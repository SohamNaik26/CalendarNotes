import express from 'express';
import { body, query } from 'express-validator';
import { authRequired } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { createRateLimiter, writeLimiter } from '../middleware/rateLimiter.js';
import { handleValidationErrors } from '../middleware/validation.js';

const router = express.Router();

router.use(authRequired);

// POST /api/sync/pull - Get changes since last sync
router.post(
  '/pull',
  [
    query('lastSyncTimestamp').optional().isISO8601(),
    query('device_id').optional().isString()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { lastSyncTimestamp, device_id } = req.query;
    const userId = req.user.id;
    const db = req.db;

    const timestamp = lastSyncTimestamp || new Date(0).toISOString();

    // Get all entities modified after timestamp
    const entityTypes = [
      'calendar_events',
      'notes',
      'todo_items',
      'bookmarks',
      'collections',
      'voice_notes'
    ];

    const changes = {};

    for (const entityType of entityTypes) {
      let tableName = entityType;
      if (entityType === 'calendar_events') {
        tableName = 'calendar_events';
      } else if (entityType === 'todo_items') {
        tableName = 'todo_items';
      } else if (entityType === 'voice_notes') {
        tableName = 'voice_notes';
      }

      // Get created/updated records
      const result = await db.query(
        `SELECT * FROM calendarnotes.${tableName} 
         WHERE user_id = $1 
         AND (created_at > $2 OR updated_at > $2)
         AND deleted_at IS NULL
         ORDER BY updated_at DESC`,
        [userId, timestamp]
      );

      // Get deleted records (soft deletes)
      const deletedResult = await db.query(
        `SELECT id, deleted_at FROM calendarnotes.${tableName} 
         WHERE user_id = $1 
         AND deleted_at > $2
         ORDER BY deleted_at DESC`,
        [userId, timestamp]
      );

      changes[entityType] = {
        created: result.rows.filter(r => new Date(r.created_at) > new Date(timestamp)),
        updated: result.rows.filter(r => 
          new Date(r.updated_at) > new Date(timestamp) && 
          new Date(r.created_at) <= new Date(timestamp)
        ),
        deleted: deletedResult.rows.map(r => ({ id: r.id, deleted_at: r.deleted_at }))
      };
    }

    // Update sync log
    if (device_id) {
      await db.query(
        `INSERT INTO calendarnotes.sync_log (user_id, device_id, entity_type, entity_id, action, synced_at, sync_status)
         VALUES ($1, $2, $3, $4, $5, NOW(), 'completed')
         ON CONFLICT DO NOTHING`,
        [userId, device_id, 'sync', userId, 'update']
      );
    }

    res.json({
      changes,
      syncTimestamp: new Date().toISOString(),
      lastSyncTimestamp: timestamp
    });
  })
);

// POST /api/sync/push - Push local changes to server
router.post(
  '/push',
  createRateLimiter(writeLimiter),
  [
    body('changes').isArray().withMessage('changes must be an array'),
    body('changes.*.entity_type').isIn(['calendar_events', 'notes', 'todo_items', 'bookmarks', 'collections', 'voice_notes']),
    body('changes.*.entity_id').isUUID(),
    body('changes.*.action').isIn(['create', 'update', 'delete']),
    body('changes.*.data').optional().isObject(),
    body('device_id').optional().isString()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { changes, device_id } = req.body;
    const userId = req.user.id;
    const db = req.db;

    const results = {
      processed: 0,
      errors: []
    };

    for (let i = 0; i < changes.length; i++) {
      const change = changes[i];
      try {
        const { entity_type, entity_id, action, data } = change;
        let tableName = entity_type;

        if (action === 'create') {
          // Insert new record
          if (!data) {
            results.errors.push({ index: i, error: 'data is required for create action' });
            continue;
          }

          // Build insert query dynamically based on entity type
          // This is simplified - in production, you'd want more robust handling
          const fields = Object.keys(data).filter(k => k !== 'id' && k !== 'user_id');
          const values = fields.map((_, idx) => `$${idx + 2}`);
          const insertValues = [userId, ...fields.map(f => data[f])];

          await db.query(
            `INSERT INTO calendarnotes.${tableName} (user_id, ${fields.join(', ')})
             VALUES ($1, ${values.join(', ')})
             ON CONFLICT (id) DO NOTHING`,
            insertValues
          );

        } else if (action === 'update') {
          // Update existing record
          if (!data) {
            results.errors.push({ index: i, error: 'data is required for update action' });
            continue;
          }

          // Check ownership
          const ownershipCheck = await db.query(
            `SELECT id FROM calendarnotes.${tableName} WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
            [entity_id, userId]
          );

          if (ownershipCheck.rowCount === 0) {
            results.errors.push({ index: i, error: 'Resource not found or access denied' });
            continue;
          }

          const updateFields = Object.keys(data).filter(k => k !== 'id' && k !== 'user_id' && k !== 'created_at');
          const updates = updateFields.map((f, idx) => `${f} = $${idx + 1}`);
          const updateValues = updateFields.map(f => data[f]);
          updateValues.push(entity_id);

          await db.query(
            `UPDATE calendarnotes.${tableName} 
             SET ${updates.join(', ')}, updated_at = NOW()
             WHERE id = $${updateValues.length} AND deleted_at IS NULL`,
            updateValues
          );

        } else if (action === 'delete') {
          // Soft delete
          const ownershipCheck = await db.query(
            `SELECT id FROM calendarnotes.${tableName} WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
            [entity_id, userId]
          );

          if (ownershipCheck.rowCount === 0) {
            results.errors.push({ index: i, error: 'Resource not found or access denied' });
            continue;
          }

          await db.query(
            `UPDATE calendarnotes.${tableName} 
             SET deleted_at = NOW()
             WHERE id = $1 AND deleted_at IS NULL`,
            [entity_id]
          );
        }

        // Log sync
        if (device_id) {
          await db.query(
            `INSERT INTO calendarnotes.sync_log (user_id, device_id, entity_type, entity_id, action, synced_at, sync_status)
             VALUES ($1, $2, $3, $4, $5, NOW(), 'completed')`,
            [userId, device_id, entity_type, entity_id, action]
          );
        }

        results.processed++;

      } catch (err) {
        results.errors.push({ index: i, error: err.message });
      }
    }

    res.json({
      success: results.errors.length === 0,
      processed: results.processed,
      total: changes.length,
      errors: results.errors.length > 0 ? results.errors : undefined
    });
  })
);

// GET /api/sync/status - Get sync status for user
router.get(
  '/status',
  asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const db = req.db;

    // Get last sync time
    const lastSyncResult = await db.query(
      `SELECT MAX(synced_at) as last_sync FROM calendarnotes.sync_log WHERE user_id = $1`,
      [userId]
    );
    const lastSync = lastSyncResult.rows[0]?.last_sync || null;

    // Get pending changes count (records modified but not synced)
    const pendingCounts = {};
    const entityTypes = [
      'calendar_events',
      'notes',
      'todo_items',
      'bookmarks',
      'collections',
      'voice_notes'
    ];

    for (const entityType of entityTypes) {
      let tableName = entityType;
      if (lastSync) {
        const result = await db.query(
          `SELECT COUNT(*) FROM calendarnotes.${tableName} 
           WHERE user_id = $1 
           AND (updated_at > $2 OR created_at > $2 OR deleted_at > $2)
           AND (synced_at IS NULL OR synced_at < updated_at OR synced_at < COALESCE(deleted_at, '1970-01-01'))`,
          [userId, lastSync]
        );
        pendingCounts[entityType] = parseInt(result.rows[0].count);
      } else {
        const result = await db.query(
          `SELECT COUNT(*) FROM calendarnotes.${tableName} 
           WHERE user_id = $1 AND deleted_at IS NULL`,
          [userId]
        );
        pendingCounts[entityType] = parseInt(result.rows[0].count);
      }
    }

    const totalPending = Object.values(pendingCounts).reduce((a, b) => a + b, 0);

    res.json({
      lastSync,
      pendingChanges: {
        total: totalPending,
        byType: pendingCounts
      }
    });
  })
);

// POST /api/sync/resolve-conflict - Resolve sync conflict
router.post(
  '/resolve-conflict',
  createRateLimiter(writeLimiter),
  [
    body('entity_type').isIn(['calendar_events', 'notes', 'todo_items', 'bookmarks', 'collections', 'voice_notes']),
    body('entity_id').isUUID(),
    body('strategy').isIn(['server', 'client', 'merge']).withMessage('Strategy must be server, client, or merge'),
    body('client_data').optional().isObject(),
    body('server_data').optional().isObject()
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const { entity_type, entity_id, strategy, client_data, server_data } = req.body;
    const userId = req.user.id;
    const db = req.db;

    let tableName = entity_type;

    // Get server version
    const serverResult = await db.query(
      `SELECT * FROM calendarnotes.${tableName} WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [entity_id, userId]
    );

    if (serverResult.rowCount === 0) {
      return res.status(404).json({ error: 'Entity not found' });
    }

    let resolvedData;

    if (strategy === 'server') {
      // Use server version
      resolvedData = serverResult.rows[0];
    } else if (strategy === 'client') {
      // Use client version - update server
      if (!client_data) {
        return res.status(400).json({ error: 'client_data required for client strategy' });
      }

      const updateFields = Object.keys(client_data).filter(k => k !== 'id' && k !== 'user_id' && k !== 'created_at');
      const updates = updateFields.map((f, idx) => `${f} = $${idx + 1}`);
      const updateValues = updateFields.map(f => client_data[f]);
      updateValues.push(entity_id);

      const updateResult = await db.query(
        `UPDATE calendarnotes.${tableName} 
         SET ${updates.join(', ')}, updated_at = NOW()
         WHERE id = $${updateValues.length} AND deleted_at IS NULL
         RETURNING *`,
        updateValues
      );

      resolvedData = updateResult.rows[0];
    } else if (strategy === 'merge') {
      // Merge both versions
      if (!client_data || !server_data) {
        return res.status(400).json({ error: 'Both client_data and server_data required for merge strategy' });
      }

      // Simple merge: prefer client for most fields, keep server timestamps
      const merged = {
        ...serverResult.rows[0],
        ...client_data,
        id: entity_id,
        user_id: userId,
        created_at: serverResult.rows[0].created_at,
        updated_at: new Date().toISOString()
      };

      const updateFields = Object.keys(merged).filter(k => k !== 'id' && k !== 'user_id' && k !== 'created_at');
      const updates = updateFields.map((f, idx) => `${f} = $${idx + 1}`);
      const updateValues = updateFields.map(f => merged[f]);
      updateValues.push(entity_id);

      const mergeResult = await db.query(
        `UPDATE calendarnotes.${tableName} 
         SET ${updates.join(', ')}, updated_at = NOW()
         WHERE id = $${updateValues.length} AND deleted_at IS NULL
         RETURNING *`,
        updateValues
      );

      resolvedData = mergeResult.rows[0];
    }

    res.json({
      resolved: resolvedData,
      strategy,
      message: 'Conflict resolved'
    });
  })
);

export default router;

