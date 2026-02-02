const jwt = require('jsonwebtoken');

const rolePriority = {
  patient: 0,
  doctor: 1,
  admin: 2,
  support_manager: 2,
  superadmin: 3,
};

/**
 * Проверяет JWT токен и (опционально) роль пользователя.
 * @param {Array<string>} allowedRoles - список ролей, которым разрешен доступ.
 */
function auth(allowedRoles = []) {
  return (req, res, next) => {
    try {
      const header = req.headers.authorization || '';
      const token = header.startsWith('Bearer ') ? header.slice(7) : null;

      if (!token) {
        return res.status(401).json({ message: 'Токен не найден. Авторизуйтесь.' });
      }

      const payload = jwt.verify(token, process.env.JWT_SECRET);
      req.user = payload;

      if (allowedRoles.length > 0) {
        const hasAccess = allowedRoles.some((role) => {
          if (role.includes('+')) {
            // allow admin+ syntax
            const [baseRole] = role.split('+');
            return rolePriority[payload.role] >= rolePriority[baseRole];
          }
          return payload.role === role;
        });

        if (!hasAccess) {
          return res.status(403).json({ message: 'Недостаточно прав для выполнения действия.' });
        }
      }

      next();
    } catch (error) {
      console.error('Ошибка авторизации:', error.message);
      res.status(401).json({ message: 'Недействительный токен.' });
    }
  };
}

module.exports = auth;
