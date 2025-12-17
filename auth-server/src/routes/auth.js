import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { body, validationResult } from 'express-validator';
import { authRequired } from '../middleware/auth.js';

const router = express.Router();

function signAccessToken(user) {
  return jwt.sign(
    { email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRY || '7d', subject: user.id }
  );
}

function signRefreshToken(user) {
  return jwt.sign(
    { email: user.email, type: 'refresh' },
    process.env.JWT_SECRET,
    { expiresIn: process.env.REFRESH_TOKEN_EXPIRY || '30d', subject: user.id }
  );
}

// POST /api/auth/register
router.post(
  '/register',
  body('email').isEmail(),
  body('password').isLength({ min: 8 }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    const { email, password } = req.body;
    const db = req.db;
    try {
      const existing = await db.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
      if (existing.rowCount > 0) {
        return res.status(409).json({ error: 'User already exists' });
      }
      const hash = await bcrypt.hash(password, 10);
      const result = await db.query(
        'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email, created_at, email_verified',
        [email.toLowerCase(), hash]
      );
      const user = result.rows[0];
      const access = signAccessToken(user);
      const refresh = signRefreshToken(user);
      await db.query('UPDATE users SET refresh_token = $1 WHERE id = $2', [refresh, user.id]);
      return res.status(201).json({ user, token: access, refreshToken: refresh });
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: 'Server error' });
    }
  }
);

// POST /api/auth/login
router.post(
  '/login',
  body('email').isEmail(),
  body('password').isLength({ min: 8 }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    const { email, password } = req.body;
    const db = req.db;
    try {
      const result = await db.query('SELECT id, email, password_hash FROM users WHERE email = $1', [email.toLowerCase()]);
      if (result.rowCount === 0) return res.status(401).json({ error: 'Invalid credentials' });
      const user = result.rows[0];
      const ok = await bcrypt.compare(password, user.password_hash);
      if (!ok) return res.status(401).json({ error: 'Invalid credentials' });
      const access = signAccessToken(user);
      const refresh = signRefreshToken(user);
      await db.query('UPDATE users SET last_login_at = NOW(), refresh_token = $1 WHERE id = $2', [refresh, user.id]);
      const userRow = await db.query('SELECT id, email, created_at, email_verified, last_login_at FROM users WHERE id = $1', [user.id]);
      const userOut = userRow.rows[0] || { id: user.id, email: user.email };
      return res.json({
        user: userOut,
        token: access,
        refreshToken: refresh
      });
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: 'Server error' });
    }
  }
);

// POST /api/auth/logout
router.post('/logout', authRequired, async (req, res) => {
  try {
    const db = req.db;
    await db.query('UPDATE users SET refresh_token = NULL WHERE id = $1', [req.user.id]);
    return res.json({ success: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/auth/refresh-token
router.post('/refresh-token', async (req, res) => {
  try {
    const { refreshToken } = req.body || {};
    if (!refreshToken) return res.status(400).json({ error: 'Missing refreshToken' });
    const decoded = jwt.verify(refreshToken, process.env.JWT_SECRET);
    if (decoded.type !== 'refresh') return res.status(400).json({ error: 'Invalid token type' });
    const db = req.db;
    const result = await db.query('SELECT id, email, refresh_token FROM users WHERE id = $1', [decoded.sub]);
    if (result.rowCount === 0) return res.status(401).json({ error: 'Invalid token' });
    const user = result.rows[0];
    if (user.refresh_token !== refreshToken) return res.status(401).json({ error: 'Token revoked' });
    const access = signAccessToken(user);
    return res.json({ token: access });
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Refresh token expired' });
    }
    console.error(err);
    return res.status(401).json({ error: 'Invalid refresh token' });
  }
});

// POST /api/auth/forgot-password (stubbed: issue reset token)
router.post(
  '/forgot-password',
  body('email').isEmail(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    // In a real implementation, generate a one-time token and email it
    return res.json({ success: true, message: 'If the email exists, a reset link will be sent.' });
  }
);

// POST /api/auth/reset-password (stub: verify token + update)
router.post(
  '/reset-password',
  body('token').isString().notEmpty(),
  body('password').isLength({ min: 8 }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    // Here you would verify the token and set the new password
    return res.json({ success: true });
  }
);

// GET /api/auth/verify-email/:token (stub)
router.get('/verify-email/:token', async (req, res) => {
  // Verify token and mark email as verified
  return res.json({ success: true });
});

// GET /api/auth/me
router.get('/me', authRequired, async (req, res) => {
  const db = req.db;
  try {
    const result = await db.query('SELECT id, email, email_verified, created_at, last_login_at FROM users WHERE id = $1', [req.user.id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
    return res.json({ user: result.rows[0] });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

export default router;


