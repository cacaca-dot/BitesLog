const test = require('node:test');
const assert = require('node:assert/strict');

const { success, error } = require('../src/utils/response');

test('success helper returns standard payload', () => {
  const res = {
    statusCode: 200,
    payload: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.payload = payload;
      return this;
    },
  };

  success(res, 201, 'Created', { ok: true });

  assert.equal(res.statusCode, 201);
  assert.deepEqual(res.payload, {
    status: 'success',
    message: 'Created',
    data: { ok: true },
  });
});

test('error helper returns standard error payload', () => {
  const res = {
    statusCode: 200,
    payload: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.payload = payload;
      return this;
    },
  };

  error(res, 401, 'INVALID_CREDENTIALS', 'Wrong password');

  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.payload, {
    status: 'error',
    error: { code: 'INVALID_CREDENTIALS', message: 'Wrong password' },
  });
});
