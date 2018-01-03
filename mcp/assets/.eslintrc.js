module.exports = {
  "extends": "airbnb-base",
  "env": {
    "node": true,
    "jquery": true,
    "browser": true,
    "es6": true
  },
  "globals": {
    "prettyMs": true
  },
  "rules": {
    "no-unused-vars": ["error", {
      "args": "none"
    }]
  }
};