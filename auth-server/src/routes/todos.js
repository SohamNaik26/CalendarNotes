import express from 'express';
import { body, query, param } from 'express-validator';
import { authRequired } from '../middleware/auth.js';
import { checkResourceOwnership } from '../middleware/authorization.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { createRateLimiter, writeLimiter } from '../middleware/rateLimiter.js';
import { handleValidationErrors, validators } from '../middleware/validation.js';

const router = express.Router();

router.use(authRequired);

// GET /api/todos - Get all todos
router.get(
  '/',
  [
    query('completed').optional().isBoolean(),
    query('priority').optional().isIn(['high', 'medium', 'low']),
    query('dueDate').optional().isISO8601(),
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { completed, priority, dueDate, page = 1, limit = 50 } = req.query;
    const userId = req.user.id;
    const db = req.db;
    const offset = (page - 1) * limit;

    let queryText = `
      SELECT * FROM calendarnotes.todo_items 
      WHERE user_id = $1 AND deleted_at IS NULL
    `;
    const queryParams = [userId];
    let paramIndex = 2;

    if (completed !== undefined) {
      queryText += ` AND is_completed = $${paramIndex}`;
      queryParams.push(completed === 'true');
      paramIndex++;
    }

    if (priority) {
      queryText += ` AND priority = $${paramIndex}`;
      queryParams.push(priority);
      paramIndex++;
    }

    if (dueDate) {
      queryText += ` AND DATE(due_date) = DATE($${paramIndex})`;
      queryParams.push(dueDate);
      paramIndex++;
    }

    queryText += ` ORDER BY 
      CASE priority 
        WHEN 'high' THEN 1 
        WHEN 'medium' THEN 2 
        WHEN 'low' THEN 3 
        ELSE 4 
      END,
      due_date ASC NULLS LAST,
      created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    queryParams.push(limit, offset);

    const result = await db.query(queryText, queryParams);

    // Get total count
    let countQuery = `
      SELECT COUNT(*) FROM calendarnotes.todo_items 
      WHERE user_id = $1 AND deleted_at IS NULL
    `;
    const countParams = [userId];
    if (completed !== undefined) {
      countQuery += ` AND is_completed = $2`;
      countParams.push(completed === 'true');
    }
    if (priority) {
      countQuery += ` AND priority = $${countParams.length + 1}`;
      countParams.push(priority);
    }
    if (dueDate) {
      countQuery += ` AND DATE(due_date) = DATE($${countParams.length + 1})`;
      countParams.push(dueDate);
    }

    const countResult = await db.query(countQuery, countParams);
    const total = parseInt(countResult.rows[0].count);

    res.json({
      todos: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit)
      }
    });
  })
);

// GET /api/todos/:id - Get single todo
router.get(
  '/:id',
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('todo_items'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      'SELECT * FROM calendarnotes.todo_items WHERE id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Todo not found' });
    }

    res.json({ todo: result.rows[0] });
  })
);

// POST /api/todos - Create todo
router.post(
  '/',
  createRateLimiter(writeLimiter),
  [
    body('title').isString().notEmpty().withMessage('Title is required'),
    body('description').optional().isString(),
    body('due_date').optional().isISO8601(),
    body('priority').optional().isIn(['high', 'medium', 'low']),
    body('category').optional().isString(),
    body('is_recurring').optional().isBoolean(),
    body('recurrence_rule').optional().isObject(),
    body('linked_event_id').optional().isUUID()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const {
      title,
      description,
      due_date,
      priority,
      category,
      is_recurring = false,
      recurrence_rule,
      linked_event_id
    } = req.body;
    const userId = req.user.id;
    const db = req.db;

    // Validate linked_event_id if provided
    if (linked_event_id) {
      const eventCheck = await db.query(
        'SELECT id FROM calendarnotes.calendar_events WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [linked_event_id, userId]
      );
      if (eventCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid linked_event_id' });
      }
    }

    const result = await db.query(
      `INSERT INTO calendarnotes.todo_items 
       (user_id, title, description, due_date, priority, category, is_recurring, recurrence_rule, linked_event_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        userId,
        title,
        description || null,
        due_date || null,
        priority || null,
        category || null,
        is_recurring,
        recurrence_rule ? JSON.stringify(recurrence_rule) : null,
        linked_event_id || null
      ]
    );

    res.status(201).json({ todo: result.rows[0] });
  })
);

// PUT /api/todos/:id - Update todo
router.put(
  '/:id',
  createRateLimiter(writeLimiter),
  [
    validators.uuid,
    body('title').optional().isString().notEmpty(),
    body('description').optional().isString(),
    body('due_date').optional().isISO8601(),
    body('priority').optional().isIn(['high', 'medium', 'low']),
    body('category').optional().isString(),
    body('is_recurring').optional().isBoolean(),
    body('recurrence_rule').optional().isObject(),
    body('linked_event_id').optional().isUUID()
  ],
  handleValidationErrors,
  checkResourceOwnership('todo_items'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const allowedFields = [
      'title', 'description', 'due_date', 'priority', 'category',
      'is_recurring', 'recurrence_rule', 'linked_event_id'
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

    // Validate linked_event_id if being updated
    if (req.body.linked_event_id) {
      const eventCheck = await db.query(
        'SELECT id FROM calendarnotes.calendar_events WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [req.body.linked_event_id, req.user.id]
      );
      if (eventCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid linked_event_id' });
      }
    }

    values.push(req.resourceId);
    const result = await db.query(
      `UPDATE calendarnotes.todo_items 
       SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex} AND deleted_at IS NULL
       RETURNING *`,
      values
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Todo not found' });
    }

    res.json({ todo: result.rows[0] });
  })
);

// DELETE /api/todos/:id - Soft delete todo
router.delete(
  '/:id',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('todo_items'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      `UPDATE calendarnotes.todo_items 
       SET deleted_at = NOW() 
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING id`,
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Todo not found' });
    }

    res.json({ success: true, message: 'Todo deleted' });
  })
);

// PATCH /api/todos/:id/complete - Mark todo as completed
router.patch(
  '/:id/complete',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('todo_items'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      `UPDATE calendarnotes.todo_items 
       SET is_completed = TRUE, completed_at = NOW(), updated_at = NOW()
       WHERE id = $1 AND deleted_at IS NULL AND is_completed = FALSE
       RETURNING *`,
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Todo not found or already completed' });
    }

    res.json({ todo: result.rows[0] });
  })
);

// PATCH /api/todos/:id/uncomplete - Mark todo as incomplete
router.patch(
  '/:id/uncomplete',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('todo_items'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      `UPDATE calendarnotes.todo_items 
       SET is_completed = FALSE, completed_at = NULL, updated_at = NOW()
       WHERE id = $1 AND deleted_at IS NULL AND is_completed = TRUE
       RETURNING *`,
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Todo not found or already incomplete' });
    }

    res.json({ todo: result.rows[0] });
  })
);

export default router;

