// Импортируем необходимые модули
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config(); // Загружает переменные окружения из .env
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./swagger');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

// Импортируем наши маршруты
const apiRoutes = require('./routes/api');

// Инициализируем приложение Express
const app = express();
const PORT = process.env.PORT || 8050;

app.set('trust proxy', 1);

// Middleware
app.use(helmet());
const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
const isDev = process.env.NODE_ENV === 'development';
app.use(
  cors({
    origin: (origin, callback) => {
      // Allow non-browser requests (mobile apps, curl) — no Origin header
      if (!origin) return callback(null, true);
      // Always allow any localhost / 127.0.0.1 (Flutter web uses a random port)
      if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
        return callback(null, true);
      }
      // Dev mode: allow everything
      if (isDev) return callback(null, true);
      // Production: only configured origins
      if (corsOrigins.includes(origin)) return callback(null, true);
      return callback(null, false);
    },
    credentials: true,
  }),
);
app.use(express.json()); // Позволяет парсить JSON в теле запроса

// Extract real client IP from X-Forwarded-For (Render proxy)
const getClientIp = (req) => {
  const xff = req.headers['x-forwarded-for'];
  return (xff ? xff.split(',')[0].trim() : null) || req.socket?.remoteAddress || 'unknown';
};

const rateLimitDefaults = {
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  keyGenerator: getClientIp,
};

const limiter = rateLimit({
  ...rateLimitDefaults,
  windowMs: 15 * 60 * 1000,
  max: 200,
});
app.use('/api', limiter);

const authLimiter = rateLimit({
  ...rateLimitDefaults,
  windowMs: 15 * 60 * 1000,
  max: 30,
});
app.use('/api/auth', authLimiter);

const supportLimiter = rateLimit({
  ...rateLimitDefaults,
  windowMs: 15 * 60 * 1000,
  max: 60,
});
app.use('/api/support', supportLimiter);

const appointmentsLimiter = rateLimit({
  ...rateLimitDefaults,
  windowMs: 15 * 60 * 1000,
  max: 80,
});
app.use('/api/appointments', appointmentsLimiter);

// Swagger UI
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// --- Подключение к MongoDB ---
const MONGO_URI = process.env.MONGO_URI;
mongoose.connect(MONGO_URI)
  .then(async () => {
    console.log('Успешное подключение к MongoDB');
    // Cancel all past scheduled/confirmed appointments on startup
    try {
      const Appointment = require('./models/Appointment');
      const result = await Appointment.updateMany(
        { startTime: { $lt: new Date() }, status: { $in: ['scheduled', 'confirmed'] } },
        { $set: { status: 'cancelled' } },
      );
      if (result.modifiedCount > 0) {
        console.log(`Автоотмена: ${result.modifiedCount} просроченных записей отменено`);
      }
    } catch (err) {
      console.error('Ошибка автоотмены просроченных записей:', err);
    }
  })
  .catch(err => console.error('Ошибка подключения к MongoDB:', err));

// --- Маршруты ---
// Все API-запросы будут начинаться с /api
app.use('/api', apiRoutes);

// Базовый маршрут для проверки
app.get('/', (req, res) => {
  res.send('Бэкенд для rasul_dent_app запущен!');
});

// Запускаем сервер
app.listen(PORT, () => {
  console.log(`Сервер запущен на порту ${PORT}`);
});
