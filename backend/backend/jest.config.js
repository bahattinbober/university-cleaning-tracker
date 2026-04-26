/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  testTimeout: 10000,
  verbose: true,
  setupFiles: ['./tests/setup.js'],
};
