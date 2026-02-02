# Rasul Dent App MVP

[![Flutter](https://img.shields.io/badge/Flutter-Stable-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Express](https://img.shields.io/badge/Express-4-000000?logo=express&logoColor=white)](https://expressjs.com/)
[![MongoDB](https://img.shields.io/badge/MongoDB-6+-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com/)

Dental clinic assistant: appointments, doctors, medical records, support, fines, QR confirmation, and role dashboards.

---

## 🌐 Translations

| 🇺🇸 English | 🇷🇺 [Русский](readmeRu.md) | 🇰🇿 [қазақша](readmeKz.md) |
|:---:|:---:|:---:|

---

## 📋 Quick Start

### Prerequisites
- Flutter stable
- Node.js 18+
- MongoDB 6+

### Run Backend (local)
```bash
cd backend
npm install
cp .env.example .env
npm run dev
```
API: `http://localhost:8050/api`

### Run Flutter
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8050/api
```

---

## 🧠 Core Architecture & Logic

### Mobile App
- **Framework**: Flutter
- **State**: Provider
- **Networking**: `http` + JWT
- **Local storage**: SharedPreferences for token
- **QR**: mobile_scanner
- **Notifications**: flutter_local_notifications

### Backend
- **Runtime**: Node.js
- **Framework**: Express
- **API**: REST `/api/*`
- **Auth**: JWT (7d)
- **DB**: MongoDB (Mongoose)
- **Uploads**: Cloudinary (medical records + support attachments)
- **Docs**: Swagger UI at `/api/docs`

---

## 🧩 Features

- Authentication & role-based access (patient/doctor/admin/director)
- Doctor list + profiles + reviews
- Appointment booking, confirmation, cancellation
- QR confirmation for visits
- Doctor/admin scheduling (slots)
- Medical records (create/edit for doctors/admins)
- Support tickets (chat-like history)
- Fines for late cancellations
- Role dashboards with metrics

---

## 🔌 API Surface (key)

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

Required variables (see `backend/.env.example`):
- `PORT=8050`
- `MONGO_URI`
- `JWT_SECRET`
- `BOOTSTRAP_SECRET` (для `/auth/bootstrap-director`)
- `GOOGLE_PLACES_API_KEY`
- `GEMINI_API_KEY`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`
- `QR_SECRET` (подпись QR)
- `CORS_ORIGINS` (comma-separated)

---

## 📦 Project Layout

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
