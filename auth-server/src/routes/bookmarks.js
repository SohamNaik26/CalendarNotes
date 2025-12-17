import express from 'express';
import { body, query, param } from 'express-validator';
import { authRequired } from '../middleware/auth.js';
import { checkResourceOwnership } from '../middleware/authorization.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { createRateLimiter, writeLimiter } from '../middleware/rateLimiter.js';
import { handleValidationErrors, validators } from '../middleware/validation.js';

const router = express.Router();

router.use(authRequired);

// GET /api/bookmarks - Get all bookmarks
router.get(
  '/',
  [
    query('collection').optional().isUUID(),
    query('tag').optional().isString(),
    query('favorite').optional().isBoolean(),
    query('archived').optional().isBoolean(),
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { collection, tag, favorite, archived, page = 1, limit = 50 } = req.query;
    const userId = req.user.id;
    const db = req.db;
    const offset = (page - 1) * limit;

    let queryText = `
      SELECT * FROM calendarnotes.bookmarks 
      WHERE user_id = $1 AND deleted_at IS NULL
    `;
    const queryParams = [userId];
    let paramIndex = 2;

    if (collection) {
      queryText += ` AND collection_id = $${paramIndex}`;
      queryParams.push(collection);
      paramIndex++;
    }

    if (tag) {
      queryText += ` AND $${paramIndex} = ANY(tags)`;
      queryParams.push(tag);
      paramIndex++;
    }

    if (favorite !== undefined) {
      queryText += ` AND is_favorite = $${paramIndex}`;
      queryParams.push(favorite === 'true');
      paramIndex++;
    }

    if (archived !== undefined) {
      queryText += ` AND is_archived = $${paramIndex}`;
      queryParams.push(archived === 'true');
      paramIndex++;
    }

    queryText += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    queryParams.push(limit, offset);

    const result = await db.query(queryText, queryParams);

    // Get total count
    let countQuery = `
      SELECT COUNT(*) FROM calendarnotes.bookmarks 
      WHERE user_id = $1 AND deleted_at IS NULL
    `;
    const countParams = [userId];
    if (collection) {
      countQuery += ` AND collection_id = $2`;
      countParams.push(collection);
    }
    if (tag) {
      countQuery += ` AND $${countParams.length + 1} = ANY(tags)`;
      countParams.push(tag);
    }
    if (favorite !== undefined) {
      countQuery += ` AND is_favorite = $${countParams.length + 1}`;
      countParams.push(favorite === 'true');
    }
    if (archived !== undefined) {
      countQuery += ` AND is_archived = $${countParams.length + 1}`;
      countParams.push(archived === 'true');
    }

    const countResult = await db.query(countQuery, countParams);
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

// GET /api/bookmarks/:id - Get single bookmark
router.get(
  '/:id',
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('bookmarks'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      'SELECT * FROM calendarnotes.bookmarks WHERE id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Bookmark not found' });
    }

    res.json({ bookmark: result.rows[0] });
  })
);

// POST /api/bookmarks - Create bookmark
router.post(
  '/',
  createRateLimiter(writeLimiter),
  [
    body('url').isURL().withMessage('Valid URL is required'),
    body('title').isString().notEmpty().withMessage('Title is required'),
    body('description').optional().isString(),
    body('favicon_url').optional().isURL(),
    body('preview_image_url').optional().isURL(),
    body('tags').optional().isArray(),
    body('tags.*').optional().isString(),
    body('collection_id').optional().isUUID(),
    body('linked_date').optional().isISO8601(),
    body('linked_event_id').optional().isUUID(),
    body('linked_note_id').optional().isUUID()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const {
      url,
      title,
      description,
      favicon_url,
      preview_image_url,
      tags,
      collection_id,
      linked_date,
      linked_event_id,
      linked_note_id
    } = req.body;
    const userId = req.user.id;
    const db = req.db;

    // Validate collection_id if provided
    if (collection_id) {
      const collectionCheck = await db.query(
        'SELECT id FROM calendarnotes.collections WHERE id = $1 AND user_id = $2',
        [collection_id, userId]
      );
      if (collectionCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid collection_id' });
      }
    }

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

    // Validate linked_note_id if provided
    if (linked_note_id) {
      const noteCheck = await db.query(
        'SELECT id FROM calendarnotes.notes WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [linked_note_id, userId]
      );
      if (noteCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid linked_note_id' });
      }
    }

    const result = await db.query(
      `INSERT INTO calendarnotes.bookmarks 
       (user_id, url, title, description, favicon_url, preview_image_url, tags, collection_id, linked_date, linked_event_id, linked_note_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [
        userId,
        url,
        title,
        description || null,
        favicon_url || null,
        preview_image_url || null,
        tags || null,
        collection_id || null,
        linked_date || null,
        linked_event_id || null,
        linked_note_id || null
      ]
    );

    res.status(201).json({ bookmark: result.rows[0] });
  })
);

// PUT /api/bookmarks/:id - Update bookmark
router.put(
  '/:id',
  createRateLimiter(writeLimiter),
  [
    validators.uuid,
    body('url').optional().isURL(),
    body('title').optional().isString().notEmpty(),
    body('description').optional().isString(),
    body('favicon_url').optional().isURL(),
    body('preview_image_url').optional().isURL(),
    body('tags').optional().isArray(),
    body('tags.*').optional().isString(),
    body('collection_id').optional().isUUID(),
    body('linked_date').optional().isISO8601(),
    body('linked_event_id').optional().isUUID(),
    body('linked_note_id').optional().isUUID()
  ],
  handleValidationErrors,
  checkResourceOwnership('bookmarks'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const allowedFields = [
      'url', 'title', 'description', 'favicon_url', 'preview_image_url',
      'tags', 'collection_id', 'linked_date', 'linked_event_id', 'linked_note_id'
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

    // Validate foreign keys if being updated
    if (req.body.collection_id) {
      const collectionCheck = await db.query(
        'SELECT id FROM calendarnotes.collections WHERE id = $1 AND user_id = $2',
        [req.body.collection_id, req.user.id]
      );
      if (collectionCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid collection_id' });
      }
    }

    if (req.body.linked_event_id) {
      const eventCheck = await db.query(
        'SELECT id FROM calendarnotes.calendar_events WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [req.body.linked_event_id, req.user.id]
      );
      if (eventCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid linked_event_id' });
      }
    }

    if (req.body.linked_note_id) {
      const noteCheck = await db.query(
        'SELECT id FROM calendarnotes.notes WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [req.body.linked_note_id, req.user.id]
      );
      if (noteCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid linked_note_id' });
      }
    }

    values.push(req.resourceId);
    const result = await db.query(
      `UPDATE calendarnotes.bookmarks 
       SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex} AND deleted_at IS NULL
       RETURNING *`,
      values
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Bookmark not found' });
    }

    res.json({ bookmark: result.rows[0] });
  })
);

// DELETE /api/bookmarks/:id - Soft delete bookmark
router.delete(
  '/:id',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('bookmarks'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      `UPDATE calendarnotes.bookmarks 
       SET deleted_at = NOW() 
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING id`,
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Bookmark not found' });
    }

    res.json({ success: true, message: 'Bookmark deleted' });
  })
);

// POST /api/bookmarks/:id/favorite - Mark bookmark as favorite
router.post(
  '/:id/favorite',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('bookmarks'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      `UPDATE calendarnotes.bookmarks 
       SET is_favorite = TRUE, updated_at = NOW()
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING *`,
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Bookmark not found' });
    }

    res.json({ bookmark: result.rows[0] });
  })
);

// DELETE /api/bookmarks/:id/favorite - Unmark bookmark as favorite
router.delete(
  '/:id/favorite',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('bookmarks'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      `UPDATE calendarnotes.bookmarks 
       SET is_favorite = FALSE, updated_at = NOW()
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING *`,
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Bookmark not found' });
    }

    res.json({ bookmark: result.rows[0] });
  })
);

// POST /api/bookmarks/:id/metadata - Fetch and update metadata
router.post(
  '/:id/metadata',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('bookmarks'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    
    // Get bookmark URL
    const bookmarkResult = await db.query(
      'SELECT url FROM calendarnotes.bookmarks WHERE id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );

    if (bookmarkResult.rowCount === 0) {
      return res.status(404).json({ error: 'Bookmark not found' });
    }

    const url = bookmarkResult.rows[0].url;

    // In a real implementation, you would fetch metadata from the URL
    // For now, we'll return a placeholder response
    // You can integrate with libraries like 'metascraper' or 'open-graph-scraper'
    
    // Placeholder metadata update
    const metadata = {
      title: req.body.title || bookmarkResult.rows[0].title,
      description: req.body.description,
      favicon_url: req.body.favicon_url,
      preview_image_url: req.body.preview_image_url
    };

    const updates = [];
    const values = [];
    let paramIndex = 1;

    if (metadata.title) {
      updates.push('title = $' + paramIndex);
      values.push(metadata.title);
      paramIndex++;
    }
    if (metadata.description !== undefined) {
      updates.push('description = $' + paramIndex);
      values.push(metadata.description);
      paramIndex++;
    }
    if (metadata.favicon_url) {
      updates.push('favicon_url = $' + paramIndex);
      values.push(metadata.favicon_url);
      paramIndex++;
    }
    if (metadata.preview_image_url) {
      updates.push('preview_image_url = $' + paramIndex);
      values.push(metadata.preview_image_url);
      paramIndex++;
    }

    if (updates.length > 0) {
      values.push(req.resourceId);
      const updateResult = await db.query(
        `UPDATE calendarnotes.bookmarks 
         SET ${updates.join(', ')}, updated_at = NOW()
         WHERE id = $${paramIndex} AND deleted_at IS NULL
         RETURNING *`,
        values
      );

      return res.json({ 
        bookmark: updateResult.rows[0],
        message: 'Metadata updated. Note: In production, implement actual URL metadata fetching.'
      });
    }

    res.json({ 
      bookmark: bookmarkResult.rows[0],
      message: 'No metadata to update. Note: In production, implement actual URL metadata fetching.'
    });
  })
);

export default router;

