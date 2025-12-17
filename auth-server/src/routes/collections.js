import express from 'express';
import { body, query, param } from 'express-validator';
import { authRequired } from '../middleware/auth.js';
import { checkResourceOwnership } from '../middleware/authorization.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { createRateLimiter, writeLimiter } from '../middleware/rateLimiter.js';
import { handleValidationErrors, validators } from '../middleware/validation.js';

const router = express.Router();

router.use(authRequired);

// GET /api/collections - Get all collections
router.get(
  '/',
  [
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { page = 1, limit = 50 } = req.query;
    const userId = req.user.id;
    const db = req.db;
    const offset = (page - 1) * limit;

    const result = await db.query(
      `SELECT * FROM calendarnotes.collections 
       WHERE user_id = $1 
       ORDER BY sort_order ASC NULLS LAST, created_at ASC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );

    const countResult = await db.query(
      'SELECT COUNT(*) FROM calendarnotes.collections WHERE user_id = $1',
      [userId]
    );
    const total = parseInt(countResult.rows[0].count);

    res.json({
      collections: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit)
      }
    });
  })
);

// GET /api/collections/:id - Get single collection
router.get(
  '/:id',
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('collections'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      'SELECT * FROM calendarnotes.collections WHERE id = $1',
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Collection not found' });
    }

    res.json({ collection: result.rows[0] });
  })
);

// POST /api/collections - Create collection
router.post(
  '/',
  createRateLimiter(writeLimiter),
  [
    body('name').isString().notEmpty().withMessage('Name is required'),
    body('description').optional().isString(),
    body('color').optional().isString(),
    body('icon').optional().isString(),
    body('parent_collection_id').optional().isUUID(),
    body('sort_order').optional().isInt()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const {
      name,
      description,
      color,
      icon,
      parent_collection_id,
      sort_order
    } = req.body;
    const userId = req.user.id;
    const db = req.db;

    // Validate parent_collection_id if provided
    if (parent_collection_id) {
      const parentCheck = await db.query(
        'SELECT id FROM calendarnotes.collections WHERE id = $1 AND user_id = $2',
        [parent_collection_id, userId]
      );
      if (parentCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid parent_collection_id' });
      }
    }

    const result = await db.query(
      `INSERT INTO calendarnotes.collections 
       (user_id, name, description, color, icon, parent_collection_id, sort_order)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        userId,
        name,
        description || null,
        color || null,
        icon || null,
        parent_collection_id || null,
        sort_order || null
      ]
    );

    res.status(201).json({ collection: result.rows[0] });
  })
);

// PUT /api/collections/:id - Update collection
router.put(
  '/:id',
  createRateLimiter(writeLimiter),
  [
    validators.uuid,
    body('name').optional().isString().notEmpty(),
    body('description').optional().isString(),
    body('color').optional().isString(),
    body('icon').optional().isString(),
    body('parent_collection_id').optional().isUUID(),
    body('sort_order').optional().isInt()
  ],
  handleValidationErrors,
  checkResourceOwnership('collections'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const allowedFields = [
      'name', 'description', 'color', 'icon', 'parent_collection_id', 'sort_order'
    ];

    const updates = [];
    const values = [];
    let paramIndex = 1;

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updates.push(`${field} = $${paramIndex}`);
        values.push(req.body[field]);
        paramIndex++;
      }
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    // Validate parent_collection_id if being updated (and prevent circular references)
    if (req.body.parent_collection_id) {
      if (req.body.parent_collection_id === req.resourceId) {
        return res.status(400).json({ error: 'Collection cannot be its own parent' });
      }

      const parentCheck = await db.query(
        'SELECT id FROM calendarnotes.collections WHERE id = $1 AND user_id = $2',
        [req.body.parent_collection_id, req.user.id]
      );
      if (parentCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid parent_collection_id' });
      }
    }

    values.push(req.resourceId);
    const result = await db.query(
      `UPDATE calendarnotes.collections 
       SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex}
       RETURNING *`,
      values
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Collection not found' });
    }

    res.json({ collection: result.rows[0] });
  })
);

// DELETE /api/collections/:id - Delete collection
router.delete(
  '/:id',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('collections'),
  asyncHandler(async (req, res) => {
    const db = req.db;

    // Check if collection has bookmarks
    const bookmarksCheck = await db.query(
      'SELECT COUNT(*) FROM calendarnotes.bookmarks WHERE collection_id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );
    const bookmarkCount = parseInt(bookmarksCheck.rows[0].count);

    if (bookmarkCount > 0) {
      return res.status(400).json({ 
        error: 'Cannot delete collection with bookmarks',
        bookmarkCount 
      });
    }

    // Check if collection has child collections
    const childrenCheck = await db.query(
      'SELECT COUNT(*) FROM calendarnotes.collections WHERE parent_collection_id = $1',
      [req.resourceId]
    );
    const childrenCount = parseInt(childrenCheck.rows[0].count);

    if (childrenCount > 0) {
      return res.status(400).json({ 
        error: 'Cannot delete collection with child collections',
        childrenCount 
      });
    }

    const result = await db.query(
      'DELETE FROM calendarnotes.collections WHERE id = $1 RETURNING id',
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Collection not found' });
    }

    res.json({ success: true, message: 'Collection deleted' });
  })
);

// GET /api/collections/:id/bookmarks - Get all bookmarks in collection
router.get(
  '/:id/bookmarks',
  [
    validators.uuid,
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  handleValidationErrors,
  checkResourceOwnership('collections'),
  asyncHandler(async (req, res) => {
    const { page = 1, limit = 50 } = req.query;
    const db = req.db;
    const offset = (page - 1) * limit;

    const result = await db.query(
      `SELECT * FROM calendarnotes.bookmarks 
       WHERE collection_id = $1 AND deleted_at IS NULL
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.resourceId, limit, offset]
    );

    const countResult = await db.query(
      'SELECT COUNT(*) FROM calendarnotes.bookmarks WHERE collection_id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );
    const total = parseInt(countResult.rows[0].count);

    res.json({
      bookmarks: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit)
      }
    });
  })
);

export default router;

