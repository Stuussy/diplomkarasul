/* eslint-disable no-console */
const express = require('express');
const auth = require('../middleware/auth');
const { groqChat, hasGroqKey } = require('../services/groq');

const router = express.Router();

const SYSTEM_PROMPT = `Ты — стоматологический ИИ-ассистент клиники Dental AI.
Правила: отвечай ТОЛЬКО по теме стоматологии и здоровья зубов/дёсен. На посторонние темы вежливо откажи.
НЕ ставь диагнозы. При серьёзных симптомах рекомендуй обратиться к врачу.
Отвечай на русском, кратко (до 150 слов), без лишних вступлений.`;

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
    const answer = await groqChat(
      [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: trimmedQuestion },
      ],
      { temperature: 0.3, maxTokens: 500 },
    );
    return res.json({ answer });
  } catch (error) {
    console.error('AI consult failed:', error.message);
    return res.status(502).json({ message: 'ИИ временно недоступен. Попробуйте позже.' });
  }
});

module.exports = router;
