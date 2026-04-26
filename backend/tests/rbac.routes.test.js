const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildJsonApp,
  loadFreshModuleWithMocks,
  requestJson,
  selectQuery,
  signTestToken,
} = require('./helpers');

test('PATCH /users/:id blocks admin from editing non-doctor users', async () => {
  let updateCalled = false;

  const User = {
    findById(id) {
      if (id === 'target-user') {
        return selectQuery({ _id: id, role: 'patient', clinics: ['clinic-1'] });
      }
      if (id === 'admin-1') {
        return selectQuery({ _id: id, clinics: ['clinic-1'] });
      }
      throw new Error(`Unexpected User.findById(${id})`);
    },
    findByIdAndUpdate() {
      updateCalled = true;
      return selectQuery({ _id: 'target-user' });
    },
  };

  const Clinic = {
    find() {
      return selectQuery([]);
    },
  };

  const router = loadFreshModuleWithMocks('routes/users.js', {
    'models/User.js': User,
    'models/Clinic.js': Clinic,
  });

  const response = await requestJson(buildJsonApp('/users', router), {
    method: 'PATCH',
    requestPath: '/users/target-user',
    token: signTestToken({ id: 'admin-1', role: 'admin' }),
    body: { firstName: 'Updated' },
  });

  assert.equal(response.status, 403);
  assert.equal(response.body.message, 'Админ может редактировать только врачей своих клиник.');
  assert.equal(updateCalled, false);
});

test('PATCH /users/:id allows admin to edit doctor from owned clinic', async () => {
  let updateArgs = null;

  const User = {
    findById(id) {
      if (id === 'doctor-1') {
        return selectQuery({ _id: id, role: 'doctor', clinics: ['clinic-owned'] });
      }
      if (id === 'admin-1') {
        return selectQuery({ _id: id, clinics: [] });
      }
      throw new Error(`Unexpected User.findById(${id})`);
    },
    findByIdAndUpdate(id, updates) {
      updateArgs = { id, updates };
      return selectQuery({ _id: id, firstName: updates.firstName, role: 'doctor' });
    },
  };

  const Clinic = {
    find(query) {
      assert.deepEqual(query, { admin: 'admin-1' });
      return selectQuery([{ _id: 'clinic-owned' }]);
    },
  };

  const router = loadFreshModuleWithMocks('routes/users.js', {
    'models/User.js': User,
    'models/Clinic.js': Clinic,
  });

  const response = await requestJson(buildJsonApp('/users', router), {
    method: 'PATCH',
    requestPath: '/users/doctor-1',
    token: signTestToken({ id: 'admin-1', role: 'admin' }),
    body: { firstName: 'Alice' },
  });

  assert.equal(response.status, 200);
  assert.equal(response.body.firstName, 'Alice');
  assert.deepEqual(updateArgs, {
    id: 'doctor-1',
    updates: { firstName: 'Alice' },
  });
});

test('GET /stats/overview for admin loads clinic scope from the database', async () => {
  const doctorCountFilters = [];

  const User = {
    findById(id) {
      assert.equal(id, 'admin-1');
      return selectQuery({ _id: id, clinics: [] });
    },
    countDocuments(filter) {
      doctorCountFilters.push(filter);
      return Promise.resolve(3);
    },
  };

  const Appointment = {
    distinct(field, filter) {
      assert.equal(field, 'patient');
      assert.deepEqual(filter, { clinic: { $in: ['clinic-db'] } });
      return Promise.resolve(['patient-1', 'patient-2']);
    },
    countDocuments(filter) {
      assert.deepEqual(filter, { clinic: { $in: ['clinic-db'] } });
      return Promise.resolve(7);
    },
  };

  const Clinic = {
    find(query) {
      if (query.admin === 'admin-1') {
        return selectQuery([{ _id: 'clinic-db' }]);
      }
      assert.deepEqual(query, { _id: { $in: ['clinic-db'] } });
      return Promise.resolve([{ _id: 'clinic-db', name: 'Owned clinic' }]);
    },
  };

  const router = loadFreshModuleWithMocks('routes/stats.js', {
    'models/User.js': User,
    'models/Appointment.js': Appointment,
    'models/Clinic.js': Clinic,
  });

  const response = await requestJson(buildJsonApp('/stats', router), {
    method: 'GET',
    requestPath: '/stats/overview',
    token: signTestToken({ id: 'admin-1', role: 'admin' }),
  });

  assert.equal(response.status, 200);
  assert.deepEqual(doctorCountFilters, [{ role: 'doctor', clinics: { $in: ['clinic-db'] } }]);
  assert.deepEqual(response.body, {
    doctors: 3,
    patients: 2,
    appointments: 7,
    clinics: [{ _id: 'clinic-db', name: 'Owned clinic' }],
  });
});

test('GET /stats/overview returns zeroed admin stats when no clinics are assigned', async () => {
  let aggregateCalls = 0;

  const User = {
    findById(id) {
      assert.equal(id, 'admin-1');
      return selectQuery({ _id: id, clinics: [] });
    },
    countDocuments() {
      aggregateCalls += 1;
      return Promise.resolve(99);
    },
  };

  const Appointment = {
    distinct() {
      aggregateCalls += 1;
      return Promise.resolve(['patient-1']);
    },
    countDocuments() {
      aggregateCalls += 1;
      return Promise.resolve(5);
    },
  };

  const Clinic = {
    find(query) {
      assert.deepEqual(query, { admin: 'admin-1' });
      return selectQuery([]);
    },
  };

  const router = loadFreshModuleWithMocks('routes/stats.js', {
    'models/User.js': User,
    'models/Appointment.js': Appointment,
    'models/Clinic.js': Clinic,
  });

  const response = await requestJson(buildJsonApp('/stats', router), {
    method: 'GET',
    requestPath: '/stats/overview',
    token: signTestToken({ id: 'admin-1', role: 'admin' }),
  });

  assert.equal(response.status, 200);
  assert.equal(aggregateCalls, 0);
  assert.deepEqual(response.body, {
    doctors: 0,
    patients: 0,
    appointments: 0,
    clinics: [],
  });
});
