// Импортируем необходимые модули
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config(); // Загружает переменные окружения из .env

// Импортируем наши маршруты
const apiRoutes = require('./routes/api');

// Инициализируем приложение Express
const app = express();
const PORT = process.env.PORT || 8050;

// Middleware
app.use(cors()); // Включаем CORS для всех запросов
app.use(express.json()); // Позволяет парсить JSON в теле запроса

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
