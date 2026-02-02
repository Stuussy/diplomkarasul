const { google } = require('googleapis');
const crypto = require('crypto');
const User = require('../models/User');

const SCOPES = ['https://www.googleapis.com/auth/calendar.events'];

function createOAuthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI,
  );
}

function ensureOAuthConfig() {
  const missing = [];
  if (!process.env.GOOGLE_CLIENT_ID) missing.push('GOOGLE_CLIENT_ID');
  if (!process.env.GOOGLE_CLIENT_SECRET) missing.push('GOOGLE_CLIENT_SECRET');
  if (!process.env.GOOGLE_REDIRECT_URI) missing.push('GOOGLE_REDIRECT_URI');
  if (missing.length > 0) {
    throw new Error(`Google OAuth не настроен: ${missing.join(', ')}`);
  }
}

async function issueState(userId) {
  const token = crypto.randomBytes(16).toString('hex');
  const state = `${userId}.${token}`;
  await User.findByIdAndUpdate(userId, {
    googleOauthState: state,
    googleOauthStateExpires: new Date(Date.now() + 10 * 60 * 1000),
  });
  return state;
}

async function verifyState(state) {
  if (!state || !state.includes('.')) return null;
  const [userId] = state.split('.');
  const user = await User.findById(userId);
  if (!user || user.googleOauthState !== state) return null;
  if (user.googleOauthStateExpires && user.googleOauthStateExpires < new Date()) return null;
  return user;
}

async function getAuthUrl(userId) {
  ensureOAuthConfig();
  const oauth2Client = createOAuthClient();
  const state = await issueState(userId);
  return oauth2Client.generateAuthUrl({
    access_type: 'offline',
    prompt: 'consent',
    scope: SCOPES,
    state,
  });
}

async function saveTokens(user, tokens) {
  const update = {
    googleOauthState: null,
    googleOauthStateExpires: null,
  };
  if (tokens.access_token) update['google.accessToken'] = tokens.access_token;
  if (tokens.refresh_token) update['google.refreshToken'] = tokens.refresh_token;
  if (tokens.expiry_date) update['google.tokenExpiry'] = new Date(tokens.expiry_date);
  update['google.connected'] = Boolean(update['google.refreshToken'] || user.google?.refreshToken);
  if (!user.google?.calendarId) update['google.calendarId'] = 'primary';

  await User.findByIdAndUpdate(user._id, update, { new: true });
}

async function handleOAuthCallback(code, state) {
  ensureOAuthConfig();
  const user = await verifyState(state);
  if (!user) {
    throw new Error('Некорректный state');
  }

  const oauth2Client = createOAuthClient();
  const { tokens } = await oauth2Client.getToken(code);
  const finalTokens = {
    access_token: tokens.access_token,
    refresh_token: tokens.refresh_token || user.google?.refreshToken,
    expiry_date: tokens.expiry_date,
  };

  await saveTokens(user, finalTokens);
  return user;
}

async function disconnect(userId) {
  await User.findByIdAndUpdate(userId, {
    google: {
      connected: false,
      calendarId: 'primary',
      accessToken: null,
      refreshToken: null,
      tokenExpiry: null,
    },
    googleOauthState: null,
    googleOauthStateExpires: null,
  });
}

async function getCalendarClient(user) {
  if (!user?.google?.refreshToken) {
    return null;
  }
  ensureOAuthConfig();
  const oauth2Client = createOAuthClient();
  oauth2Client.setCredentials({
    access_token: user.google.accessToken || undefined,
    refresh_token: user.google.refreshToken,
    expiry_date: user.google.tokenExpiry ? new Date(user.google.tokenExpiry).getTime() : undefined,
  });

  oauth2Client.on('tokens', async (tokens) => {
    const update = {};
    if (tokens.access_token) update['google.accessToken'] = tokens.access_token;
    if (tokens.refresh_token) update['google.refreshToken'] = tokens.refresh_token;
    if (tokens.expiry_date) update['google.tokenExpiry'] = new Date(tokens.expiry_date);
    update['google.connected'] = true;
    await User.findByIdAndUpdate(user._id, update);
  });

  return google.calendar({ version: 'v3', auth: oauth2Client });
}

function buildEventPayload({
  appointment,
  clinic,
  patient,
  doctor,
  roleLabel,
}) {
  const timezone = process.env.CALENDAR_TIMEZONE || 'UTC';
  const start = appointment.startTime;
  const end = appointment.endTime || new Date(appointment.startTime.getTime() + appointment.durationMinutes * 60000);
  const summary = `Прием (${appointment.service})`;
  const description = `Клиника: ${clinic?.name || '—'}\nПациент: ${patient?.firstName || ''} ${patient?.lastName || ''}\nВрач: ${doctor?.firstName || ''} ${doctor?.lastName || ''}\nРоль: ${roleLabel}`.trim();

  return {
    summary,
    description,
    start: { dateTime: start.toISOString(), timeZone: timezone },
    end: { dateTime: end.toISOString(), timeZone: timezone },
  };
}

async function safeCalendarCall(user, fn) {
  if (!user?.google?.refreshToken) {
    return { status: 'skipped' };
  }
  try {
    const calendar = await getCalendarClient(user);
    if (!calendar) return { status: 'skipped' };
    const calendarId = user.google?.calendarId || 'primary';
    const result = await fn(calendar, calendarId);
    return { status: 'ok', result };
  } catch (error) {
    const message = error?.response?.data?.error?.message || error?.message || 'Google error';
    if (error?.response?.data?.error === 'invalid_grant') {
      await User.findByIdAndUpdate(user._id, { 'google.connected': false });
    }
    return { status: 'failed', error: message };
  }
}

module.exports = {
  getAuthUrl,
  handleOAuthCallback,
  disconnect,
  buildEventPayload,
  safeCalendarCall,
};
