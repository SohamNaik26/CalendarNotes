import express from 'express';
import { body, query, param, validationResult } from 'express-validator';
import { authRequired } from '../middleware/auth.js';
import { checkResourceOwnership } from '../middleware/authorization.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { createRateLimiter, writeLimiter } from '../middleware/rateLimiter.js';
import { handleValidationErrors, validators } from '../middleware/validation.js';

const router = express.Router();

router.use(authRequired);

// GET /api/notes - Get all notes for user
router.get(
  '/',
  [
    query('linkedDate').optional().isISO8601(),
    query('tag').optional().isString(),
    query('search').optional().isString(),
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { linkedDate, tag, search, page = 1, limit = 50 } = req.query;
    const userId = req.user.id;
    const db = req.db;
    const offset = (page - 1) * limit;

    let queryText = `
      SELECT * FROM calendarnotes.notes 
      WHERE user_id = $1 AND deleted_at IS NULL
    `;
    const queryParams = [userId];
    let paramIndex = 2;

    if (linkedDate) {
      queryText += ` AND linked_date = $${paramIndex}`;
      queryParams.push(linkedDate);
      paramIndex++;
    }

    if (tag) {
      queryText += ` AND $${paramIndex} = ANY(tags)`;
      queryParams.push(tag);
      paramIndex++;
    }

    if (search) {
      queryText += ` AND (
        to_tsvector('english', COALESCE(title, '')) || 
        to_tsvector('english', COALESCE(content, ''))
      ) @@ plainto_tsquery('english', $${paramIndex})`;
      queryParams.push(search);
      paramIndex++;
    }

    queryText += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    queryParams.push(limit, offset);

    const result = await db.query(queryText, queryParams);

    // Get total count
    let countQuery = `
      SELECT COUNT(*) FROM calendarnotes.notes 
      WHERE user_id = $1 AND deleted_at IS NULL
    `;
    const countParams = [userId];
    if (linkedDate) {
      countQuery += ` AND linked_date = $2`;
      countParams.push(linkedDate);
    }
    if (tag) {
      countQuery += ` AND $${countParams.length + 1} = ANY(tags)`;
      countParams.push(tag);
    }
    if (search) {
      countQuery += ` AND (
        to_tsvector('english', COALESCE(title, '')) || 
        to_tsvector('english', COALESCE(content, ''))
      ) @@ plainto_tsquery('english', $${countParams.length + 1})`;
      countParams.push(search);
    }

    const countResult = await db.query(countQuery, countParams);
    const total = parseInt(countResult.rows[0].count);

    res.json({
      notes: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit)
      }
    });
  })
);

// GET /api/notes/:id - Get single note
router.get(
  '/:id',
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('notes'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      'SELECT * FROM calendarnotes.notes WHERE id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Note not found' });
    }

    res.json({ note: result.rows[0] });
  })
);

// POST /api/notes - Create note
router.post(
  '/',
  createRateLimiter(writeLimiter),
  [
    body('title').optional().isString(),
    body('content').optional().isString(),
    body('rich_content').optional().isObject(),
    body('linked_date').optional().isISO8601(),
    body('linked_event_id').optional().isUUID(),
    body('tags').optional().isArray(),
    body('tags.*').optional().isString()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const {
      title,
      content,
      rich_content,
      linked_date,
      linked_event_id,
      tags
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
      `INSERT INTO calendarnotes.notes 
       (user_id, title, content, rich_content, linked_date, linked_event_id, tags)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        userId,
        title || null,
        content || null,
        rich_content ? JSON.stringify(rich_content) : null,
        linked_date || null,
        linked_event_id || null,
        tags || null
      ]
    );

    res.status(201).json({ note: result.rows[0] });
  })
);

// PUT /api/notes/:id - Update note
router.put(
  '/:id',
  createRateLimiter(writeLimiter),
  [
    validators.uuid,
    body('title').optional().isString(),
    body('content').optional().isString(),
    body('rich_content').optional().isObject(),
    body('linked_date').optional().isISO8601(),
    body('linked_event_id').optional().isUUID(),
    body('tags').optional().isArray(),
    body('tags.*').optional().isString()
  ],
  handleValidationErrors,
  checkResourceOwnership('notes'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const allowedFields = [
      'title', 'content', 'rich_content', 'linked_date', 'linked_event_id', 'tags'
    ];

    const updates = [];
    const values = [];
    let paramIndex = 1;

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updates.push(`${field} = $${paramIndex}`);
        if (field === 'rich_content' && typeof req.body[field] === 'object') {
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
      `UPDATE calendarnotes.notes 
       SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex} AND deleted_at IS NULL
       RETURNING *`,
      values
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Note not found' });
    }

    res.json({ note: result.rows[0] });
  })
);

// DELETE /api/notes/:id - Soft delete note
router.delete(
  '/:id',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('notes'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      `UPDATE calendarnotes.notes 
       SET deleted_at = NOW() 
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING id`,
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Note not found' });
    }

    res.json({ success: true, message: 'Note deleted' });
  })
);

// POST /api/notes/:id/link-event - Link note to event
router.post(
  '/:id/link-event',
  createRateLimiter(writeLimiter),
  [
    validators.uuid,
    body('event_id').isUUID().withMessage('Valid event_id is required')
  ],
  handleValidationErrors,
  checkResourceOwnership('notes'),
  asyncHandler(async (req, res) => {
    const { event_id } = req.body;
    const userId = req.user.id;
    const db = req.db;

    // Verify event belongs to user
    const eventCheck = await db.query(
      'SELECT id FROM calendarnotes.calendar_events WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
      [event_id, userId]
    );

    if (eventCheck.rowCount === 0) {
      return res.status(404).json({ error: 'Event not found or access denied' });
    }

    const result = await db.query(
      `UPDATE calendarnotes.notes 
       SET linked_event_id = $1, updated_at = NOW()
       WHERE id = $2 AND deleted_at IS NULL
       RETURNING *`,
      [event_id, req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Note not found' });
    }

    res.json({ note: result.rows[0] });
  })
);

// POST /api/notes/:id/link-bookmark - Link note to bookmark
router.post(
  '/:id/link-bookmark',
  createRateLimiter(writeLimiter),
  [
    validators.uuid,
    body('bookmark_id').isUUID().withMessage('Valid bookmark_id is required')
  ],
  handleValidationErrors,
  checkResourceOwnership('notes'),
  asyncHandler(async (req, res) => {
    const { bookmark_id } = req.body;
    const userId = req.user.id;
    const db = req.db;

    // Verify bookmark belongs to user
    const bookmarkCheck = await db.query(
      'SELECT id FROM calendarnotes.bookmarks WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
      [bookmark_id, userId]
    );

    if (bookmarkCheck.rowCount === 0) {
      return res.status(404).json({ error: 'Bookmark not found or access denied' });
    }

    // Update bookmark to link to note
    const result = await db.query(
      `UPDATE calendarnotes.bookmarks 
       SET linked_note_id = $1, updated_at = NOW()
       WHERE id = $2 AND deleted_at IS NULL
       RETURNING *`,
      [req.resourceId, bookmark_id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Bookmark not found' });
    }

    res.json({ bookmark: result.rows[0] });
  })
);

export default router;

