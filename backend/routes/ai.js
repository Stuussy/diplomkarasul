/* eslint-disable no-console */
const express = require('express');
const auth = require('../middleware/auth');
const { groqChat, hasGroqKey } = require('../services/groq');
const AiMessage = require('../models/AiMessage');

const router = express.Router();

const SYSTEM_PROMPT = `Ты — стоматологический ИИ-ассистент клиники Dental AI.
Правила: отвечай ТОЛЬКО по теме стоматологии и здоровья зубов/дёсен. На посторонние темы вежливо откажи.
НЕ ставь диагнозы. При серьёзных симптомах рекомендуй обратиться к врачу.
Отвечай на русском, кратко (до 150 слов), без лишних вступлений.`;

// Сколько прошлых сообщений передавать ИИ для контекста диалога.
const CONTEXT_LIMIT = 8;

// GET /api/ai/history — история диалога текущего пользователя (по возрастанию)
router.get('/history', auth(), async (req, res) => {
  try {
    const messages = await AiMessage.find({ user: req.user.id })
      .sort({ createdAt: 1 })
      .limit(200)
      .lean();
    return res.json(
      messages.map((m) => ({
        id: m._id,
        role: m.role,
        content: m.content,
        createdAt: m.createdAt,
      })),
    );
  } catch (error) {
    console.error('AI history failed:', error.message);
    return res.status(500).json({ message: 'Не удалось загрузить историю.' });
  }
});

// DELETE /api/ai/history — очистить историю диалога
router.delete('/history', auth(), async (req, res) => {
  try {
    await AiMessage.deleteMany({ user: req.user.id });
    return res.json({ message: 'История очищена.' });
  } catch (error) {
    console.error('AI history clear failed:', error.message);
    return res.status(500).json({ message: 'Не удалось очистить историю.' });
  }
});

// POST /api/ai/consult
router.post('/consult', auth(), async (req, res) => {
  const { question } = req.body;
  if (!question || String(question).trim().length < 3) {
    return res.status(400).json({ message: 'Введите вопрос.' });
  }
  if (!hasGroqKey()) {
    return res.status(503).json({ message: 'AI-консультация временно недоступна.' });
  }

  // Trim question to avoid huge input tokens
  const trimmedQuestion = String(question).trim().slice(0, 500);

  try {
    // Подтягиваем последние сообщения для контекста диалога
    const recent = await AiMessage.find({ user: req.user.id })
      .sort({ createdAt: -1 })
      .limit(CONTEXT_LIMIT)
      .lean();
    const contextMessages = recent
      .reverse()
      .map((m) => ({ role: m.role, content: m.content }));

    const answer = await groqChat(
      [
        { role: 'system', content: SYSTEM_PROMPT },
        ...contextMessages,
        { role: 'user', content: trimmedQuestion },
      ],
      { temperature: 0.3, maxTokens: 500 },
    );

    // Сохраняем пару «вопрос — ответ» в историю
    try {
      await AiMessage.insertMany([
        { user: req.user.id, role: 'user', content: trimmedQuestion },
        { user: req.user.id, role: 'assistant', content: answer },
      ]);
    } catch (saveError) {
      console.error('AI history save failed:', saveError.message);
    }

    return res.json({ answer });
  } catch (error) {
    console.error('AI consult failed:', error.message);
    return res.status(502).json({ message: 'ИИ временно недоступен. Попробуйте позже.' });
  }
});

module.exports = router;
