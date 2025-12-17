import express from 'express';
import bcrypt from 'bcryptjs';
import { body } from 'express-validator';
import { authRequired } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { createRateLimiter, sensitiveLimiter, writeLimiter } from '../middleware/rateLimiter.js';
import { handleValidationErrors } from '../middleware/validation.js';

const router = express.Router();

router.use(authRequired);

// GET /api/users/profile - Get user profile
router.get(
  '/profile',
  asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const db = req.db;

    const result = await db.query(
      `SELECT id, email, full_name, profile_image_url, created_at, updated_at, 
              last_login_at, email_verified, is_active
       FROM calendarnotes.users 
       WHERE id = $1`,
      [userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: result.rows[0] });
  })
);

// PUT /api/users/profile - Update profile
router.put(
  '/profile',
  createRateLimiter(writeLimiter),
  [
    body('full_name').optional().isString().isLength({ max: 255 }),
    body('profile_image_url').optional().isURL()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { full_name, profile_image_url } = req.body;
    const userId = req.user.id;
    const db = req.db;

    const updates = [];
    const values = [];
    let paramIndex = 1;

    if (full_name !== undefined) {
      updates.push(`full_name = $${paramIndex}`);
      values.push(full_name);
      paramIndex++;
    }

    if (profile_image_url !== undefined) {
      updates.push(`profile_image_url = $${paramIndex}`);
      values.push(profile_image_url);
      paramIndex++;
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    values.push(userId);
    const result = await db.query(
      `UPDATE calendarnotes.users 
       SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex}
       RETURNING id, email, full_name, profile_image_url, created_at, updated_at, last_login_at, email_verified, is_active`,
      values
    );

    res.json({ user: result.rows[0] });
  })
);

// PUT /api/users/password - Change password
router.put(
  '/password',
  createRateLimiter(sensitiveLimiter),
  [
    body('current_password').isString().notEmpty().withMessage('Current password is required'),
    body('new_password').isLength({ min: 8 }).withMessage('New password must be at least 8 characters')
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { current_password, new_password } = req.body;
    const userId = req.user.id;
    const db = req.db;

    // Get current password hash
    const userResult = await db.query(
      'SELECT password_hash FROM calendarnotes.users WHERE id = $1',
      [userId]
    );

    if (userResult.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Verify current password
    const isValid = await bcrypt.compare(current_password, userResult.rows[0].password_hash);
    if (!isValid) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    // Hash new password
    const newHash = await bcrypt.hash(new_password, 10);

    // Update password
    await db.query(
      'UPDATE calendarnotes.users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
      [newHash, userId]
    );

    res.json({ success: true, message: 'Password updated successfully' });
  })
);

// DELETE /api/users/account - Delete account and all data
router.delete(
  '/account',
  createRateLimiter(sensitiveLimiter),
  [
    body('password').isString().notEmpty().withMessage('Password is required for account deletion')
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { password } = req.body;
    const userId = req.user.id;
    const db = req.db;

    // Verify password
    const userResult = await db.query(
      'SELECT password_hash FROM calendarnotes.users WHERE id = $1',
      [userId]
    );

    if (userResult.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const isValid = await bcrypt.compare(password, userResult.rows[0].password_hash);
    if (!isValid) {
      return res.status(401).json({ error: 'Password is incorrect' });
    }

    // Delete user (cascade will delete all related data due to ON DELETE CASCADE)
    await db.query('DELETE FROM calendarnotes.users WHERE id = $1', [userId]);

    res.json({ success: true, message: 'Account and all data deleted successfully' });
  })
);

// GET /api/users/stats - Get user statistics
router.get(
  '/stats',
  asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const db = req.db;

    // Get counts for each entity type
    const [eventsResult, notesResult, todosResult, bookmarksResult] = await Promise.all([
      db.query(
        'SELECT COUNT(*) FROM calendarnotes.calendar_events WHERE user_id = $1 AND deleted_at IS NULL',
        [userId]
      ),
      db.query(
        'SELECT COUNT(*) FROM calendarnotes.notes WHERE user_id = $1 AND deleted_at IS NULL',
        [userId]
      ),
      db.query(
        'SELECT COUNT(*) FROM calendarnotes.todo_items WHERE user_id = $1 AND deleted_at IS NULL',
        [userId]
      ),
      db.query(
        'SELECT COUNT(*) FROM calendarnotes.bookmarks WHERE user_id = $1 AND deleted_at IS NULL',
        [userId]
      )
    ]);

    // Get completed todos count
    const completedTodosResult = await db.query(
      'SELECT COUNT(*) FROM calendarnotes.todo_items WHERE user_id = $1 AND is_completed = TRUE AND deleted_at IS NULL',
      [userId]
    );

    // Get collections count
    const collectionsResult = await db.query(
      'SELECT COUNT(*) FROM calendarnotes.collections WHERE user_id = $1',
      [userId]
    );

    // Get voicenotes count
    const voicenotesResult = await db.query(
      'SELECT COUNT(*) FROM calendarnotes.voice_notes WHERE user_id = $1 AND deleted_at IS NULL',
      [userId]
    );

    res.json({
      stats: {
        totalEvents: parseInt(eventsResult.rows[0].count),
        totalNotes: parseInt(notesResult.rows[0].count),
        totalTodos: parseInt(todosResult.rows[0].count),
        completedTodos: parseInt(completedTodosResult.rows[0].count),
        totalBookmarks: parseInt(bookmarksResult.rows[0].count),
        totalCollections: parseInt(collectionsResult.rows[0].count),
        totalVoicenotes: parseInt(voicenotesResult.rows[0].count)
      }
    });
  })
);

export default router;

