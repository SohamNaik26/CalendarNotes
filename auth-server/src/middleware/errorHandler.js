// Centralized error handling middleware

export function errorHandler(err, req, res, next) {
  console.error('Error:', err);

  // Validation errors from express-validator
  if (err.name === 'ValidationError' || err.type === 'validation') {
    return res.status(400).json({
      error: 'Validation error',
      details: err.errors || err.message
    });
  }

  // Database errors
  if (err.code === '23505') { // Unique violation
    return res.status(409).json({ error: 'Resource already exists' });
  }
  if (err.code === '23503') { // Foreign key violation
    return res.status(400).json({ error: 'Invalid reference' });
  }
  if (err.code === '23502') { // Not null violation
    return res.status(400).json({ error: 'Required field missing' });
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({ error: 'Invalid token' });
  }
  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({ error: 'Token expired' });
  }

  // Default error
  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || 'Internal server error';

  res.status(statusCode).json({
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
}

// Async handler wrapper to catch errors in async route handlers
export function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

