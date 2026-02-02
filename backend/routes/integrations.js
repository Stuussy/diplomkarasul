const express = require('express');

const router = express.Router();

let fetch;
import('node-fetch').then((mod) => {
  fetch = mod.default;
});

router.get('/places/dental-clinics', async (req, res) => {
  const { lat, lon, radius, type, max } = req.query;
  const GOOGLE_PLACES_API_KEY = process.env.GOOGLE_PLACES_API_KEY;

  if (!lat || !lon) {
    return res.status(400).json({ error: 'Необходимо указать широту и долготу.' });
  }
  if (!fetch) {
    return res.status(500).json({ error: 'Сервис карт временно недоступен.' });
  }
  if (!GOOGLE_PLACES_API_KEY) {
    return res.status(500).json({ error: 'Ключ Google Places не настроен.' });
  }

  const url = 'https://places.googleapis.com/v1/places:searchNearby';
  const requestedRadius = Number(radius) || 5000;
  const safeRadius = Math.min(Math.max(requestedRadius, 100), 50000);
  const requestedMax = parseInt(max ?? '10', 10);
  const safeMax = Math.min(Math.max(requestedMax, 1), 20);
  const requestedType = type && String(type).trim().length > 0 ? type : 'dental_clinic';

  const payload = {
    includedPrimaryTypes: [requestedType],
    maxResultCount: safeMax,
    rankPreference: 'POPULARITY',
    locationRestriction: {
      circle: {
        center: {
          latitude: parseFloat(lat),
          longitude: parseFloat(lon),
        },
        radius: safeRadius,
      },
    },
  };

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': GOOGLE_PLACES_API_KEY,
        'X-Goog-FieldMask':
          'places.displayName,places.formattedAddress,places.location,places.googleMapsUri',
      },
      body: JSON.stringify(payload),
    });
    if (!response.ok) {
      const errorData = await response.json();
      console.error('Ошибка Google Places:', errorData);
      return res.status(response.status).json({ error: 'Не удалось получить список клиник.' });
    }
    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Ошибка Google Places:', error);
    res.status(500).json({ error: 'Не удалось получить список клиник.' });
  }
});

router.post('/gemini/ask', async (req, res) => {
  const { prompt } = req.body;
  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  const fallback =
    'Не удалось обратиться к ИИ, но мы напоминаем: чистите зубы утром и вечером, и не забывайте про нить.';

  if (!prompt) {
    return res.status(400).json({ error: 'Необходимо передать prompt.' });
  }
  if (!fetch) {
    return res.status(200).json({ response: fallback });
  }
  if (!GEMINI_API_KEY) {
    return res.status(200).json({ response: fallback });
  }

  const url =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  const payload = {
    contents: [
      {
        parts: [{ text: prompt }],
      },
    ],
  };

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-goog-api-key': GEMINI_API_KEY,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error('Ошибка Gemini:', errorData);
      return res
        .status(200)
        .json({ response: fallback, warning: errorData.error?.message ?? 'Gemini недоступен.' });
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
    res.json({ response: text || fallback });
  } catch (error) {
    console.error('Ошибка запроса к Gemini:', error);
    res.status(200).json({ response: fallback });
  }
});

module.exports = router;
