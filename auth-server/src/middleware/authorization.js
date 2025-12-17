// Authorization middleware to check if user owns a resource

export function checkResourceOwnership(tableName, resourceIdParam = 'id') {
  return async (req, res, next) => {
    try {
      const resourceId = req.params[resourceIdParam];
      const userId = req.user.id;
      const db = req.db;

      // Check if resource exists and belongs to user
      const result = await db.query(
        `SELECT id FROM calendarnotes.${tableName} WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
        [resourceId, userId]
      );

      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Resource not found or access denied' });
      }

      req.resourceId = resourceId;
      next();
    } catch (err) {
      console.error('Authorization error:', err);
      return res.status(500).json({ error: 'Authorization check failed' });
    }
  };
}

