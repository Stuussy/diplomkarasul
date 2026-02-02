# Rasul Dent App MVP

Ассистент стоматологической клиники: записи, врачи, медкарты, поддержка, штрафы, QR‑подтверждение и дашборды по ролям.

---

## 📋 Быстрый старт

### Требования
- Flutter stable
- Node.js 18+
- MongoDB 6+

### Запуск бэкенда (local)
```bash
cd backend
npm install
cp .env.example .env
npm run dev
```
API: `http://localhost:8050/api`

### Запуск Flutter
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8050/api
```

---

## 🧠 Архитектура и логика

### Мобильное приложение
- **Framework**: Flutter
- **State**: Provider
- **Networking**: `http` + JWT
- **Local storage**: SharedPreferences для токена
- **QR**: mobile_scanner
- **Notifications**: flutter_local_notifications

### Бэкенд
- **Runtime**: Node.js
- **Framework**: Express
- **API**: REST `/api/*`
- **Auth**: JWT (7 дней)
- **DB**: MongoDB (Mongoose)
- **Uploads**: Cloudinary (файлы медкарт и поддержки)
- **Docs**: Swagger UI `/api/docs`

---

## 🧩 Возможности

- Авторизация и роли (patient/doctor/admin/director)
- Список врачей + профили + отзывы
- Запись, подтверждение и отмена визитов
- Подтверждение визита по QR
- Управление расписанием (слоты)
- Медицинские карты (создание/редактирование)
- Поддержка (диалоги)
- Штрафы за позднюю отмену
- Дашборды по ролям и метрики

---

## 🔌 Основные эндпоинты

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/appointments`
- `GET /api/appointments`
- `POST /api/appointments/:id/confirm`
- `POST /api/appointments/qr-confirm`
- `POST /api/appointments/:id/cancel`
- `POST /api/appointments/slots`
- `GET /api/appointments/slots`
- `GET /api/clinics`
- `GET /api/users/doctors`
- `POST /api/records`
- `GET /api/records/mine`
- `GET /api/support`
- `POST /api/support`
- `POST /api/reviews`

---

## 🧪 Мониторинг / Health

- Swagger UI: `GET /api/docs`
- Health check: `GET /api/health`

---

## ⚙️ Переменные окружения (Backend)

См. `backend/.env.example`:
- `PORT=8050`
- `MONGO_URI`
- `JWT_SECRET`
- `GOOGLE_PLACES_API_KEY`
- `GEMINI_API_KEY`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

---

## 📦 Структура проекта

```
backend/
  config/
  middleware/
  models/
  routes/
  server.js
lib/
  models/
  providers/
  screens/
  services/
  widgets/
```
