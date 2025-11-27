const express = require('express');
const Message = require('../models/Message');
const auth = require('../middleware/auth');
const upload = require('../middleware/upload');

const router = express.Router();

router.post('/', auth(['patient']), upload.array('files', 3), async (req, res) => {
  try {
    const attachments = (req.files || []).map((file) => ({
      url: file.path,
      cloudinaryId: file.filename,
      format: file.mimetype,
    }));

    const message = await Message.create({
      patient: req.user.id,
      sender: req.user.id,
      content: req.body.content,
      attachments,
    });

    res.status(201).json(message);
  } catch (error) {
    console.error('Ошибка отправки сообщения:', error);
    res.status(500).json({ message: 'Не удалось отправить сообщение.' });
  }
});

router.get('/', auth(['admin', 'director']), async (req, res) => {
  const { status } = req.query;
  const filter = {};
  if (status) filter.status = status;
  const messages = await Message.find(filter).populate('patient', 'firstName lastName phone');
  res.json(messages);
});

router.patch('/:id', auth(['admin', 'director']), async (req, res) => {
  const { status, assignedTo } = req.body;
  const message = await Message.findByIdAndUpdate(
    req.params.id,
    {
      status,
      assignedTo: assignedTo || req.user.id,
    },
    { new: true },
  );
  if (!message) {
    return res.status(404).json({ message: 'Сообщение не найдено.' });
  }
  res.json(message);
});

module.exports = router;
