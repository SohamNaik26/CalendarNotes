// Rate limiting middleware for different endpoints

import { RateLimiterMemory } from 'rate-limiter-flexible';

// General API rate limiter (100 requests per 15 minutes)
export const generalLimiter = new RateLimiterMemory({
  points: 100,
  duration: 900 // 15 minutes
});

// Strict rate limiter for write operations (20 requests per minute)
export const writeLimiter = new RateLimiterMemory({
  points: 20,
  duration: 60
});

// Very strict rate limiter for sensitive operations (5 requests per minute)
export const sensitiveLimiter = new RateLimiterMemory({
  points: 5,
  duration: 60
});

// Rate limiter middleware factory
export function createRateLimiter(limiter) {
  return async (req, res, next) => {
    try {
      const key = req.user?.id || req.ip;
      await limiter.consume(key);
      next();
    } catch (rejRes) {
      const secs = Math.round(rejRes.msBeforeNext / 1000) || 1;
      res.status(429).json({
        error: 'Too many requests',
        retryAfter: secs
      });
    }
  };
}

