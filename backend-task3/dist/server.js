// src/server.ts
import { app } from './app.js';
const PORT = Number(process.env.PORT || 3000);
const DEFAULT_DELAY_MS = Number(process.env.SIM_DELAY_MS || 60_000);
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Task3 API listening on http://localhost:${PORT}`);
    console.log(`Delay per ID (ms): ${DEFAULT_DELAY_MS} (override with ?delayMs=1000&fixed=1)`);
});
