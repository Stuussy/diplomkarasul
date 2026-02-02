const express = require('express');
const Message = require('../models/Message');
const auth = require('../middleware/auth');
const upload = require('../middleware/upload');

const router = express.Router();

const supportScopes = ['patient', 'support_manager', 'superadmin'];

router.post('/', auth(['patient']), upload.array('files', 3), async (req, res) => {
  try {
    if (!req.body.category || !req.body.category.trim()) {
      return res.status(400).json({ message: 'Категория обязательна.' });
    }
    if (!req.body.content || !req.body.content.trim()) {
      return res.status(400).json({ message: 'Описание обязательно.' });
    }
    const attachments = (req.files || []).map((file) => ({
      url: file.path,
      cloudinaryId: file.filename,
      format: file.mimetype,
    }));

    const message = await Message.create({
      patient: req.user.id,
      sender: req.user.id,
      category: req.body.category.trim(),
      content: req.body.content,
      attachments,
      history: [
        {
          sender: req.user.id,
          content: req.body.content,
        },
      ],
      lastMessageAt: new Date(),
    });

    const populated = await Message.findById(message._id)
      .populate('patient', 'firstName lastName phone')
      .populate('history.sender', 'firstName lastName role');

    res.status(201).json(populated);
  } catch (error) {
    console.error('Ошибка отправки сообщения:', error);
    res.status(500).json({ message: 'Не удалось отправить сообщение.' });
  }
});

router.get('/', auth(['support_manager', 'superadmin']), async (req, res) => {
  const { status } = req.query;
  const filter = {};
  if (status) filter.status = status;
  const messages = await Message.find(filter)
    .sort({ lastMessageAt: -1 })
    .populate('patient', 'firstName lastName phone')
    .populate('history.sender', 'firstName lastName role');
  res.json(messages);
});

router.get('/my', auth(['patient']), async (req, res) => {
  const messages = await Message.find({ patient: req.user.id })
    .sort({ lastMessageAt: -1 })
    .populate('patient', 'firstName lastName phone')
    .populate('history.sender', 'firstName lastName role');
  res.json(messages);
});

router.get('/:id/history', auth(supportScopes), async (req, res) => {
  const message = await Message.findById(req.params.id)
    .populate('patient', 'firstName lastName phone')
    .populate('history.sender', 'firstName lastName role');

  if (!message) {
    return res.status(404).json({ message: 'Обращение не найдено.' });
  }

  if (req.user.role === 'patient' && message.patient.toString() !== req.user.id) {
    return res.status(403).json({ message: 'Нет доступа к истории обращения.' });
  }

  res.json(message.history);
});

router.post('/:id/reply', auth(supportScopes), async (req, res) => {
  const { content } = req.body;
  if (!content || !content.trim()) {
    return res.status(400).json({ message: 'Сообщение не может быть пустым.' });
  }

  const message = await Message.findById(req.params.id)
    .populate('patient', 'firstName lastName phone')
    .populate('history.sender', 'firstName lastName role');

  if (!message) {
    return res.status(404).json({ message: 'Обращение не найдено.' });
  }
  if (req.user.role === 'patient' && message.patient.toString() !== req.user.id) {
    return res.status(403).json({ message: 'Нет доступа.' });
  }

  message.history.push({
    sender: req.user.id,
    content: content.trim(),
  });
  message.content = content.trim();
  message.sender = req.user.id;
  message.lastMessageAt = new Date();

  if (req.user.role === 'patient') {
    if (message.status === 'resolved') {
      message.status = 'open';
    }
  } else {
    if (!message.assignedTo) {
      message.assignedTo = req.user.id;
    }
    if (message.status === 'open') {
      message.status = 'in_progress';
    }
  }

  await message.save();
  await message.populate('history.sender', 'firstName lastName role');

  res.json(message);
});

router.patch('/:id', auth(['support_manager', 'superadmin']), async (req, res) => {
  const { status, assignedTo } = req.body;
  const message = await Message.findByIdAndUpdate(
    req.params.id,
    {
      status,
      assignedTo: assignedTo || req.user.id,
    },
    { new: true },
  )
    .populate('patient', 'firstName lastName phone')
    .populate('history.sender', 'firstName lastName role');

  if (!message) {
    return res.status(404).json({ message: 'Сообщение не найдено.' });
  }
  res.json(message);
});

module.exports = router;
