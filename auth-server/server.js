import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { RateLimiterMemory } from 'rate-limiter-flexible';
import pkg from 'pg';
import authRouter from './src/routes/auth.js';
import eventsRouter from './src/routes/events.js';
import notesRouter from './src/routes/notes.js';
import todosRouter from './src/routes/todos.js';
import bookmarksRouter from './src/routes/bookmarks.js';
import collectionsRouter from './src/routes/collections.js';
import voicenotesRouter from './src/routes/voicenotes.js';
import syncRouter from './src/routes/sync.js';
import usersRouter from './src/routes/users.js';
import { httpLogger, logger } from './src/middleware/logger.js';
import { errorHandler } from './src/middleware/errorHandler.js';
import { createRateLimiter, generalLimiter } from './src/middleware/rateLimiter.js';
import { monitorQuery } from './src/middleware/queryMonitor.js';

const { Pool } = pkg;

const app = express();
const PORT = process.env.PORT || 3000;

// PostgreSQL connection pool with optimized settings
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10, // Maximum pool size
  min: 2, // Minimum pool size
  idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
  connectionTimeoutMillis: 5000, // Return an error after 5 seconds if connection cannot be established
  statement_timeout: 5000, // Query timeout (5 seconds)
  query_timeout: 5000
});

// Monitor query performance
monitorQuery(pool);

// Handle pool errors
pool.on('error', (err, client) => {
  logger.error('Unexpected error on idle client', err);
  console.error('Unexpected error on idle client', err);
});

// Log pool events for monitoring
pool.on('connect', (client) => {
  logger.debug('New client connected to pool');
});

pool.on('acquire', (client) => {
  logger.debug('Client acquired from pool');
});

pool.on('remove', (client) => {
  logger.debug('Client removed from pool');
});

// Ensure table structure (simple bootstrap)
async function ensureTables() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      email_verified BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      last_login_at TIMESTAMPTZ,
      refresh_token TEXT
    );
  `).catch(async (e) => {
    // Fallback when pgcrypto is not present to create UUID; use extension if available
    await pool.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto;`);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        email_verified BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        last_login_at TIMESTAMPTZ,
        refresh_token TEXT
      );
    `);
  });
}

// Middleware
app.use(helmet());
app.use(cors({
  origin: true,
  credentials: true
}));
app.use(express.json());

// Logging middleware
app.use(httpLogger);

// Rate limiting for auth endpoints (10 req/min per IP)
const rateLimiter = new RateLimiterMemory({
  points: 10,
  duration: 60
});
app.use('/api/auth', async (req, res, next) => {
  try {
    await rateLimiter.consume(req.ip);
    next();
  } catch {
    res.status(429).json({ error: 'Too many requests' });
  }
});

// Inject pool into request
app.use((req, _res, next) => {
  req.db = pool;
  next();
});

// General rate limiting for all API routes
app.use('/api', createRateLimiter(generalLimiter));

// Routes
app.use('/api/auth', authRouter);
app.use('/api/events', eventsRouter);
app.use('/api/notes', notesRouter);
app.use('/api/todos', todosRouter);
app.use('/api/bookmarks', bookmarksRouter);
app.use('/api/collections', collectionsRouter);
app.use('/api/voicenotes', voicenotesRouter);
app.use('/api/sync', syncRouter);
app.use('/api/users', usersRouter);

// Health check endpoint with database and disk space checks
app.get('/api/health', async (_req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'CalendarNotes API',
    checks: {
      database: 'unknown',
      diskSpace: 'unknown'
    }
  };

  try {
    // Check database connection
    const startTime = Date.now();
    const dbResult = await pool.query('SELECT NOW() as current_time, version() as version');
    const responseTime = Date.now() - startTime;
    
    health.checks.database = {
      status: 'connected',
      version: dbResult.rows[0].version.split(' ')[0] + ' ' + dbResult.rows[0].version.split(' ')[1],
      responseTime: `${responseTime}ms`
    };
  } catch (error) {
    health.status = 'unhealthy';
    health.checks.database = {
      status: 'disconnected',
      error: error.message
    };
  }

  try {
    // Check disk space using child_process to run df command
    const { execSync } = await import('child_process');
    const os = await import('os');
    
    // Use df command for Unix-like systems (Linux, macOS, Docker)
    try {
      const dfOutput = execSync('df -k /', { encoding: 'utf-8', timeout: 5000 });
      const lines = dfOutput.trim().split('\n');
      if (lines.length > 1) {
        const parts = lines[1].split(/\s+/);
        const totalSpace = parseInt(parts[1]) * 1024; // Convert from KB to bytes
        const usedSpace = parseInt(parts[2]) * 1024;
        const freeSpace = parseInt(parts[3]) * 1024;
        const usedPercent = parseFloat(parts[4].replace('%', ''));

        health.checks.diskSpace = {
          status: usedPercent > 90 ? 'warning' : 'ok',
          total: formatBytes(totalSpace),
          free: formatBytes(freeSpace),
          used: formatBytes(usedSpace),
          usedPercent: `${usedPercent}%`
        };

        if (usedPercent > 90) {
          health.status = 'degraded';
        }
      } else {
        throw new Error('Unable to parse df output');
      }
    } catch (execError) {
      // Fallback: use os module for basic info (doesn't provide disk space)
      health.checks.diskSpace = {
        status: 'ok',
        note: 'Detailed disk space check unavailable, using system info',
        platform: os.platform(),
        hostname: os.hostname()
      };
    }
  } catch (error) {
    health.checks.diskSpace = {
      status: 'unknown',
      error: error.message
    };
  }

  const statusCode = health.status === 'healthy' ? 200 : health.status === 'degraded' ? 200 : 503;
  res.status(statusCode).json(health);
});

// Helper function to format bytes
function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

// Legacy health endpoint (for backward compatibility)
app.get('/health', (_req, res) => res.json({ ok: true }));

// Error handling middleware (must be last)
app.use(errorHandler);

// Start
ensureTables().then(() => {
  app.listen(PORT, () => {
    logger.info(`CalendarNotes API server running on port ${PORT}`);
    console.log(`CalendarNotes API server running on port ${PORT}`);
  });
}).catch(err => {
  logger.error('Failed to ensure tables', err);
  console.error('Failed to ensure tables', err);
  process.exit(1);
});


