const http = require('node:http');
const path = require('node:path');
const express = require('express');
const jwt = require('jsonwebtoken');

function backendPath(relativePath) {
  return path.join(__dirname, '..', relativePath);
}

function selectQuery(result) {
  return {
    select: async () => result,
  };
}

function loadFreshModuleWithMocks(relativeModulePath, mockMap) {
  const touchedModules = new Map();

  for (const [relativePath, mockExports] of Object.entries(mockMap)) {
    const absolutePath = backendPath(relativePath);
    touchedModules.set(absolutePath, require.cache[absolutePath]);
    require.cache[absolutePath] = {
      id: absolutePath,
      filename: absolutePath,
      loaded: true,
      exports: mockExports,
    };
  }

  const modulePath = backendPath(relativeModulePath);
  touchedModules.set(modulePath, require.cache[modulePath]);
  delete require.cache[modulePath];

  try {
    return require(modulePath);
  } finally {
    for (const [absolutePath, cachedModule] of touchedModules.entries()) {
      if (cachedModule) {
        require.cache[absolutePath] = cachedModule;
      } else {
        delete require.cache[absolutePath];
      }
    }
  }
}

function buildJsonApp(mountPath, router) {
  const app = express();
  app.use(express.json());
  app.use(mountPath, router);
  return app;
}

async function requestJson(app, { method = 'GET', requestPath = '/', token, body } = {}) {
  const server = http.createServer(app);

  await new Promise((resolve) => {
    server.listen(0, '127.0.0.1', resolve);
  });

  try {
    const { port } = server.address();
    const response = await fetch(`http://127.0.0.1:${port}${requestPath}`, {
      method,
      headers: {
        ...(token ? { authorization: `Bearer ${token}` } : {}),
        ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });

    const text = await response.text();
    let parsedBody = null;
    if (text) {
      try {
        parsedBody = JSON.parse(text);
      } catch (_) {
        parsedBody = text;
      }
    }

    return {
      status: response.status,
      body: parsedBody,
    };
  } finally {
    await new Promise((resolve) => {
      server.close(resolve);
    });
  }
}

function signTestToken(payload) {
  process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret';
  return jwt.sign(payload, process.env.JWT_SECRET);
}

module.exports = {
  buildJsonApp,
  loadFreshModuleWithMocks,
  requestJson,
  selectQuery,
  signTestToken,
};
