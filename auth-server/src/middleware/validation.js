// Validation helpers and common validators

import { body, query, param, validationResult } from 'express-validator';

// Middleware to handle validation errors
export function handleValidationErrors(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
}

// Common validators
export const validators = {
  uuid: param('id').isUUID().withMessage('Invalid UUID format'),
  optionalUuid: body('id').optional().isUUID().withMessage('Invalid UUID format'),
  email: body('email').isEmail().withMessage('Invalid email format'),
  password: body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
  pagination: [
    query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100')
  ],
  date: (field) => body(field).optional().isISO8601().withMessage(`Invalid date format for ${field}`),
  dateQuery: (field) => query(field).optional().isISO8601().withMessage(`Invalid date format for ${field}`)
};

