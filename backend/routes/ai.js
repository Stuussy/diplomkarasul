/* eslint-disable no-console */
const express = require('express');
const https = require('https');
const auth = require('../middleware/auth');

const router = express.Router();

const GEMINI_KEY = process.env.GEMINI_API_KEY;
const GEMINI_MODELS = ['gemini-2.0-flash', 'gemini-2.0-flash-lite', 'gemini-1.5-flash', 'gemini-2.5-flash'];

const SYSTEM_PROMPT = `Ты — стоматологический ИИ-ассистент клиники Dental AI. Твоя задача:
1. Помогать пациентам разобраться с симптомами и беспокойствами, связанными с зубами и полостью рта.
2. Давать общие рекомендации (гигиена, профилактика, первая помощь).
3. Рекомендовать обратиться к врачу при серьёзных симптомах.
4. НЕ ставить диагнозы — только помогать понять симптомы.
5. Отвечать только по теме стоматологии. На посторонние темы вежливо отказывай.
6. Отвечай на русском языке, кратко и понятно (до 300 слов).`;

function geminiRequest(prompt, model) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      contents: [
        {
          parts: [
            { text: `${SYSTEM_PROMPT}\n\nВопрос пациента: ${prompt}` },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 512,
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
            console.error('Gemini API error response:', JSON.stringify(parsed.error));
            return reject(new Error(parsed.error.message || 'Gemini API error'));
          }
          const text = parsed?.candidates?.[0]?.content?.parts?.[0]?.text;
          if (text) {
            return resolve(text);
          }
          console.error('Gemini unexpected response (status %d):', res.statusCode, data.substring(0, 500));
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
    req.setTimeout(15000, () => {
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

  let lastError = null;
  for (const model of GEMINI_MODELS) {
    try {
      const answer = await geminiRequest(String(question).trim(), model);
      return res.json({ answer, model });
    } catch (error) {
      lastError = error;
      console.error(`Gemini ${model} failed:`, error.message);
    }
  }
  console.error('All Gemini models failed. Last error:', lastError?.message);
  res.status(502).json({
    message: 'ИИ временно недоступен. Попробуйте позже.',
    detail: lastError?.message,
  });
});

module.exports = router;
