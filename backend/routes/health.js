const express = require('express');

const router = express.Router();

/**
 * @openapi
 * /health:
 *   get:
 *     summary: Health check
 *     description: Проверка доступности сервиса.
 *     tags:
 *       - Monitoring
 *     responses:
 *       200:
 *         description: Service is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: ok
 *                 uptime:
 *                   type: number
 *                   example: 123.45
 */
router.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

module.exports = router;
