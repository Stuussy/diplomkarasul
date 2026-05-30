/* eslint-disable no-console */
const express = require('express');
const https = require('https');
const auth = require('../middleware/auth');

const router = express.Router();

// Groq API (бесплатный, OpenAI-совместимый, работает глобально)
const GROQ_KEY = process.env.GROQ_API_KEY;
const GROQ_MODELS = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];

const SYSTEM_PROMPT = `Ты — стоматологический ИИ-ассистент клиники Dental AI.
Правила: отвечай ТОЛЬКО по теме стоматологии и здоровья зубов/дёсен. На посторонние темы вежливо откажи.
НЕ ставь диагнозы. При серьёзных симптомах рекомендуй обратиться к врачу.
Отвечай на русском, кратко (до 150 слов), без лишних вступлений.`;

function groqRequest(question, model) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      model,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: question },
      ],
      temperature: 0.3,
      max_tokens: 500,
    });

    const options = {
      hostname: 'api.groq.com',
      path: '/openai/v1/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${GROQ_KEY}`,
        'Content-Length': Buffer.byteLength(payload),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.error) {
            console.error(`Groq [${model}] API error (HTTP ${res.statusCode}):`, JSON.stringify(parsed.error));
            return reject(new Error(parsed.error.message || 'Groq API error'));
          }
          const text = parsed?.choices?.[0]?.message?.content;
          if (text) return resolve(text.trim());
          console.error(`Groq [${model}] unexpected response (HTTP ${res.statusCode}):`, data.substring(0, 800));
          reject(new Error('Не удалось получить ответ от ИИ.'));
        } catch (e) {
          console.error(`Groq [${model}] parse error, raw body:`, data.substring(0, 300));
          reject(new Error('Ошибка разбора ответа ИИ.'));
        }
      });
    });

    req.on('error', (e) => {
      console.error('Groq network error:', e.message);
      reject(e);
    });
    req.setTimeout(20000, () => {
      req.destroy(new Error('Таймаут запроса к ИИ.'));
    });
    req.write(payload);
    req.end();
  });
}

// POST /api/ai/consult
router.post('/consult', auth(), async (req, res) => {
  const { question } = req.body;
  if (!question || String(question).trim().length < 3) {
    return res.status(400).json({ message: 'Введите вопрос.' });
  }
  if (!GROQ_KEY) {
    return res.status(503).json({ message: 'AI-консультация временно недоступна.' });
  }

  // Trim question to avoid huge input tokens
  const trimmedQuestion = String(question).trim().slice(0, 500);

  let lastError = null;
  for (const model of GROQ_MODELS) {
    try {
      const answer = await groqRequest(trimmedQuestion, model);
      return res.json({ answer, model });
    } catch (error) {
      lastError = error;
      console.error(`Groq ${model} failed:`, error.message);
    }
  }
  console.error('All Groq models failed. Last error:', lastError?.message);
  res.status(502).json({ message: 'ИИ временно недоступен. Попробуйте позже.' });
});

module.exports = router;
