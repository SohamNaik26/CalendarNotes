// Query performance monitoring middleware
// Logs queries taking >500ms and alerts on queries taking >2 seconds

import { logger } from './logger.js';

// Track query performance
const queryStats = {
  slowQueries: [], // Queries > 500ms
  verySlowQueries: [], // Queries > 2 seconds
  queryCounts: new Map(), // Track query frequency
  totalQueries: 0
};

// Maximum number of tracked queries
const MAX_TRACKED_QUERIES = 100;

/**
 * Wraps pool.query to monitor query performance
 */
function monitorQuery(pool) {
  const originalQuery = pool.query.bind(pool);
  
  pool.query = function(text, params) {
    const startTime = Date.now();
    const queryId = generateQueryId(text);
    
    return originalQuery(text, params)
      .then((result) => {
        const duration = Date.now() - startTime;
        const durationSeconds = duration / 1000;
        
        // Track query
        trackQuery(queryId, text, durationSeconds);
        
        // Log slow queries (>500ms)
        if (duration > 500) {
          logger.warn(`Slow query detected: ${queryId} took ${duration}ms`, {
            query: sanitizeQuery(text),
            duration: duration,
            params: params ? params.length : 0
          });
          
          queryStats.slowQueries.push({
            query: sanitizeQuery(text),
            duration: durationSeconds,
            timestamp: new Date().toISOString()
          });
          
          // Keep only recent slow queries
          if (queryStats.slowQueries.length > MAX_TRACKED_QUERIES) {
            queryStats.slowQueries.shift();
          }
        }
        
        // Alert on very slow queries (>2 seconds)
        if (duration > 2000) {
          logger.error(`⚠️ Very slow query: ${queryId} took ${duration}ms`, {
            query: sanitizeQuery(text),
            duration: duration,
            params: params ? params.length : 0
          });
          
          queryStats.verySlowQueries.push({
            query: sanitizeQuery(text),
            duration: durationSeconds,
            timestamp: new Date().toISOString()
          });
          
          // Keep only recent very slow queries
          if (queryStats.verySlowQueries.length > MAX_TRACKED_QUERIES) {
            queryStats.verySlowQueries.shift();
          }
        }
        
        return result;
      })
      .catch((error) => {
        const duration = Date.now() - startTime;
        logger.error(`Query failed after ${duration}ms: ${queryId}`, {
          query: sanitizeQuery(text),
          error: error.message,
          duration: duration
        });
        throw error;
      });
  };
  
  return pool;
}

/**
 * Generates a unique ID for a query (for tracking)
 */
function generateQueryId(query) {
  // Use first 50 chars of query as ID
  const sanitized = sanitizeQuery(query);
  return sanitized.substring(0, 50).replace(/\s+/g, '_');
}

/**
 * Sanitizes query by removing parameters for grouping similar queries
 */
function sanitizeQuery(query) {
  if (typeof query !== 'string') {
    return 'N/A';
  }
  
  // Replace parameter placeholders ($1, $2, etc.) with ?
  return query.replace(/\$\d+/g, '?');
}

/**
 * Tracks query frequency and performance
 */
function trackQuery(queryId, query, duration) {
  queryStats.totalQueries++;
  
  if (!queryStats.queryCounts.has(queryId)) {
    queryStats.queryCounts.set(queryId, {
      count: 0,
      totalDuration: 0,
      minDuration: Infinity,
      maxDuration: 0,
      query: sanitizeQuery(query)
    });
  }
  
  const stats = queryStats.queryCounts.get(queryId);
  stats.count++;
  stats.totalDuration += duration;
  stats.minDuration = Math.min(stats.minDuration, duration);
  stats.maxDuration = Math.max(stats.maxDuration, duration);
}

/**
 * Gets query performance statistics
 */
function getQueryStats() {
  // Get top 10 slowest queries
  const topSlowQueries = Array.from(queryStats.queryCounts.entries())
    .map(([id, stats]) => ({
      id,
      query: stats.query,
      count: stats.count,
      avgDuration: stats.totalDuration / stats.count,
      minDuration: stats.minDuration,
      maxDuration: stats.maxDuration
    }))
    .sort((a, b) => b.avgDuration - a.avgDuration)
    .slice(0, 10);
  
  return {
    totalQueries: queryStats.totalQueries,
    slowQueriesCount: queryStats.slowQueries.length,
    verySlowQueriesCount: queryStats.verySlowQueries.length,
    recentSlowQueries: queryStats.slowQueries.slice(-10),
    recentVerySlowQueries: queryStats.verySlowQueries.slice(-10),
    topSlowQueries: topSlowQueries
  };
}

/**
 * Resets query statistics
 */
function resetQueryStats() {
  queryStats.slowQueries = [];
  queryStats.verySlowQueries = [];
  queryStats.queryCounts.clear();
  queryStats.totalQueries = 0;
}

export { monitorQuery, getQueryStats, resetQueryStats };

