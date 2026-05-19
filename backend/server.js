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
    origin: isDev ? true : corsOrigins.length > 0 ? corsOrigins : false,
    credentials: true,
  }),
);
app.use(express.json()); // Позволяет парсить JSON в теле запроса

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api', limiter);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/auth', authLimiter);

const supportLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/support', supportLimiter);

const appointmentsLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 80,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/appointments', appointmentsLimiter);

// Swagger UI
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// --- Подключение к MongoDB ---
const MONGO_URI = process.env.MONGO_URI;
mongoose.connect(MONGO_URI)
  .then(() => console.log('Успешное подключение к MongoDB'))
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
