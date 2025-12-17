// Logging middleware using Winston and Morgan

import winston from 'winston';
import morgan from 'morgan';

// Create Winston logger
export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'calendarnotes-api' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// Add console transport in development
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

// Morgan HTTP request logger
export const httpLogger = morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim())
  }
});

// Custom logging middleware
export function logRequest(req, res, next) {
  logger.info({
    method: req.method,
    url: req.url,
    ip: req.ip,
    user: req.user?.id || 'anonymous'
  });
  next();
}

