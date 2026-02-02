const jwt = require('jsonwebtoken');

function signToken(user) {
  return jwt.sign(
    {
      id: user._id,
      role: user.role,
      email: user.email,
      fullName: `${user.firstName || ''} ${user.lastName || ''}`.trim(),
    },
    process.env.JWT_SECRET,
    { expiresIn: '7d' },
  );
}

module.exports = { signToken };
