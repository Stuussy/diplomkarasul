# Rasul Dent App MVP

Стоматологиялық клиникаға арналған ассистент: қабылдаулар, дәрігерлер, медкарталар, қолдау, айыппұлдар, QR‑растау және рөлдік дашбордтар.

---

## 📋 Жылдам бастау

### Қажеттілер
- Flutter stable
- Node.js 18+
- MongoDB 6+

### Backend іске қосу (local)
```bash
cd backend
npm install
cp .env.example .env
npm run dev
```
API: `http://localhost:8050/api`

### Flutter іске қосу
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8050/api
```

---

## 🧠 Архитектура және логика

### Мобильді қосымша
- **Framework**: Flutter
- **State**: Provider
- **Networking**: `http` + JWT
- **Local storage**: SharedPreferences (токен)
- **QR**: mobile_scanner
- **Notifications**: flutter_local_notifications

### Backend
- **Runtime**: Node.js
- **Framework**: Express
- **API**: REST `/api/*`
- **Auth**: JWT (7 күн)
- **DB**: MongoDB (Mongoose)
- **Uploads**: Cloudinary (медкарталар мен қолдау файлдары)
- **Docs**: Swagger UI `/api/docs`

---

## 🧩 Мүмкіндіктер

- Авторизация және рөлдер (patient/doctor/admin/director)
- Дәрігерлер тізімі + профильдер + пікірлер
- Қабылдауға жазылу, растау және болдырмау
- QR арқылы растау
- Кесте (слоттар) басқару
- Медициналық карталар (құру/өңдеу)
- Қолдау (чат тарихы)
- Кеш болдырмау үшін айыппұлдар
- Рөлдік дашбордтар мен метрикалар

---

## 🔌 Негізгі эндпоинттар

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

## 🧪 Monitoring / Health

- Swagger UI: `GET /api/docs`
- Health check: `GET /api/health`

---

## ⚙️ Environment (Backend)

`backend/.env.example` файлын қараңыз:
- `PORT=8050`
- `MONGO_URI`
- `JWT_SECRET`
- `GOOGLE_PLACES_API_KEY`
- `GEMINI_API_KEY`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

---

## 📦 Жоба құрылымы

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
