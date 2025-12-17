import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { body, query, param } from 'express-validator';
import { authRequired } from '../middleware/auth.js';
import { checkResourceOwnership } from '../middleware/authorization.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { createRateLimiter, writeLimiter } from '../middleware/rateLimiter.js';
import { handleValidationErrors, validators } from '../middleware/validation.js';

const router = express.Router();

router.use(authRequired);

// Configure multer for audio file uploads
const uploadDir = process.env.UPLOAD_DIR || './uploads/voicenotes';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, `voicenote-${req.user.id}-${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 50 * 1024 * 1024 // 50MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a', 'audio/aac', 'audio/ogg'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only audio files are allowed.'));
    }
  }
});

// GET /api/voicenotes - Get all voicenotes
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
      `SELECT id, user_id, transcription, duration_seconds, file_size_bytes, 
              bitrate_kbps, sample_rate_hz, linked_note_id, linked_event_id, 
              linked_task_id, is_favorite, is_archived, created_at, updated_at
       FROM calendarnotes.voice_notes 
       WHERE user_id = $1 AND deleted_at IS NULL
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );

    const countResult = await db.query(
      'SELECT COUNT(*) FROM calendarnotes.voice_notes WHERE user_id = $1 AND deleted_at IS NULL',
      [userId]
    );
    const total = parseInt(countResult.rows[0].count);

    res.json({
      voicenotes: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit)
      }
    });
  })
);

// GET /api/voicenotes/:id - Get single voicenote
router.get(
  '/:id',
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('voice_notes'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const result = await db.query(
      `SELECT id, user_id, transcription, duration_seconds, file_size_bytes, 
              bitrate_kbps, sample_rate_hz, linked_note_id, linked_event_id, 
              linked_task_id, is_favorite, is_archived, created_at, updated_at
       FROM calendarnotes.voice_notes 
       WHERE id = $1 AND deleted_at IS NULL`,
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Voicenote not found' });
    }

    res.json({ voicenote: result.rows[0] });
  })
);

// POST /api/voicenotes - Upload audio file
router.post(
  '/',
  createRateLimiter(writeLimiter),
  upload.single('audio'),
  [
    body('linked_note_id').optional().isUUID(),
    body('linked_event_id').optional().isUUID(),
    body('linked_task_id').optional().isUUID()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'Audio file is required' });
    }

    const {
      linked_note_id,
      linked_event_id,
      linked_task_id
    } = req.body;
    const userId = req.user.id;
    const db = req.db;

    // Validate linked entities if provided
    if (linked_event_id) {
      const eventCheck = await db.query(
        'SELECT id FROM calendarnotes.calendar_events WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [linked_event_id, userId]
      );
      if (eventCheck.rowCount === 0) {
        fs.unlinkSync(req.file.path); // Clean up uploaded file
        return res.status(400).json({ error: 'Invalid linked_event_id' });
      }
    }

    if (linked_note_id) {
      const noteCheck = await db.query(
        'SELECT id FROM calendarnotes.notes WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [linked_note_id, userId]
      );
      if (noteCheck.rowCount === 0) {
        fs.unlinkSync(req.file.path);
        return res.status(400).json({ error: 'Invalid linked_note_id' });
      }
    }

    if (linked_task_id) {
      const taskCheck = await db.query(
        'SELECT id FROM calendarnotes.todo_items WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [linked_task_id, userId]
      );
      if (taskCheck.rowCount === 0) {
        fs.unlinkSync(req.file.path);
        return res.status(400).json({ error: 'Invalid linked_task_id' });
      }
    }

    // Get file stats
    const stats = fs.statSync(req.file.path);
    const fileSizeBytes = stats.size;

    // In production, you would extract audio metadata (duration, bitrate, sample rate)
    // For now, we'll use placeholder values
    const result = await db.query(
      `INSERT INTO calendarnotes.voice_notes 
       (user_id, audio_file_path, file_size_bytes, linked_note_id, linked_event_id, linked_task_id)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        userId,
        req.file.path,
        fileSizeBytes,
        linked_note_id || null,
        linked_event_id || null,
        linked_task_id || null
      ]
    );

    res.status(201).json({ voicenote: result.rows[0] });
  })
);

// PUT /api/voicenotes/:id - Update voicenote
router.put(
  '/:id',
  createRateLimiter(writeLimiter),
  [
    validators.uuid,
    body('transcription').optional().isString(),
    body('linked_note_id').optional().isUUID(),
    body('linked_event_id').optional().isUUID(),
    body('linked_task_id').optional().isUUID(),
    body('is_favorite').optional().isBoolean(),
    body('is_archived').optional().isBoolean()
  ],
  handleValidationErrors,
  checkResourceOwnership('voice_notes'),
  asyncHandler(async (req, res) => {
    const db = req.db;
    const allowedFields = [
      'transcription', 'linked_note_id', 'linked_event_id', 'linked_task_id',
      'is_favorite', 'is_archived'
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

    // Validate linked entities if being updated
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

    if (req.body.linked_task_id) {
      const taskCheck = await db.query(
        'SELECT id FROM calendarnotes.todo_items WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [req.body.linked_task_id, req.user.id]
      );
      if (taskCheck.rowCount === 0) {
        return res.status(400).json({ error: 'Invalid linked_task_id' });
      }
    }

    values.push(req.resourceId);
    const result = await db.query(
      `UPDATE calendarnotes.voice_notes 
       SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex} AND deleted_at IS NULL
       RETURNING *`,
      values
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Voicenote not found' });
    }

    res.json({ voicenote: result.rows[0] });
  })
);

// DELETE /api/voicenotes/:id - Soft delete voicenote
router.delete(
  '/:id',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('voice_notes'),
  asyncHandler(async (req, res) => {
    const db = req.db;

    // Get file path before deleting
    const voicenoteResult = await db.query(
      'SELECT audio_file_path FROM calendarnotes.voice_notes WHERE id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );

    if (voicenoteResult.rowCount === 0) {
      return res.status(404).json({ error: 'Voicenote not found' });
    }

    // Soft delete in database
    const result = await db.query(
      `UPDATE calendarnotes.voice_notes 
       SET deleted_at = NOW() 
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING id`,
      [req.resourceId]
    );

    // In production, you might want to schedule actual file deletion
    // or move files to a trash directory for recovery

    res.json({ success: true, message: 'Voicenote deleted' });
  })
);

// POST /api/voicenotes/:id/transcribe - Trigger transcription
router.post(
  '/:id/transcribe',
  createRateLimiter(writeLimiter),
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('voice_notes'),
  asyncHandler(async (req, res) => {
    const db = req.db;

    // Get voicenote with file path
    const voicenoteResult = await db.query(
      'SELECT audio_file_path FROM calendarnotes.voice_notes WHERE id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );

    if (voicenoteResult.rowCount === 0) {
      return res.status(404).json({ error: 'Voicenote not found' });
    }

    const filePath = voicenoteResult.rows[0].audio_file_path;

    // In production, integrate with a transcription service like:
    // - Google Cloud Speech-to-Text
    // - AWS Transcribe
    // - OpenAI Whisper API
    // - AssemblyAI
    
    // Placeholder transcription
    const transcription = 'Transcription service not implemented. In production, integrate with a speech-to-text API.';

    // Update transcription in database
    const updateResult = await db.query(
      `UPDATE calendarnotes.voice_notes 
       SET transcription = $1, updated_at = NOW()
       WHERE id = $2 AND deleted_at IS NULL
       RETURNING *`,
      [transcription, req.resourceId]
    );

    res.json({
      voicenote: updateResult.rows[0],
      message: 'Transcription completed. Note: In production, implement actual transcription service.'
    });
  })
);

// GET /api/voicenotes/:id/audio - Stream audio file
router.get(
  '/:id/audio',
  [validators.uuid],
  handleValidationErrors,
  checkResourceOwnership('voice_notes'),
  asyncHandler(async (req, res) => {
    const db = req.db;

    const result = await db.query(
      'SELECT audio_file_path FROM calendarnotes.voice_notes WHERE id = $1 AND deleted_at IS NULL',
      [req.resourceId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Voicenote not found' });
    }

    const filePath = result.rows[0].audio_file_path;

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'Audio file not found' });
    }

    const stat = fs.statSync(filePath);
    const fileSize = stat.size;
    const range = req.headers.range;

    if (range) {
      // Support range requests for streaming
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
      const chunksize = (end - start) + 1;
      const file = fs.createReadStream(filePath, { start, end });
      const head = {
        'Content-Range': `bytes ${start}-${end}/${fileSize}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': chunksize,
        'Content-Type': 'audio/mpeg'
      };
      res.writeHead(206, head);
      file.pipe(res);
    } else {
      // Full file download
      const head = {
        'Content-Length': fileSize,
        'Content-Type': 'audio/mpeg'
      };
      res.writeHead(200, head);
      fs.createReadStream(filePath).pipe(res);
    }
  })
);

export default router;

