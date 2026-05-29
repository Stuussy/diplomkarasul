// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';

/// Access via: context.s.someKey  or  S.of(context).someKey
extension SContext on BuildContext {
  AppStrings get s {
    final locale = watch<LocaleProvider>().locale;
    return locale.languageCode == 'kk' ? KkStrings() : RuStrings();
  }
  // Read-only version (no listen)
  AppStrings get sRead {
    final locale = read<LocaleProvider>().locale;
    return locale.languageCode == 'kk' ? KkStrings() : RuStrings();
  }
}

abstract class AppStrings {
  // ── Navigation ──────────────────────────────────────────────────────────────
  String get navHome;
  String get navMap;
  String get navAppointments;
  String get navProfile;
  String get navAi;
  String get navSupport;
  String get navNotifications;

  // ── Common ───────────────────────────────────────────────────────────────────
  String get cancel;
  String get confirm;
  String get save;
  String get close;
  String get yes;
  String get no;
  String get ok;
  String get back;
  String get retry;
  String get loading;
  String get error;
  String get success;
  String get send;
  String get delete;
  String get edit;
  String get search;
  String get filter;
  String get refresh;
  String get apply;
  String get reset;
  String get next;
  String get done;
  String get notFound;
  String get serverError;
  String get noData;
  String get required;

  // ── Auth ─────────────────────────────────────────────────────────────────────
  String get login;
  String get logout;
  String get register;
  String get email;
  String get password;
  String get firstName;
  String get lastName;
  String get phone;
  String get forgotPassword;
  String get noAccount;
  String get haveAccount;
  String get enterEmail;
  String get enterPassword;
  String get enterFirstName;
  String get enterLastName;
  String get enterPhone;
  String get loginTitle;
  String get registerTitle;
  String get loginButton;
  String get registerButton;
  String get loginError;
  String get passwordMin;
  String get emailInvalid;
  String get logoutConfirmTitle;
  String get logoutConfirmContent;
  String get logoutButton;

  // ── Forgot password ──────────────────────────────────────────────────────────
  String get forgotTitle;
  String get forgotSubtitle;
  String get forgotSend;
  String get forgotCodeSent;
  String get forgotEnterCode;
  String get forgotNewPassword;
  String get forgotConfirmPassword;
  String get forgotSubmit;
  String get forgotPasswordMismatch;
  String get forgotCodeLabel;
  String get forgotSuccess;

  // ── Home ─────────────────────────────────────────────────────────────────────
  String get homeGreeting;
  String get homeSubtitle;
  String get homeDoctors;
  String get homeClinics;
  String get homeServices;
  String get homeSearchDoctors;
  String get homeNoDoctors;
  String get homeNoClinics;
  String get homeExperience;
  String get homeYears;
  String get homeBook;
  String get homeDetails;
  String get homeSpecialties;
  String get homeAllDoctors;
  String get homeAllClinics;
  String get homeSectionBestDoctors;
  String get homeSectionSubtitle;
  String get homeNextVisitLabel;
  String get homeNoAppointmentTitle;
  String get homeNoAppointmentSubtitle;

  // ── Map ──────────────────────────────────────────────────────────────────────
  String get mapTitle;
  String get mapNoClinics;
  String get mapOpenRoute;
  String get mapTaxi;
  String get mapWorkingHours;
  String get mapClosed;
  String get mapOpen;
  String get mapContacts;
  String get mapDoctors;
  String get mapServices;
  String get mapBook;
  String get mapAddress;
  String get mapNoDoctorsMessage;

  // ── Appointments ──────────────────────────────────────────────────────────────
  String get appointmentsTitle;
  String get appointmentsEmpty;
  String get appointmentsScheduled;
  String get appointmentsConfirmed;
  String get appointmentsCompleted;
  String get appointmentsCancelled;
  String get appointmentsCancel;
  String get appointmentsCancelTitle;
  String get appointmentsCancelContent;
  String get appointmentsCancelDone;
  String get appointmentsConfirmQr;
  String get appointmentsReview;
  String get appointmentsLeaveReview;
  String get appointmentsDoctor;
  String get appointmentsClinic;
  String get appointmentsDate;
  String get appointmentsTime;
  String get appointmentsService;
  String get appointmentsStatus;
  String get appointmentsQrSuccess;
  String get appointmentsNoSlots;
  String get appointmentsUpcoming;
  String get appointmentsPast;

  // ── Booking ───────────────────────────────────────────────────────────────────
  String get bookTitle;
  String get bookDoctor;
  String get bookService;
  String get bookDate;
  String get bookSlot;
  String get bookComment;
  String get bookSubmit;
  String get bookSuccess;
  String get bookSelectService;
  String get bookSelectDate;
  String get bookSelectSlot;
  String get bookNoSlots;
  String get bookCommentHint;
  String get bookConfirmTitle;
  String get bookConfirmContent;

  // ── Profile ───────────────────────────────────────────────────────────────────
  String get profileTitle;
  String get profileEdit;
  String get profileMedicalRecords;
  String get profileFines;
  String get profileFineUnpaid;
  String get profileFinePaid;
  String get profileFinePayKaspi;
  String get profileFineAmount;
  String get profileFineReason;
  String get finesEmpty;
  String get fineForAppointment;
  String get fineIssuedOn;
  String get finePaidOn;
  String get finesUnpaidTotal;
  String get profileChangePassword;
  String get profileCurrentPassword;
  String get profileNewPassword;
  String get profileSaveChanges;
  String get profileRole;
  String get profileExperience;
  String get profileBio;
  String get profileSpecialties;
  String get profileServices;
  String get profileNoFines;

  // ── Kaspi payment ─────────────────────────────────────────────────────────────
  String get kaspiTitle;
  String get kaspiContent;
  String get kaspiOpen;
  String get kaspiConfirmTitle;
  String get kaspiConfirmContent;
  String get kaspiConfirmYes;
  String get kaspiConfirmNo;
  String get kaspiPaidSuccess;

  // ── AI consultation ────────────────────────────────────────────────────────────
  String get aiTitle;
  String get aiSubtitle;
  String get aiHint;
  String get aiSend;
  String get aiEmpty;
  String get aiError;
  String get aiWelcome;
  String get aiDisclaimer;
  String get aiThinking;

  // ── Support ────────────────────────────────────────────────────────────────────
  String get supportTitle;
  String get supportHint;
  String get supportSend;
  String get supportEmpty;
  String get supportCategories;
  String get supportCategoryGeneral;
  String get supportCategoryAppointment;
  String get supportCategoryBilling;
  String get supportCategoryOther;
  String get supportStatus;
  String get supportOpen;
  String get supportClosed;

  // ── Notifications ──────────────────────────────────────────────────────────────
  String get notificationsTitle;
  String get notificationsEmpty;
  String get notificationsMarkAll;

  // ── QR Scanner ────────────────────────────────────────────────────────────────
  String get qrTitle;
  String get qrInstruction;
  String get qrFound;
  String get qrConfirm;
  String get qrError;
  String get qrPermission;
  String get qrAllowCamera;
  String get qrOpenSettings;
  String get qrSuccess;
  String get qrManualNote;
  String get qrManualHint;

  // ── Medical records ────────────────────────────────────────────────────────────
  String get medTitle;
  String get medEmpty;
  String get medAdd;
  String get medDate;
  String get medDiagnosis;
  String get medTreatment;
  String get medNotes;
  String get medDoctor;
  String get medClinic;
  String get medExport;
  String get medDelete;
  String get medDeleteConfirm;

  // ── Filter ─────────────────────────────────────────────────────────────────────
  String get filterTitle;
  String get filterSpecialty;
  String get filterCity;
  String get filterService;
  String get filterRating;
  String get filterApply;
  String get filterReset;
  String get filterAll;

  // ── Doctor detail ──────────────────────────────────────────────────────────────
  String get doctorAbout;
  String get doctorExperience;
  String get doctorSpecialties;
  String get doctorServices;
  String get doctorReviews;
  String get doctorBook;
  String get doctorNoReviews;
  String get doctorRating;
  String get doctorClinic;
  String get doctorYears;

  // ── Doctor dashboard ────────────────────────────────────────────────────────────
  String get dashDoctorTitle;
  String get dashDoctorToday;
  String get dashDoctorPatients;
  String get dashDoctorSchedule;
  String get dashDoctorNoAppointments;
  String get dashDoctorComplete;
  String get dashDoctorCompleteConfirm;

  // ── Admin dashboard ─────────────────────────────────────────────────────────────
  String get dashAdminTitle;
  String get dashAdminClinics;
  String get dashAdminDoctors;
  String get dashAdminPatients;
  String get dashAdminAppointments;
  String get dashAdminAddDoctor;
  String get dashAdminRemoveDoctor;
  String get dashAdminGenerateQr;
  String get dashAdminQrExpiry;
  String get dashAdminFines;
  String get dashAdminIssueFine;
  String get dashAdminStats;

  // ── Superadmin ─────────────────────────────────────────────────────────────────
  String get dashSuperTitle;
  String get dashSuperUsers;
  String get dashSuperClinics;
  String get dashSuperCreateClinic;
  String get dashSuperCreateAdmin;
  String get dashSuperDeactivate;
  String get dashSuperActivate;

  // ── Support manager ────────────────────────────────────────────────────────────
  String get dashSupportTitle;
  String get dashSupportTickets;
  String get dashSupportClose;
  String get dashSupportReply;
  String get dashSupportOpen;
  String get dashSupportClosed;

  // ── Review ──────────────────────────────────────────────────────────────────────
  String get reviewTitle;
  String get reviewRating;
  String get reviewComment;
  String get reviewSubmit;
  String get reviewSuccess;
  String get reviewCommentHint;
  String get reviewAnonymous;

  // ── Roles ───────────────────────────────────────────────────────────────────────
  String get rolePatient;
  String get roleDoctor;
  String get roleAdmin;
  String get roleSuperadmin;
  String get roleSupportManager;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RUSSIAN
// ═══════════════════════════════════════════════════════════════════════════════
class RuStrings extends AppStrings {
  // ── Navigation ───────────────────────────────────────────────────────────────
  @override String get navHome => 'Главная';
  @override String get navMap => 'Карта';
  @override String get navAppointments => 'Записи';
  @override String get navProfile => 'Профиль';
  @override String get navAi => 'ИИ-ассистент';
  @override String get navSupport => 'Чат-поддержка';
  @override String get navNotifications => 'Уведомления';

  // ── Common ────────────────────────────────────────────────────────────────────
  @override String get cancel => 'Отмена';
  @override String get confirm => 'Подтвердить';
  @override String get save => 'Сохранить';
  @override String get close => 'Закрыть';
  @override String get yes => 'Да';
  @override String get no => 'Нет';
  @override String get ok => 'ОК';
  @override String get back => 'Назад';
  @override String get retry => 'Повторить';
  @override String get loading => 'Загрузка...';
  @override String get error => 'Ошибка';
  @override String get success => 'Успешно';
  @override String get send => 'Отправить';
  @override String get delete => 'Удалить';
  @override String get edit => 'Редактировать';
  @override String get search => 'Поиск';
  @override String get filter => 'Фильтр';
  @override String get refresh => 'Обновить';
  @override String get apply => 'Применить';
  @override String get reset => 'Сбросить';
  @override String get next => 'Далее';
  @override String get done => 'Готово';
  @override String get notFound => 'Не найдено';
  @override String get serverError => 'Ошибка сервера';
  @override String get noData => 'Нет данных';
  @override String get required => 'Обязательное поле';

  // ── Auth ──────────────────────────────────────────────────────────────────────
  @override String get login => 'Войти';
  @override String get logout => 'Выйти';
  @override String get register => 'Зарегистрироваться';
  @override String get email => 'Email';
  @override String get password => 'Пароль';
  @override String get firstName => 'Имя';
  @override String get lastName => 'Фамилия';
  @override String get phone => 'Телефон';
  @override String get forgotPassword => 'Забыли пароль?';
  @override String get noAccount => 'Нет аккаунта?';
  @override String get haveAccount => 'Уже есть аккаунт?';
  @override String get enterEmail => 'Введите email';
  @override String get enterPassword => 'Введите пароль';
  @override String get enterFirstName => 'Введите имя';
  @override String get enterLastName => 'Введите фамилию';
  @override String get enterPhone => 'Введите телефон';
  @override String get loginTitle => 'Добро пожаловать!';
  @override String get registerTitle => 'Создать аккаунт';
  @override String get loginButton => 'Войти';
  @override String get registerButton => 'Зарегистрироваться';
  @override String get loginError => 'Неверный email или пароль';
  @override String get passwordMin => 'Минимум 6 символов';
  @override String get emailInvalid => 'Некорректный email';
  @override String get logoutConfirmTitle => 'Выйти из аккаунта?';
  @override String get logoutConfirmContent => 'Вы уверены, что хотите выйти?';
  @override String get logoutButton => 'Выйти';

  // ── Forgot password ───────────────────────────────────────────────────────────
  @override String get forgotTitle => 'Сброс пароля';
  @override String get forgotSubtitle => 'Введите email, чтобы получить код';
  @override String get forgotSend => 'Получить код';
  @override String get forgotCodeSent => 'Код отправлен на почту';
  @override String get forgotEnterCode => 'Введите код из письма';
  @override String get forgotNewPassword => 'Новый пароль';
  @override String get forgotConfirmPassword => 'Повторите пароль';
  @override String get forgotSubmit => 'Изменить пароль';
  @override String get forgotPasswordMismatch => 'Пароли не совпадают';
  @override String get forgotCodeLabel => 'Код';
  @override String get forgotSuccess => 'Пароль успешно изменён';

  // ── Home ──────────────────────────────────────────────────────────────────────
  @override String get homeGreeting => 'Здравствуйте!';
  @override String get homeSubtitle => 'Найдите врача или клинику';
  @override String get homeDoctors => 'Врачи';
  @override String get homeClinics => 'Клиники';
  @override String get homeServices => 'Услуги';
  @override String get homeSearchDoctors => 'Поиск врачей...';
  @override String get homeNoDoctors => 'Врачи не найдены';
  @override String get homeNoClinics => 'Клиники не найдены';
  @override String get homeExperience => 'Опыт';
  @override String get homeYears => 'лет';
  @override String get homeBook => 'Записаться';
  @override String get homeDetails => 'Подробнее';
  @override String get homeSpecialties => 'Специализация уточняется';
  @override String get homeAllDoctors => 'Все врачи';
  @override String get homeAllClinics => 'Все клиники';
  @override String get homeSectionBestDoctors => 'Лучшие врачи';
  @override String get homeSectionSubtitle => 'Выберите специалиста';
  @override String get homeNextVisitLabel => 'Ближайший визит';
  @override String get homeNoAppointmentTitle => 'Запишитесь на приём';
  @override String get homeNoAppointmentSubtitle => 'Выберите врача и удобное время';

  // ── Map ───────────────────────────────────────────────────────────────────────
  @override String get mapTitle => 'Карта клиник';
  @override String get mapNoClinics => 'Клиники не найдены';
  @override String get mapOpenRoute => 'Маршрут';
  @override String get mapTaxi => 'Вызвать такси';
  @override String get mapWorkingHours => 'Режим работы';
  @override String get mapClosed => 'Закрыто';
  @override String get mapOpen => 'Открыто';
  @override String get mapContacts => 'Контакты';
  @override String get mapDoctors => 'Врачи';
  @override String get mapServices => 'Услуги';
  @override String get mapBook => 'Записаться';
  @override String get mapAddress => 'Адрес';
  @override String get mapNoDoctorsMessage => 'Скоро добавим новых специалистов.';

  // ── Appointments ───────────────────────────────────────────────────────────────
  @override String get appointmentsTitle => 'Мои записи';
  @override String get appointmentsEmpty => 'Нет активных записей';
  @override String get appointmentsScheduled => 'Запланирован';
  @override String get appointmentsConfirmed => 'Подтверждён';
  @override String get appointmentsCompleted => 'Завершён';
  @override String get appointmentsCancelled => 'Отменён';
  @override String get appointmentsCancel => 'Отменить запись';
  @override String get appointmentsCancelTitle => 'Отменить запись?';
  @override String get appointmentsCancelContent => 'Вы хотите отменить запись?';
  @override String get appointmentsCancelDone => 'Запись отменена';
  @override String get appointmentsConfirmQr => 'Подтвердить через QR';
  @override String get appointmentsReview => 'Оставить отзыв';
  @override String get appointmentsLeaveReview => 'Отзыв';
  @override String get appointmentsDoctor => 'Врач';
  @override String get appointmentsClinic => 'Клиника';
  @override String get appointmentsDate => 'Дата';
  @override String get appointmentsTime => 'Время';
  @override String get appointmentsService => 'Услуга';
  @override String get appointmentsStatus => 'Статус';
  @override String get appointmentsQrSuccess => 'Запись подтверждена! ✓';
  @override String get appointmentsNoSlots => 'Нет доступных слотов';
  @override String get appointmentsUpcoming => 'Предстоящие';
  @override String get appointmentsPast => 'Прошедшие';

  // ── Booking ────────────────────────────────────────────────────────────────────
  @override String get bookTitle => 'Запись к врачу';
  @override String get bookDoctor => 'Врач';
  @override String get bookService => 'Услуга';
  @override String get bookDate => 'Дата';
  @override String get bookSlot => 'Время';
  @override String get bookComment => 'Комментарий';
  @override String get bookSubmit => 'Записаться';
  @override String get bookSuccess => 'Запись создана!';
  @override String get bookSelectService => 'Выберите услугу';
  @override String get bookSelectDate => 'Выберите дату';
  @override String get bookSelectSlot => 'Выберите время';
  @override String get bookNoSlots => 'На выбранную дату нет доступных слотов';
  @override String get bookCommentHint => 'Опишите жалобы (необязательно)';
  @override String get bookConfirmTitle => 'Подтвердить запись?';
  @override String get bookConfirmContent => 'Записаться на приём?';

  // ── Profile ────────────────────────────────────────────────────────────────────
  @override String get profileTitle => 'Профиль';
  @override String get profileEdit => 'Редактировать профиль';
  @override String get profileMedicalRecords => 'Медицинские записи';
  @override String get profileFines => 'Штрафы';
  @override String get profileFineUnpaid => 'Не оплачен';
  @override String get profileFinePaid => 'Оплачен';
  @override String get profileFinePayKaspi => 'Оплатить через Kaspi';
  @override String get profileFineAmount => 'Сумма';
  @override String get profileFineReason => 'Причина';
  @override String get finesEmpty => 'У вас нет штрафов';
  @override String get fineForAppointment => 'За запись';
  @override String get fineIssuedOn => 'Начислен';
  @override String get finePaidOn => 'Оплачен';
  @override String get finesUnpaidTotal => 'К оплате';
  @override String get profileChangePassword => 'Сменить пароль';
  @override String get profileCurrentPassword => 'Текущий пароль';
  @override String get profileNewPassword => 'Новый пароль';
  @override String get profileSaveChanges => 'Сохранить изменения';
  @override String get profileRole => 'Роль';
  @override String get profileExperience => 'Опыт работы';
  @override String get profileBio => 'О себе';
  @override String get profileSpecialties => 'Специальности';
  @override String get profileServices => 'Услуги';
  @override String get profileNoFines => 'Штрафов нет';

  // ── Kaspi ──────────────────────────────────────────────────────────────────────
  @override String get kaspiTitle => 'Оплата через Kaspi';
  @override String get kaspiContent => 'Сейчас откроется Kaspi для оплаты. После успешной оплаты вернитесь в приложение и подтвердите.';
  @override String get kaspiOpen => 'Открыть Kaspi';
  @override String get kaspiConfirmTitle => 'Подтверждение оплаты';
  @override String get kaspiConfirmContent => 'Вы успешно оплатили штраф через Kaspi?';
  @override String get kaspiConfirmYes => 'Да, оплатил';
  @override String get kaspiConfirmNo => 'Ещё нет';
  @override String get kaspiPaidSuccess => 'Штраф оплачен ✓';

  // ── AI ─────────────────────────────────────────────────────────────────────────
  @override String get aiTitle => 'ИИ-консультация';
  @override String get aiSubtitle => 'Стоматологический ассистент';
  @override String get aiHint => 'Задайте вопрос о здоровье зубов...';
  @override String get aiSend => 'Отправить';
  @override String get aiEmpty => 'Задайте вопрос стоматологическому ИИ-ассистенту';
  @override String get aiError => 'ИИ временно недоступен. Попробуйте позже.';
  @override String get aiWelcome => 'Здравствуйте! Я — ваш стоматологический ИИ-ассистент. Задайте вопрос о здоровье зубов.';
  @override String get aiDisclaimer => 'ИИ не ставит диагнозы. При серьёзных симптомах обратитесь к врачу.';
  @override String get aiThinking => 'Думаю...';

  // ── Support ────────────────────────────────────────────────────────────────────
  @override String get supportTitle => 'Поддержка';
  @override String get supportHint => 'Напишите сообщение...';
  @override String get supportSend => 'Отправить';
  @override String get supportEmpty => 'Нет сообщений';
  @override String get supportCategories => 'Категория';
  @override String get supportCategoryGeneral => 'Общий вопрос';
  @override String get supportCategoryAppointment => 'Запись на приём';
  @override String get supportCategoryBilling => 'Оплата';
  @override String get supportCategoryOther => 'Другое';
  @override String get supportStatus => 'Статус';
  @override String get supportOpen => 'Открыт';
  @override String get supportClosed => 'Закрыт';

  // ── Notifications ───────────────────────────────────────────────────────────────
  @override String get notificationsTitle => 'Уведомления';
  @override String get notificationsEmpty => 'Нет уведомлений';
  @override String get notificationsMarkAll => 'Отметить все прочитанными';

  // ── QR ─────────────────────────────────────────────────────────────────────────
  @override String get qrTitle => 'Сканер QR';
  @override String get qrInstruction => 'Наведите камеру на QR-код';
  @override String get qrFound => 'QR найден';
  @override String get qrConfirm => 'Подтвердить';
  @override String get qrError => 'Ошибка сканирования';
  @override String get qrPermission => 'Нужен доступ к камере';
  @override String get qrAllowCamera => 'Разрешить доступ';
  @override String get qrOpenSettings => 'Открыть настройки';
  @override String get qrSuccess => 'Приём подтверждён!';
  @override String get qrManualNote => 'Сканирование камерой доступно на реальном устройстве. Введите код из QR вручную.';
  @override String get qrManualHint => 'Код из QR';

  // ── Medical records ─────────────────────────────────────────────────────────────
  @override String get medTitle => 'Медицинские записи';
  @override String get medEmpty => 'Нет медицинских записей';
  @override String get medAdd => 'Добавить запись';
  @override String get medDate => 'Дата';
  @override String get medDiagnosis => 'Диагноз';
  @override String get medTreatment => 'Лечение';
  @override String get medNotes => 'Заметки';
  @override String get medDoctor => 'Врач';
  @override String get medClinic => 'Клиника';
  @override String get medExport => 'Экспорт PDF';
  @override String get medDelete => 'Удалить';
  @override String get medDeleteConfirm => 'Удалить запись?';

  // ── Filter ──────────────────────────────────────────────────────────────────────
  @override String get filterTitle => 'Фильтры';
  @override String get filterSpecialty => 'Специальность';
  @override String get filterCity => 'Город';
  @override String get filterService => 'Услуга';
  @override String get filterRating => 'Рейтинг';
  @override String get filterApply => 'Применить';
  @override String get filterReset => 'Сбросить';
  @override String get filterAll => 'Все';

  // ── Doctor detail ───────────────────────────────────────────────────────────────
  @override String get doctorAbout => 'О враче';
  @override String get doctorExperience => 'Опыт';
  @override String get doctorSpecialties => 'Специальности';
  @override String get doctorServices => 'Услуги';
  @override String get doctorReviews => 'Отзывы';
  @override String get doctorBook => 'Записаться';
  @override String get doctorNoReviews => 'Нет отзывов';
  @override String get doctorRating => 'Рейтинг';
  @override String get doctorClinic => 'Клиника';
  @override String get doctorYears => 'лет опыта';

  // ── Doctor dashboard ────────────────────────────────────────────────────────────
  @override String get dashDoctorTitle => 'Кабинет врача';
  @override String get dashDoctorToday => 'Сегодня';
  @override String get dashDoctorPatients => 'Пациенты';
  @override String get dashDoctorSchedule => 'Расписание';
  @override String get dashDoctorNoAppointments => 'Нет записей на сегодня';
  @override String get dashDoctorComplete => 'Завершить приём';
  @override String get dashDoctorCompleteConfirm => 'Отметить приём как завершённый?';

  // ── Admin dashboard ─────────────────────────────────────────────────────────────
  @override String get dashAdminTitle => 'Панель администратора';
  @override String get dashAdminClinics => 'Клиники';
  @override String get dashAdminDoctors => 'Врачи';
  @override String get dashAdminPatients => 'Пациенты';
  @override String get dashAdminAppointments => 'Записи';
  @override String get dashAdminAddDoctor => 'Добавить врача';
  @override String get dashAdminRemoveDoctor => 'Удалить врача';
  @override String get dashAdminGenerateQr => 'Сгенерировать QR';
  @override String get dashAdminQrExpiry => 'QR действителен 5 минут';
  @override String get dashAdminFines => 'Штрафы';
  @override String get dashAdminIssueFine => 'Выписать штраф';
  @override String get dashAdminStats => 'Статистика';

  // ── Superadmin ──────────────────────────────────────────────────────────────────
  @override String get dashSuperTitle => 'Суперадмин';
  @override String get dashSuperUsers => 'Пользователи';
  @override String get dashSuperClinics => 'Клиники';
  @override String get dashSuperCreateClinic => 'Создать клинику';
  @override String get dashSuperCreateAdmin => 'Создать администратора';
  @override String get dashSuperDeactivate => 'Деактивировать';
  @override String get dashSuperActivate => 'Активировать';

  // ── Support manager ─────────────────────────────────────────────────────────────
  @override String get dashSupportTitle => 'Менеджер поддержки';
  @override String get dashSupportTickets => 'Тикеты';
  @override String get dashSupportClose => 'Закрыть тикет';
  @override String get dashSupportReply => 'Ответить';
  @override String get dashSupportOpen => 'Открытые';
  @override String get dashSupportClosed => 'Закрытые';

  // ── Review ──────────────────────────────────────────────────────────────────────
  @override String get reviewTitle => 'Оставить отзыв';
  @override String get reviewRating => 'Оценка';
  @override String get reviewComment => 'Комментарий';
  @override String get reviewSubmit => 'Отправить отзыв';
  @override String get reviewSuccess => 'Отзыв отправлен!';
  @override String get reviewCommentHint => 'Напишите о своём опыте...';
  @override String get reviewAnonymous => 'Анонимный отзыв';

  // ── Roles ───────────────────────────────────────────────────────────────────────
  @override String get rolePatient => 'Пациент';
  @override String get roleDoctor => 'Врач';
  @override String get roleAdmin => 'Администратор';
  @override String get roleSuperadmin => 'Суперадмин';
  @override String get roleSupportManager => 'Менеджер поддержки';
}

// ═══════════════════════════════════════════════════════════════════════════════
// KAZAKH
// ═══════════════════════════════════════════════════════════════════════════════
class KkStrings extends AppStrings {
  // ── Navigation ───────────────────────────────────────────────────────────────
  @override String get navHome => 'Басты бет';
  @override String get navMap => 'Карта';
  @override String get navAppointments => 'Жазбалар';
  @override String get navProfile => 'Профиль';
  @override String get navAi => 'ЖИ-ассистент';
  @override String get navSupport => 'Қолдау чаты';
  @override String get navNotifications => 'Хабарламалар';

  // ── Common ────────────────────────────────────────────────────────────────────
  @override String get cancel => 'Болдырмау';
  @override String get confirm => 'Растау';
  @override String get save => 'Сақтау';
  @override String get close => 'Жабу';
  @override String get yes => 'Иә';
  @override String get no => 'Жоқ';
  @override String get ok => 'Жарайды';
  @override String get back => 'Артқа';
  @override String get retry => 'Қайталау';
  @override String get loading => 'Жүктелуде...';
  @override String get error => 'Қате';
  @override String get success => 'Сәтті';
  @override String get send => 'Жіберу';
  @override String get delete => 'Жою';
  @override String get edit => 'Өңдеу';
  @override String get search => 'Іздеу';
  @override String get filter => 'Сүзгі';
  @override String get refresh => 'Жаңарту';
  @override String get apply => 'Қолдану';
  @override String get reset => 'Тазалау';
  @override String get next => 'Келесі';
  @override String get done => 'Дайын';
  @override String get notFound => 'Табылмады';
  @override String get serverError => 'Сервер қатесі';
  @override String get noData => 'Деректер жоқ';
  @override String get required => 'Міндетті өріс';

  // ── Auth ──────────────────────────────────────────────────────────────────────
  @override String get login => 'Кіру';
  @override String get logout => 'Шығу';
  @override String get register => 'Тіркелу';
  @override String get email => 'Email';
  @override String get password => 'Құпия сөз';
  @override String get firstName => 'Аты';
  @override String get lastName => 'Тегі';
  @override String get phone => 'Телефон';
  @override String get forgotPassword => 'Құпия сөзді ұмыттыңыз ба?';
  @override String get noAccount => 'Аккаунт жоқ па?';
  @override String get haveAccount => 'Аккаунт бар ма?';
  @override String get enterEmail => 'Email енгізіңіз';
  @override String get enterPassword => 'Құпия сөз енгізіңіз';
  @override String get enterFirstName => 'Атыңызды енгізіңіз';
  @override String get enterLastName => 'Тегіңізді енгізіңіз';
  @override String get enterPhone => 'Телефонды енгізіңіз';
  @override String get loginTitle => 'Қош келдіңіз!';
  @override String get registerTitle => 'Аккаунт жасау';
  @override String get loginButton => 'Кіру';
  @override String get registerButton => 'Тіркелу';
  @override String get loginError => 'Email немесе құпия сөз қате';
  @override String get passwordMin => 'Кемінде 6 таңба';
  @override String get emailInvalid => 'Email дұрыс емес';
  @override String get logoutConfirmTitle => 'Шығу?';
  @override String get logoutConfirmContent => 'Шынымен шығасыз ба?';
  @override String get logoutButton => 'Шығу';

  // ── Forgot password ───────────────────────────────────────────────────────────
  @override String get forgotTitle => 'Құпия сөзді қалпына келтіру';
  @override String get forgotSubtitle => 'Код алу үшін email енгізіңіз';
  @override String get forgotSend => 'Код алу';
  @override String get forgotCodeSent => 'Код поштаға жіберілді';
  @override String get forgotEnterCode => 'Хаттан кодты енгізіңіз';
  @override String get forgotNewPassword => 'Жаңа құпия сөз';
  @override String get forgotConfirmPassword => 'Құпия сөзді қайталаңыз';
  @override String get forgotSubmit => 'Құпия сөзді өзгерту';
  @override String get forgotPasswordMismatch => 'Құпия сөздер сәйкес келмейді';
  @override String get forgotCodeLabel => 'Код';
  @override String get forgotSuccess => 'Құпия сөз сәтті өзгертілді';

  // ── Home ──────────────────────────────────────────────────────────────────────
  @override String get homeGreeting => 'Сәлеметсіз бе!';
  @override String get homeSubtitle => 'Дәрігер немесе клиника тауып алыңыз';
  @override String get homeDoctors => 'Дәрігерлер';
  @override String get homeClinics => 'Клиникалар';
  @override String get homeServices => 'Қызметтер';
  @override String get homeSearchDoctors => 'Дәрігер іздеу...';
  @override String get homeNoDoctors => 'Дәрігерлер табылмады';
  @override String get homeNoClinics => 'Клиникалар табылмады';
  @override String get homeExperience => 'Тәжірибе';
  @override String get homeYears => 'жыл';
  @override String get homeBook => 'Жазылу';
  @override String get homeDetails => 'Толығырақ';
  @override String get homeSpecialties => 'Мамандық нақтыланады';
  @override String get homeAllDoctors => 'Барлық дәрігерлер';
  @override String get homeAllClinics => 'Барлық клиникалар';
  @override String get homeSectionBestDoctors => 'Үздік дәрігерлер';
  @override String get homeSectionSubtitle => 'Маманды таңдаңыз';
  @override String get homeNextVisitLabel => 'Жақын визит';
  @override String get homeNoAppointmentTitle => 'Қабылдауға жазылыңыз';
  @override String get homeNoAppointmentSubtitle => 'Дәрігер мен ыңғайлы уақытты таңдаңыз';

  // ── Map ───────────────────────────────────────────────────────────────────────
  @override String get mapTitle => 'Клиникалар картасы';
  @override String get mapNoClinics => 'Клиникалар табылмады';
  @override String get mapOpenRoute => 'Маршрут';
  @override String get mapTaxi => 'Такси шақыру';
  @override String get mapWorkingHours => 'Жұмыс уақыты';
  @override String get mapClosed => 'Жабық';
  @override String get mapOpen => 'Ашық';
  @override String get mapContacts => 'Байланыс';
  @override String get mapDoctors => 'Дәрігерлер';
  @override String get mapServices => 'Қызметтер';
  @override String get mapBook => 'Жазылу';
  @override String get mapAddress => 'Мекенжай';
  @override String get mapNoDoctorsMessage => 'Жақында жаңа мамандар қосамыз.';

  // ── Appointments ───────────────────────────────────────────────────────────────
  @override String get appointmentsTitle => 'Менің жазбаларым';
  @override String get appointmentsEmpty => 'Белсенді жазбалар жоқ';
  @override String get appointmentsScheduled => 'Жоспарланған';
  @override String get appointmentsConfirmed => 'Расталған';
  @override String get appointmentsCompleted => 'Аяқталған';
  @override String get appointmentsCancelled => 'Болдырылмаған';
  @override String get appointmentsCancel => 'Жазбаны болдырмау';
  @override String get appointmentsCancelTitle => 'Жазбаны болдырмау?';
  @override String get appointmentsCancelContent => 'Жазбаны болдырмағыңыз келе ме?';
  @override String get appointmentsCancelDone => 'Жазба болдырылмады';
  @override String get appointmentsConfirmQr => 'QR арқылы растау';
  @override String get appointmentsReview => 'Пікір қалдыру';
  @override String get appointmentsLeaveReview => 'Пікір';
  @override String get appointmentsDoctor => 'Дәрігер';
  @override String get appointmentsClinic => 'Клиника';
  @override String get appointmentsDate => 'Күн';
  @override String get appointmentsTime => 'Уақыт';
  @override String get appointmentsService => 'Қызмет';
  @override String get appointmentsStatus => 'Күй';
  @override String get appointmentsQrSuccess => 'Жазба расталды! ✓';
  @override String get appointmentsNoSlots => 'Бос слоттар жоқ';
  @override String get appointmentsUpcoming => 'Алдағы';
  @override String get appointmentsPast => 'Өткен';

  // ── Booking ────────────────────────────────────────────────────────────────────
  @override String get bookTitle => 'Дәрігерге жазылу';
  @override String get bookDoctor => 'Дәрігер';
  @override String get bookService => 'Қызмет';
  @override String get bookDate => 'Күн';
  @override String get bookSlot => 'Уақыт';
  @override String get bookComment => 'Түсініктеме';
  @override String get bookSubmit => 'Жазылу';
  @override String get bookSuccess => 'Жазба жасалды!';
  @override String get bookSelectService => 'Қызметті таңдаңыз';
  @override String get bookSelectDate => 'Күнді таңдаңыз';
  @override String get bookSelectSlot => 'Уақытты таңдаңыз';
  @override String get bookNoSlots => 'Таңдалған күнге бос слоттар жоқ';
  @override String get bookCommentHint => 'Шағымдарды сипаттаңыз (міндетті емес)';
  @override String get bookConfirmTitle => 'Жазбаны растау?';
  @override String get bookConfirmContent => 'Қабылдауға жазылу?';

  // ── Profile ────────────────────────────────────────────────────────────────────
  @override String get profileTitle => 'Профиль';
  @override String get profileEdit => 'Профильді өңдеу';
  @override String get profileMedicalRecords => 'Медициналық жазбалар';
  @override String get profileFines => 'Айыппұлдар';
  @override String get profileFineUnpaid => 'Төленбеген';
  @override String get profileFinePaid => 'Төленген';
  @override String get profileFinePayKaspi => 'Kaspi арқылы төлеу';
  @override String get profileFineAmount => 'Сома';
  @override String get profileFineReason => 'Себеп';
  @override String get finesEmpty => 'Сізде айыппұл жоқ';
  @override String get fineForAppointment => 'Жазба үшін';
  @override String get fineIssuedOn => 'Есептелді';
  @override String get finePaidOn => 'Төленді';
  @override String get finesUnpaidTotal => 'Төлеуге';
  @override String get profileChangePassword => 'Құпия сөзді өзгерту';
  @override String get profileCurrentPassword => 'Ағымдағы құпия сөз';
  @override String get profileNewPassword => 'Жаңа құпия сөз';
  @override String get profileSaveChanges => 'Өзгерістерді сақтау';
  @override String get profileRole => 'Рөл';
  @override String get profileExperience => 'Жұмыс тәжірибесі';
  @override String get profileBio => 'Өзім туралы';
  @override String get profileSpecialties => 'Мамандықтар';
  @override String get profileServices => 'Қызметтер';
  @override String get profileNoFines => 'Айыппұлдар жоқ';

  // ── Kaspi ──────────────────────────────────────────────────────────────────────
  @override String get kaspiTitle => 'Kaspi арқылы төлеу';
  @override String get kaspiContent => 'Қазір Kaspi ашылады. Сәтті төлегеннен кейін қайтып, растаңыз.';
  @override String get kaspiOpen => 'Kaspi ашу';
  @override String get kaspiConfirmTitle => 'Төлемді растау';
  @override String get kaspiConfirmContent => 'Kaspi арқылы айыппұлды сәтті төледіңіз бе?';
  @override String get kaspiConfirmYes => 'Иә, төледім';
  @override String get kaspiConfirmNo => 'Әлі жоқ';
  @override String get kaspiPaidSuccess => 'Айыппұл төленді ✓';

  // ── AI ─────────────────────────────────────────────────────────────────────────
  @override String get aiTitle => 'ЖИ-кеңес';
  @override String get aiSubtitle => 'Стоматологиялық ассистент';
  @override String get aiHint => 'Тіс денсаулығы туралы сұрақ қойыңыз...';
  @override String get aiSend => 'Жіберу';
  @override String get aiEmpty => 'Стоматологиялық ЖИ-ассистентке сұрақ қойыңыз';
  @override String get aiError => 'ЖИ уақытша қолжетімді емес. Кейінірек қайталаңыз.';
  @override String get aiWelcome => 'Сәлеметсіз бе! Мен — стоматологиялық ЖИ-ассистентіңіз. Тіс денсаулығы туралы сұрақ қойыңыз.';
  @override String get aiDisclaimer => 'ЖИ диагноз қоймайды. Ауыр белгілер болса дәрігерге барыңыз.';
  @override String get aiThinking => 'Ойланып жатыр...';

  // ── Support ────────────────────────────────────────────────────────────────────
  @override String get supportTitle => 'Қолдау қызметі';
  @override String get supportHint => 'Хабарлама жазыңыз...';
  @override String get supportSend => 'Жіберу';
  @override String get supportEmpty => 'Хабарламалар жоқ';
  @override String get supportCategories => 'Санат';
  @override String get supportCategoryGeneral => 'Жалпы сұрақ';
  @override String get supportCategoryAppointment => 'Қабылдауға жазылу';
  @override String get supportCategoryBilling => 'Төлем';
  @override String get supportCategoryOther => 'Басқа';
  @override String get supportStatus => 'Күй';
  @override String get supportOpen => 'Ашық';
  @override String get supportClosed => 'Жабық';

  // ── Notifications ───────────────────────────────────────────────────────────────
  @override String get notificationsTitle => 'Хабарламалар';
  @override String get notificationsEmpty => 'Хабарламалар жоқ';
  @override String get notificationsMarkAll => 'Барлығын оқылды деп белгілеу';

  // ── QR ─────────────────────────────────────────────────────────────────────────
  @override String get qrTitle => 'QR сканер';
  @override String get qrInstruction => 'Камераны QR-кодқа бағыттаңыз';
  @override String get qrFound => 'QR табылды';
  @override String get qrConfirm => 'Растау';
  @override String get qrError => 'Сканерлеу қатесі';
  @override String get qrPermission => 'Камераға рұқсат қажет';
  @override String get qrAllowCamera => 'Рұқсат беру';
  @override String get qrOpenSettings => 'Параметрлерді ашу';
  @override String get qrSuccess => 'Қабылдау расталды!';
  @override String get qrManualNote => 'Камерамен сканерлеу нақты құрылғыда қолжетімді. QR кодын қолмен енгізіңіз.';
  @override String get qrManualHint => 'QR коды';

  // ── Medical records ─────────────────────────────────────────────────────────────
  @override String get medTitle => 'Медициналық жазбалар';
  @override String get medEmpty => 'Медициналық жазбалар жоқ';
  @override String get medAdd => 'Жазба қосу';
  @override String get medDate => 'Күн';
  @override String get medDiagnosis => 'Диагноз';
  @override String get medTreatment => 'Ем';
  @override String get medNotes => 'Жазбалар';
  @override String get medDoctor => 'Дәрігер';
  @override String get medClinic => 'Клиника';
  @override String get medExport => 'PDF экспорт';
  @override String get medDelete => 'Жою';
  @override String get medDeleteConfirm => 'Жазбаны жою?';

  // ── Filter ──────────────────────────────────────────────────────────────────────
  @override String get filterTitle => 'Сүзгілер';
  @override String get filterSpecialty => 'Мамандық';
  @override String get filterCity => 'Қала';
  @override String get filterService => 'Қызмет';
  @override String get filterRating => 'Рейтинг';
  @override String get filterApply => 'Қолдану';
  @override String get filterReset => 'Тазалау';
  @override String get filterAll => 'Барлығы';

  // ── Doctor detail ───────────────────────────────────────────────────────────────
  @override String get doctorAbout => 'Дәрігер туралы';
  @override String get doctorExperience => 'Тәжірибе';
  @override String get doctorSpecialties => 'Мамандықтар';
  @override String get doctorServices => 'Қызметтер';
  @override String get doctorReviews => 'Пікірлер';
  @override String get doctorBook => 'Жазылу';
  @override String get doctorNoReviews => 'Пікірлер жоқ';
  @override String get doctorRating => 'Рейтинг';
  @override String get doctorClinic => 'Клиника';
  @override String get doctorYears => 'жыл тәжірибе';

  // ── Doctor dashboard ────────────────────────────────────────────────────────────
  @override String get dashDoctorTitle => 'Дәрігер кабинеті';
  @override String get dashDoctorToday => 'Бүгін';
  @override String get dashDoctorPatients => 'Науқастар';
  @override String get dashDoctorSchedule => 'Кесте';
  @override String get dashDoctorNoAppointments => 'Бүгінге жазбалар жоқ';
  @override String get dashDoctorComplete => 'Қабылдауды аяқтау';
  @override String get dashDoctorCompleteConfirm => 'Қабылдауды аяқталды деп белгілеу?';

  // ── Admin dashboard ─────────────────────────────────────────────────────────────
  @override String get dashAdminTitle => 'Әкімші панелі';
  @override String get dashAdminClinics => 'Клиникалар';
  @override String get dashAdminDoctors => 'Дәрігерлер';
  @override String get dashAdminPatients => 'Науқастар';
  @override String get dashAdminAppointments => 'Жазбалар';
  @override String get dashAdminAddDoctor => 'Дәрігер қосу';
  @override String get dashAdminRemoveDoctor => 'Дәрігерді жою';
  @override String get dashAdminGenerateQr => 'QR генерациялау';
  @override String get dashAdminQrExpiry => 'QR 5 минут жарамды';
  @override String get dashAdminFines => 'Айыппұлдар';
  @override String get dashAdminIssueFine => 'Айыппұл шығару';
  @override String get dashAdminStats => 'Статистика';

  // ── Superadmin ──────────────────────────────────────────────────────────────────
  @override String get dashSuperTitle => 'Суперәкімші';
  @override String get dashSuperUsers => 'Пайдаланушылар';
  @override String get dashSuperClinics => 'Клиникалар';
  @override String get dashSuperCreateClinic => 'Клиника жасау';
  @override String get dashSuperCreateAdmin => 'Әкімші жасау';
  @override String get dashSuperDeactivate => 'Өшіру';
  @override String get dashSuperActivate => 'Белсендіру';

  // ── Support manager ─────────────────────────────────────────────────────────────
  @override String get dashSupportTitle => 'Қолдау менеджері';
  @override String get dashSupportTickets => 'Тикеттер';
  @override String get dashSupportClose => 'Тикетті жабу';
  @override String get dashSupportReply => 'Жауап беру';
  @override String get dashSupportOpen => 'Ашық';
  @override String get dashSupportClosed => 'Жабық';

  // ── Review ──────────────────────────────────────────────────────────────────────
  @override String get reviewTitle => 'Пікір қалдыру';
  @override String get reviewRating => 'Баға';
  @override String get reviewComment => 'Түсініктеме';
  @override String get reviewSubmit => 'Пікір жіберу';
  @override String get reviewSuccess => 'Пікір жіберілді!';
  @override String get reviewCommentHint => 'Тәжірибеңіз туралы жазыңыз...';
  @override String get reviewAnonymous => 'Анонимді пікір';

  // ── Roles ───────────────────────────────────────────────────────────────────────
  @override String get rolePatient => 'Науқас';
  @override String get roleDoctor => 'Дәрігер';
  @override String get roleAdmin => 'Әкімші';
  @override String get roleSuperadmin => 'Суперәкімші';
  @override String get roleSupportManager => 'Қолдау менеджері';
}
