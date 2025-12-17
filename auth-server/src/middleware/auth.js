import jwt from 'jsonwebtoken';

export function authRequired(req, res, next) {
  try {
    const header = req.headers['authorization'];
    if (!header) return res.status(401).json({ error: 'Missing Authorization header' });
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) return res.status(401).json({ error: 'Invalid Authorization header' });
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { id: decoded.sub, email: decoded.email };
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
}


