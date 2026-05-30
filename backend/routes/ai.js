/* eslint-disable no-console */
const express = require('express');
const https = require('https');
const auth = require('../middleware/auth');

const router = express.Router();

const GEMINI_KEY = process.env.GEMINI_API_KEY;
const GEMINI_MODELS = ['gemini-2.0-flash', 'gemini-2.0-flash-lite', 'gemini-1.5-flash'];

const SYSTEM_PROMPT = `Ты — стоматологический ИИ-ассистент клиники Dental AI.
Правила: отвечай ТОЛЬКО по теме стоматологии и здоровья зубов/дёсен. На посторонние темы вежливо откажи.
НЕ ставь диагнозы. При серьёзных симптомах рекомендуй обратиться к врачу.
Отвечай на русском, кратко (до 150 слов), без лишних вступлений.`;

function geminiRequest(question, model) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [{ role: 'user', parts: [{ text: question }] }],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 500,
      },
    });

    const options = {
      hostname: 'generativelanguage.googleapis.com',
      path: `/v1beta/models/${model}:generateContent?key=${GEMINI_KEY}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
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
            console.error(`Gemini [${model}] API error (HTTP ${res.statusCode}):`, JSON.stringify(parsed.error));
            return reject(new Error(parsed.error.message || 'Gemini API error'));
          }
          const text = parsed?.candidates?.[0]?.content?.parts?.[0]?.text;
          if (text) return resolve(text);
          console.error(`Gemini [${model}] unexpected response (HTTP ${res.statusCode}):`, data.substring(0, 800));
          reject(new Error('Не удалось получить ответ от ИИ.'));
        } catch (e) {
          console.error('Gemini parse error, raw body:', data.substring(0, 300));
          reject(new Error('Ошибка разбора ответа ИИ.'));
        }
      });
    });

    req.on('error', (e) => {
      console.error('Gemini network error:', e.message);
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
  if (!GEMINI_KEY) {
    return res.status(503).json({ message: 'AI-консультация временно недоступна.' });
  }

  // Trim question to avoid huge input tokens
  const trimmedQuestion = String(question).trim().slice(0, 500);

  let lastError = null;
  for (const model of GEMINI_MODELS) {
    try {
      const answer = await geminiRequest(trimmedQuestion, model);
      return res.json({ answer, model });
    } catch (error) {
      lastError = error;
      console.error(`Gemini ${model} failed:`, error.message);
    }
  }
  console.error('All Gemini models failed. Last error:', lastError?.message);
  res.status(502).json({ message: 'ИИ временно недоступен. Попробуйте позже.' });
});

module.exports = router;
