/* eslint-disable no-console */
const https = require('https');

// Общий клиент Groq API (бесплатный, OpenAI-совместимый, работает глобально).
// Используется и для ИИ-консультаций пациентов, и для генерации планов лечения.
const GROQ_KEY = process.env.GROQ_API_KEY;
const GROQ_MODELS = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];

function hasGroqKey() {
  return Boolean(GROQ_KEY);
}

/**
 * Один запрос к Groq для конкретной модели.
 * @param {Array<{role:string, content:string}>} messages
 * @param {{ temperature?: number, maxTokens?: number, jsonMode?: boolean }} opts
 */
function groqRequest(messages, model, opts = {}) {
  const { temperature = 0.3, maxTokens = 800, jsonMode = false } = opts;
  return new Promise((resolve, reject) => {
    const body = {
      model,
      messages,
      temperature,
      max_tokens: maxTokens,
    };
    if (jsonMode) {
      body.response_format = { type: 'json_object' };
    }
    const payload = JSON.stringify(body);

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
    req.setTimeout(25000, () => {
      req.destroy(new Error('Таймаут запроса к ИИ.'));
    });
    req.write(payload);
    req.end();
  });
}

/**
 * Запрос к Groq с автоматическим перебором моделей (fallback).
 * Возвращает текстовый ответ ассистента.
 */
async function groqChat(messages, opts = {}) {
  if (!hasGroqKey()) {
    throw new Error('GROQ_API_KEY не задан.');
  }
  let lastError = null;
  for (const model of GROQ_MODELS) {
    try {
      return await groqRequest(messages, model, opts);
    } catch (error) {
      lastError = error;
      console.error(`Groq ${model} failed:`, error.message);
    }
  }
  throw lastError || new Error('Все модели Groq недоступны.');
}

/**
 * Извлекает JSON из ответа модели, даже если он завёрнут в ```json ... ```.
 */
function parseJsonFromText(text) {
  if (!text) throw new Error('Пустой ответ ИИ.');
  let cleaned = text.trim();
  // Срезаем markdown-ограждения, если модель их добавила
  const fenceMatch = cleaned.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenceMatch) {
    cleaned = fenceMatch[1].trim();
  }
  // На случай лишнего текста до/после — берём первый { ... последний }
  const first = cleaned.indexOf('{');
  const last = cleaned.lastIndexOf('}');
  if (first !== -1 && last !== -1 && last > first) {
    cleaned = cleaned.slice(first, last + 1);
  }
  return JSON.parse(cleaned);
}

module.exports = { groqChat, parseJsonFromText, hasGroqKey, GROQ_MODELS };
