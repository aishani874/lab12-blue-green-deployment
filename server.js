const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const APP_ENV = process.env.APP_ENV || 'blue';
const APP_VERSION = process.env.APP_VERSION || '1.0.0';

app.get('/', (req, res) => {
    res.status(200).json({
        status: 'UP',
        environment: APP_ENV,
        version: APP_VERSION,
        message: `Serving traffic from the ${APP_ENV.toUpperCase()} deployment environment. (Execution 2)`
    });
});

app.get('/health', (req, res) => {
    res.status(200).json({ status: 'HEALTHY' });
});

app.listen(PORT, () => {
    console.log(`Node application listening on port ${PORT} [Env: ${APP_ENV}]`);
});