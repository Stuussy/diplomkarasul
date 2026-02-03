const express = require('express');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');

const router = express.Router();

router.get('/', auth(), async (req, res) => {
  const { unread } = req.query;
  const filter = { user: req.user.id };
  if (unread === 'true') filter.isRead = false;

  const notifications = await Notification.find(filter).sort({ createdAt: -1 }).limit(50);
  res.json(notifications);
});

router.patch('/:id/read', auth(), async (req, res) => {
  const notification = await Notification.findOneAndUpdate(
    { _id: req.params.id, user: req.user.id },
    { isRead: true },
    { new: true },
  );
  if (!notification) {
    return res.status(404).json({ message: 'Уведомление не найдено.' });
  }
  res.json(notification);
});

router.patch('/read-all', auth(), async (req, res) => {
  await Notification.updateMany({ user: req.user.id, isRead: false }, { isRead: true });
  res.json({ success: true });
});

module.exports = router;
