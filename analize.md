# 📊 Project Audit Report

## 1. Общая оценка

### Executive summary

Проект уже содержит реальный домен и широкий набор функций для дипломного MVP:

- аутентификация и роли;
- клиники и врачи;
- запись на приём, перенос, отмена, QR-подтверждение;
- медкарты;
- поддержка;
- отзывы;
- уведомления;
- внешние интеграции.

С точки зрения продуктовой идеи это уже не “пустой шаблон”, а почти полноценный вертикальный срез продукта. С точки зрения инженерной готовности проект пока находится в фазе стабилизации, а не в фазе релиза.

Главный вывод аудита:

- backend по функциональности ближе к MVP, чем frontend;
- frontend сейчас является главным источником риска;
- текущий checkout не воспроизводим как надёжная demo/release-ветка;
- до production-подобного уровня проекту ещё далеко.

### Что было проверено

- структура репозитория и текущее состояние `git status`
- `flutter analyze`
- `npm --prefix backend test`
- ключевые backend-файлы:
  - `backend/server.js`
  - `backend/routes/*.js`
  - `backend/models/*.js`
  - `backend/middleware/*.js`
  - `backend/services/google_calendar.js`
  - `backend/utils/*.js`
- ключевые frontend-файлы:
  - `lib/main.dart`
  - `lib/navigation_container.dart`
  - `lib/providers/session_provider.dart`
  - `lib/services/api_service.dart`
  - `lib/screens/*.dart`
  - `lib/widgets/*.dart`
  - `lib/theme/clinic_theme.dart`
- конфигурация:
  - `README.md`
  - `backend/.env.example`
  - `pubspec.yaml`
  - `package.json`
  - `backend/package.json`

### Допущения аудита

- MVP для защиты диплома трактуется как демонстрируемый end-to-end сценарий с backend, авторизацией, хотя бы одним пациентским happy path и базовыми административными функциями.
- Оценка готовности дана по текущему состоянию checkout на 2026-04-04, а не по “задуманной” архитектуре.
- Если для защиты обязателен Android APK, текущая готовность ниже, чем указано в процентах, потому что Android-платформа сейчас отсутствует в рабочем дереве.

### Сильные стороны проекта

- Хороший функциональный охват для дипломного проекта.
- Чёткое разделение на mobile client и backend.
- Есть RBAC, JWT, Cloudinary uploads, Google Calendar OAuth, Google Places, Gemini, support flow.
- Есть health route и Swagger wiring.
- UI-концепция уже выше среднего для MVP: единая тема, карточки, role dashboards, нормальный визуальный язык.
- Backend уже начал получать тесты на критичные RBAC-сценарии.

## 2. Архитектура

### 2.1 Структура проекта

Фактическая структура сейчас выглядит так:

- `backend/` — Express + Mongoose
- `lib/` — Flutter client
- `ios/` и `web/` — платформенные каталоги
- корневой `package.json` — repo-level scripts

Сильная сторона структуры:

- разбиение на backend/frontend интуитивно понятное;
- модель/роут/сервис/утилиты в backend отделены;
- во Flutter есть выделенные `models`, `providers`, `services`, `screens`, `widgets`, `theme`.

Проблема структуры:

- проект выглядит как монолит без дополнительных слоёв orchestration/domain policy;
- часть критической логики размазана между роутами, сервисами и UI;
- очень крупные файлы усложняют поддержку.

### 2.2 Backend архитектура

Текущий backend:

- стек: Node.js + Express + Mongoose;
- входная точка: `backend/server.js`;
- маршруты монтируются через `backend/routes/api.js`;
- авторизация: JWT через `backend/middleware/auth.js`;
- загрузки: `multer` + Cloudinary;
- интеграции: Google Calendar, Google Places, Gemini.

Что хорошо:

- базовый security baseline есть: `helmet`, `rate-limit`, auth middleware;
- RBAC уже реализован и в чувствительных местах начал усиливаться;
- маршруты в целом разделены по доменам;
- Google Calendar integration обёрнут в отдельный service;
- upload middleware уже умеет возвращать понятные ошибки API.

Что плохо:

- `backend/server.js` одновременно создаёт app, подключает MongoDB и делает `listen()`, из-за чего неудобно писать integration tests;
- нет централизованного error middleware;
- нет единого слоя policy/service для RBAC и clinic-scope;
- значимая бизнес-логика сидит прямо в routes;
- response contracts для ошибок несогласованы:
  - где-то `{ message }`
  - где-то `{ error }`
  - где-то `{ errors: [] }`

### 2.3 Frontend архитектура

Текущий frontend:

- стек: Flutter + Provider + `http`;
- session/state: `SessionProvider`;
- API access: монолитный `ApiService` на 785 строк;
- навигация:
  - patient через tab shell
  - staff через role dashboards

Что хорошо:

- визуальная система уже собрана;
- permission flow для камеры и notification перенесён ближе к точке использования;
- экраны покрывают основные роли и сценарии;
- данные моделируются отдельными frontend model classes.

Что плохо:

- frontend сейчас не проходит `flutter analyze`;
- `ApiService`, `SessionProvider` и экраны рассинхронизированы;
- критичные сценарии пациента ломаются из-за несовместимых сигнатур;
- файлы слишком крупные:
  - `lib/screens/role_dashboards.dart` — 2048 строк
  - `lib/services/api_service.dart` — 785 строк
  - `lib/screens/home_screen.dart` — 574 строки
  - `lib/screens/medical_records_screen.dart` — 533 строки

### 2.4 Инфраструктура и delivery

На уровне поддержки проекта сейчас есть:

- README
- `.env.example`
- корневые npm scripts для backend
- базовый backend test harness

На уровне release engineering не хватает:

- CI
- deployment config
- Docker / compose
- preflight env validation
- release checklist
- smoke pipeline

Отдельный сигнал риска:

- в рабочем дереве физически присутствуют только `ios` и `web`
- `android`, `linux`, `macos`, `windows` в текущем checkout удалены

Если целевая защита требует Android APK, это уже архитектурно-процессный блокер, а не просто “грязный git status”.

### 2.5 API и контрактность

Плюсы API:

- REST surface уже широкий;
- роль доступа во многих маршрутах описана достаточно явно;
- доменные маршруты читаемы.

Минусы API:

- нет версионирования;
- Swagger фактически не покрывает API:
  - `swagger.js` подключён
  - аннотация `@openapi` найдена только у health route
- нет единого стандарта ошибок и response envelopes;
- нет пагинации почти нигде;
- тяжёлые списочные маршруты возвращают данные целиком.

### 2.6 Интеграции

Интеграции, которые есть:

- Google Places
- Gemini
- Google Calendar OAuth
- SMTP
- Cloudinary
- 2GIS / deeplink во frontend

Что хорошо:

- интеграции реально встроены в продуктовые сценарии;
- `.env.example` описывает нужные переменные.

Что плохо:

- Map screen использует жёстко зашитый 2GIS URL/deeplink, а не реальные данные клиники;
- Google Calendar вызовы выполняются прямо в booking/reschedule/cancel flow, то есть внешний сервис влияет на латентность и устойчивость пользовательского запроса;
- Gemini и Places вынесены в backend, но при ошибках частично возвращают fallback, частично 500, поведение не до конца унифицировано;
- нет механизма graceful degradation на уровне продукта, кроме локальных fallback-веток.

### 2.7 Безопасность

Что уже хорошо:

- JWT подписывается и не содержит лишнего clinic-scope;
- `.env` и `backend/.env` не находятся в tracked files;
- есть auth middleware и role gating;
- для auth есть отдельный rate limiter;
- upload pipeline уже ограничивает MIME, размер и count.

Основные риски:

- `bootstrap-director` опасен для production, если оставить включённым;
- Google OAuth tokens сохраняются в базе в открытом виде в `User.google`;
- нет централизованной валидации обязательных env на старте;
- Gemini/Places endpoints не защищены auth;
- нет audit trail для чувствительных действий;
- policy logic по доступам дублируется по маршрутам, а не централизована;
- поддержка error cases и security cases держится на route-level if/else, что плохо масштабируется.

### 2.8 Производительность

Главные наблюдения:

- пагинации почти нет;
- списки часто строятся через `find()` без лимитов;
- активно используется `populate()` на маршрутах, которые потенциально будут расти;
- индексов почти нет.

Фактически найденные индексы:

- `Clinic.location` — `2dsphere`
- `ScheduleSlot.doctor + startTime` — unique

Не хватает индексов для горячих сценариев:

- appointments по `patient`, `doctor`, `clinic`, `startTime`, `status`
- notifications по `user`, `isRead`, `createdAt`
- messages по `patient`, `status`, `lastMessageAt`
- reviews по `doctor`
- fines по `patient`

### 2.9 Масштабируемость

На уровень дипломного MVP текущая архитектура ещё терпима. На уровень production-масштабирования — нет.

Главные ограничения масштабируемости:

- монолитный `ApiService` во frontend;
- монолитные route files в backend;
- дублирование clinic-scope helper в нескольких маршрутах;
- слабая тестируемость backend entrypoint;
- внешние интеграции в синхронном request path;
- отсутствие CI и контрактных тестов.

### 2.10 UX/UI

С точки зрения визуала:

- UI выглядит заметно лучше базового CRUD MVP;
- theme и reusable widgets уже есть;
- patient shell, dashboards, cards, badges, gradients — это сильная сторона для защиты диплома.

С точки зрения UX-реальности:

- пользовательские потоки не надёжны, потому что client contract broken;
- карта клиники сейчас не data-driven;
- role dashboards функционально насыщены, но перегружены по реализации;
- часть ошибок для пользователя сейчас просто “не доходит” корректно.

Отдельный пример:

- `SessionProvider.login()` и `register()` возвращают `String?` с текстом ошибки
- `LoginScreen` ждёт, что ошибки будут выброшены через `throw`

Итог:

- даже при красивом UI пользователь может не получить корректной обратной связи в auth flow.

## 3. Проблемы и блокеры

### 🔴 Critical — блокирует MVP

#### C1. Flutter client не проходит статическую проверку и фактически не готов к сборке

Факт:

- `flutter analyze` завершился с `34 issues found`

Ключевые ошибки:

- экраны вызывают отсутствующие методы `ApiService`
- используются несовместимые сигнатуры методов
- используются отсутствующие `LucideIcons`
- используются отсутствующие theme fields

Это блокирует достижение MVP, потому что демонстрационный клиент нельзя считать стабильным.

#### C2. Сломан контракт между UI и API service в ключевых пациентских сценариях

Конкретные примеры:

- `fetchMyAppointments` вызывается, но в `ApiService` отсутствует
- `bookAppointment` вызывается, но в `ApiService` есть `bookSlot`
- `fetchMyFines` вызывается, но есть только `fetchFines`
- `confirmAppointmentByQr` вызывается с именованными параметрами, а объявлен как `confirmAppointmentByQr(String payload)`
- `changePassword` вызывается с `oldPassword`, а метод ждёт `currentPassword`

Это ломает:

- просмотр своих записей
- бронирование
- подтверждение по QR
- профиль и штрафы
- смену пароля

#### C3. Auth flow сломан на уровне frontend contract

Проблема:

- `SessionProvider.login()` и `register()` возвращают строку ошибки
- `LoginScreen` использует `try/catch` и игнорирует возвращаемое значение
- в `register()` ещё и сломан вызов именованных параметров

Результат:

- регистрация сейчас не компилируется;
- ошибки логина могут теряться без корректного сообщения пользователю.

#### C4. Целевая мобильная платформа не определена, а Android checkout отсутствует

Факт:

- в текущем рабочем дереве есть только `ios` и `web`
- каталоги `android`, `linux`, `macos`, `windows` физически отсутствуют

Если защита диплома должна идти с Android APK, текущий проект не готов даже организационно.

#### C5. Текущий checkout не является demo-safe веткой

Факт:

- `git status` содержит тысячи dirty entries
- в истории/индексе были закоммичены `backend/node_modules`
- одновременно присутствуют продуктовые правки, инфраструктурная чистка и platform deletions

Это критично не для кода как такового, а для управляемости релизной сборки и защиты проекта.

### 🟡 Medium — мешает релизу

#### M1. Тестовое покрытие минимальное и не покрывает продуктовые happy paths

Факты:

- Flutter tests: `0`
- backend tests: `2 файла / 4 сценария`

Покрытия нет для:

- auth happy path
- booking / confirm / cancel / reschedule
- support flow
- reviews flow
- medical records flow
- role dashboards

#### M2. Backend tests в текущей среде не запускаются “как есть”

Факт:

- `npm --prefix backend test` в текущем состоянии падает на `Cannot find module 'express'`

Причина:

- зависимости backend не установлены;
- `backend/node_modules` был исторически tracked и сейчас удалён из working tree.

Это не обязательно ломает сам проект после `npm install`, но показывает слабую воспроизводимость среды.

#### M3. Swagger практически пустой

Факт:

- Swagger wiring есть
- `@openapi` аннотация найдена только у `health` route

Для поддержки и защиты это означает, что API “документирован концептуально”, но не реально.

#### M4. Слабая performance/scaling база

Факты:

- почти нет пагинации;
- почти нет индексов;
- есть тяжёлые `find()` + `populate()` без лимитов;
- route handlers делают много последовательной бизнес-логики прямо в запросе.

На MVP это допустимо. На release-подобный режим — уже заметный риск.

#### M5. Дублирование RBAC и clinic-scope логики

Функция `getAdminClinicIds` дублируется как минимум в:

- `appointments.js`
- `clinics.js`
- `fines.js`
- `records.js`
- `stats.js`
- `users.js`

Это означает высокий риск новых access bugs при дальнейших изменениях.

#### M6. Map flow не завершён как продуктовая функция

Факт:

- `MapScreen` использует жёстко зашитый 2GIS deeplink/url
- маршрут не строится от реальных клиник проекта

Итог:

- экран выглядит убедительно визуально;
- как продуктовая функция он пока демонстрационный, а не настоящий.

#### M7. Интеграции не изолированы от пользовательских запросов

Конкретно:

- Google Calendar insert/patch/delete идут прямо в booking/reschedule/cancel flow

Риск:

- внешний сервис напрямую влияет на latency и отказоустойчивость критичных операций.

#### M8. Нет release engineering и CI

Факт:

- отсутствует `.github/workflows`
- нет smoke pipeline
- нет deploy config
- нет release checklist

Для production readiness это серьёзный минус.

### 🟢 Minor — можно отложить

#### N1. Крупные файлы усложняют ревью и поддержку

Наиболее проблемные:

- `lib/screens/role_dashboards.dart`
- `lib/services/api_service.dart`
- `backend/routes/appointments.js`
- `backend/routes/profile.js`

Это не обязательно мешает MVP сегодня, но увеличивает вероятность регрессий завтра.

#### N2. Lint hygiene и визуальные недочёты

Примеры:

- unused imports
- deprecated member use
- лишние касты
- несогласованные icon refs

Это не корневая проблема, но усиливает ощущение нестабильности ветки.

#### N3. README и фактическое состояние проекта немного расходятся

README описывает проект как более целостный, чем он сейчас есть в рабочем состоянии. Для диплома лучше, чтобы документация соответствовала реальной demo-ветке.

## 4. Оценка готовности

### Готовность MVP: 45%

#### Почему не ниже

- доменная логика уже богата;
- backend реализует значительную часть нужных сценариев;
- UI и role dashboards уже существуют;
- есть реальные продуктовые интеграции;
- patient/admin/doctor/support контуры уже намечены.

#### Почему не выше

- клиент не проходит `flutter analyze`;
- ключевые frontend flows сломаны контрактно;
- auth flow сейчас ненадёжен;
- demo-ветка грязная;
- target platform не до конца определена.

#### Корректировка по платформе

Если на защите обязателен Android APK, реальная MVP-ready оценка ближе к `35%`, пока Android scaffold не восстановлен или не выбран другой целевой формат демонстрации.

### Готовность Production: 18%

#### Аргументация

До production уровня сейчас не хватает почти всех operational и reliability слоёв:

- CI
- тестового покрытия
- стабильной сборки frontend
- release process
- env validation
- observability
- нормального API documentation coverage
- hardening интеграций и секретов
- performance readiness
- безопасной reproducible delivery ветки

С точки зрения production это пока исследовательский / учебный продукт с сильным доменом, но без release discipline.

## 5. MVP Gap

Ниже только то, без чего MVP для защиты не стоит считать готовым.

### Обязательный минимум до MVP

- починить все blocking compile/analyze ошибки во Flutter;
- синхронизировать `ApiService`, `SessionProvider` и экраны;
- восстановить пациентский happy path:
  - логин / регистрация
  - список врачей
  - запись на приём
  - просмотр своих записей
  - QR-подтверждение
  - профиль / штрафы / медкарта
- проверить и довести admin happy path:
  - просмотр overview/stats
  - создание врача
  - слоты
  - генерация QR для клиники
- зафиксировать целевую demo-платформу:
  - либо вернуть Android
  - либо официально демонстрировать iOS/web
- очистить demo-ветку от инфраструктурного шума и platform deletions;
- сделать минимальный reproducible runbook:
  - backend install
  - env setup
  - seed/demo data
  - frontend run

### Что не обязательно для MVP

- полное покрытие Swagger
- глубокий рефакторинг backend routes
- вынос всех монолитных файлов
- полноценная production-observability
- микросервисное разделение

## 6. Риски

### Продуктовые риски

- на защите может оказаться, что визуально богатый экран не проходит реальный сценарий из-за поломанного контракта;
- карта клиники выглядит как feature, но по сути частично статична;
- role dashboards могут создать ожидание полноценных админских сценариев, которые не все стабилизированы end-to-end.

### Технические риски

- новые правки в RBAC легко породят новые access bugs из-за дублирования policy logic;
- любые изменения в `ApiService` без проверки экранов снова сломают клиент;
- текущие большие файлы повышают риск случайных регрессий.

### Release риски

- demo/build ветка сейчас не чистая;
- нет CI и smoke gates;
- отсутствует надёжный “one command bootstrap” для проекта.

### Security риски

- plaintext-like хранение Google tokens в базе;
- опасный bootstrap route, если его не отключать вне initial setup;
- открытые integration endpoints;
- нет полноценного audit trail.

### Операционные риски

- внешние интеграции в синхронном request path;
- отсутствуют фоновые job queues;
- нет централизованной проверки конфигурации при старте приложения.

### Главный вывод по рискам

Проект реалистично доводим до сильного дипломного MVP за короткий цикл, потому что функциональный фундамент уже есть. Но без быстрой стабилизации frontend и приведения checkout к demo-safe состоянию защита будет зависеть от удачи, а не от качества системы.
