import express from 'express';
import { body, query, param, validationResult } from 'express-validator';
import { authRequired } from '../middleware/auth.js';
import { checkResourceOwnership } from '../middleware/authorization.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { createRateLimiter, writeLimiter } from '../middleware/rateLimiter.js';
import { handleValidationErrors, validators } from '../middleware/validation.js';

const router = express.Router();

// Apply authentication to all routes
router.use(authRequired);

// GET /api/events - Get all events for authenticated user
router.get(
  '/',
  [
    query('startDate').optional().isISO8601(),
    query('endDate').optional().isISO8601(),
    query('category').optional().isString(),
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { startDate, endDate, category, page = 1, limit = 50 } = req.query;
    const userId = req.user.id;
    const db = req.db;
    const offset = (page - 1) * limit;

    let queryText = `
      SELECT * FROM calendarnotes.calendar_events 
      WHERE user_id = $1 AND deleted_at IS NULL
    `;
    const queryParams = [userId];
    let paramIndex = 2;

    if (startDate) {
      queryText += ` AND start_date >= $${paramIndex}`;
      queryParams.push(startDate);
      paramIndex++;
    }

    if (endDate) {
      queryText += ` AND end_date <= $${paramIndex}`;
      queryParams.push(endDate);
      paramIndex++;
    }

    if (category) {
      queryText += ` AND category = $${paramIndex}`;
      queryParams.push(category);
      paramIndex++;
    }

    queryText += ` ORDER BY start_date ASC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    queryParams.push(limit, offset);

    const result = await db.query(queryText, queryParams);

    // Get total count
    let countQuery = `
      SELECT COUNT(*) FROM calendarnotes.calendar_events 
      WHERE user_id = $1 AND deleted_at IS NULL
    `;
    const countParams = [userId];
    if (startDate) {
      countQuery += ` AND start_date >= $2`;
      countParams.push(startDate);
    }
    if (endDate) {
      countQuery += ` AND end_date <= $${countParams.length + 1}`;
      countParams.push(endDate);
    }
    if (category) {
      countQuery += ` AND category = $${countParams.length + 1}`;
      countParams.push(category);
    }

    const countResult = await db.query(countQuery, countParams);
    const total = parseInt(countResult.rows[0].count);

    res.json({
      events: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit)
      }
    });
  })
);

// GET /api/events/:id - Get single event by ID
router.get(
  '/:id',
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('calendar_events'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      'SELECT * FROM calendarnotes.calendar_events WHERE id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Event not found' });
    }

    res.json({ event: result.rows[0] });
  })
);

// POST /api/events - Create new event
router.post(
  '/',
  createRateLimiter(writeLimiter),
  [
    body('title').isString().notEmpty().withMessage('Title is required'),
    body('start_date').isISO8601().withMessage('Valid start_date is required'),
    body('end_date').isISO8601().withMessage('Valid end_date is required'),
    body('description').optional().isString(),
    body('location').optional().isString(),
    body('category').optional().isString(),
    body('color').optional().isString(),
    body('is_all_day').optional().isBoolean(),
    body('is_recurring').optional().isBoolean(),
    body('recurrence_rule').optional().isObject()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const {
      title,
      description,
      start_date,
      end_date,
      location,
      category,
      color,
      is_all_day = false,
      is_recurring = false,
      recurrence_rule
    } = req.body;
    const userId = req.user.id;
    const db = req.db;

    // Validate date range
    if (new Date(end_date) < new Date(start_date)) {
      return res.status(400).json({ error: 'end_date must be after start_date' });
    }

    const result = await db.query(
      `INSERT INTO calendarnotes.calendar_events 
       (user_id, title, description, start_date, end_date, location, category, color, is_all_day, is_recurring, recurrence_rule)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [userId, title, description, start_date, end_date, location, category, color, is_all_day, is_recurring, recurrence_rule ? JSON.stringify(recurrence_rule) : null]
    );

    res.status(201).json({ event: result.rows[0] });
  })
);

// PUT /api/events/:id - Update event
router.put(
  '/:id',
  createRateLimiter(writeLimiter),
  [
    validators.uuid,
    body('title').optional().isString().notEmpty(),
    body('start_date').optional().isISO8601(),
    body('end_date').optional().isISO8601(),
    body('description').optional().isString(),
    body('location').optional().isString(),
    body('category').optional().isString(),
    body('color').optional().isString(),
    body('is_all_day').optional().isBoolean(),
    body('is_recurring').optional().isBoolean(),
    body('recurrence_rule').optional().isObject()
  ],
  handleValidationErrors,
  checkResourceOwnership('calendar_events'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const allowedFields = [
      'title', 'description', 'start_date', 'end_date', 'location',
      'category', 'color', 'is_all_day', 'is_recurring', 'recurrence_rule'
    ];

    const updates = [];
    const values = [];
    let paramIndex = 1;

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updates.push(`${field} = $${paramIndex}`);
        if (field === 'recurrence_rule' && typeof req.body[field] === 'object') {
          values.push(JSON.stringify(req.body[field]));
        } else {
          values.push(req.body[field]);
        }
        paramIndex++;
      }
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    // Validate date range if both dates are being updated
    if (req.body.start_date && req.body.end_date) {
      if (new Date(req.body.end_date) < new Date(req.body.start_date)) {
        return res.status(400).json({ error: 'end_date must be after start_date' });
      }
    }

    values.push(req.resourceId);
    const result = await db.query(
      `UPDATE calendarnotes.calendar_events 
       SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex} AND deleted_at IS NULL
       RETURNING *`,
      values
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Event not found' });
    }

    res.json({ event: result.rows[0] });
  })
);

// DELETE /api/events/:id - Soft delete event
router.delete(
  '/:id',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('calendar_events'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      `UPDATE calendarnotes.calendar_events 
       SET deleted_at = NOW() 
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING id`,
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Event not found' });
    }

    res.json({ success: true, message: 'Event deleted' });
  })
);

// POST /api/events/batch - Create multiple events
router.post(
  '/batch',
  createRateLimiter(writeLimiter),
  [
    body('events').isArray({ min: 1, max: 100 }).withMessage('events must be an array with 1-100 items'),
    body('events.*.title').isString().notEmpty(),
    body('events.*.start_date').isISO8601(),
    body('events.*.end_date').isISO8601()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { events } = req.body;
    const userId = req.user.id;
    const db = req.db;

    const createdIds = [];
    const errors = [];

    for (let i = 0; i < events.length; i++) {
      const event = events[i];
      try {
        if (new Date(event.end_date) < new Date(event.start_date)) {
          errors.push({ index: i, error: 'end_date must be after start_date' });
          continue;
        }

        const result = await db.query(
          `INSERT INTO calendarnotes.calendar_events 
           (user_id, title, description, start_date, end_date, location, category, color, is_all_day, is_recurring, recurrence_rule)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
           RETURNING id`,
          [
            userId,
            event.title,
            event.description || null,
            event.start_date,
            event.end_date,
            event.location || null,
            event.category || null,
            event.color || null,
            event.is_all_day || false,
            event.is_recurring || false,
            event.recurrence_rule ? JSON.stringify(event.recurrence_rule) : null
          ]
        );
        createdIds.push(result.rows[0].id);
      } catch (err) {
        errors.push({ index: i, error: err.message });
      }
    }

    res.status(201).json({
      created: createdIds.length,
      ids: createdIds,
      errors: errors.length > 0 ? errors : undefined
    });
  })
);

// PUT /api/events/batch - Update multiple events
router.put(
  '/batch',
  createRateLimiter(writeLimiter),
  [
    body('events').isArray({ min: 1, max: 100 }).withMessage('events must be an array with 1-100 items'),
    body('events.*.id').isUUID(),
    body('events.*.title').optional().isString().notEmpty(),
    body('events.*.start_date').optional().isISO8601(),
    body('events.*.end_date').optional().isISO8601()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { events } = req.body;
    const userId = req.user.id;
    const db = req.db;

    let updatedCount = 0;
    const errors = [];

    for (let i = 0; i < events.length; i++) {
      const event = events[i];
      try {
        // Check ownership
        const checkResult = await db.query(
          'SELECT id FROM calendarnotes.calendar_events WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
          [event.id, userId]
        );

        if (checkResult.rowCount === 0) {
          errors.push({ index: i, id: event.id, error: 'Event not found or access denied' });
          continue;
        }

        const allowedFields = [
          'title', 'description', 'start_date', 'end_date', 'location',
          'category', 'color', 'is_all_day', 'is_recurring', 'recurrence_rule'
        ];

        const updates = [];
        const values = [];
        let paramIndex = 1;

        for (const field of allowedFields) {
          if (event[field] !== undefined) {
            updates.push(`${field} = $${paramIndex}`);
            if (field === 'recurrence_rule' && typeof event[field] === 'object') {
              values.push(JSON.stringify(event[field]));
            } else {
              values.push(event[field]);
            }
            paramIndex++;
          }
        }

        if (updates.length > 0) {
          values.push(event.id);
          await db.query(
            `UPDATE calendarnotes.calendar_events 
             SET ${updates.join(', ')}, updated_at = NOW()
             WHERE id = $${paramIndex} AND deleted_at IS NULL`,
            values
          );
          updatedCount++;
        }
      } catch (err) {
        errors.push({ index: i, id: event.id, error: err.message });
      }
    }

    res.json({
      updated: updatedCount,
      errors: errors.length > 0 ? errors : undefined
    });
  })
);

export default router;

