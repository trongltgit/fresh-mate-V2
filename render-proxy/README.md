# FreshMate proxy on Render
Files: server.js + package.json (upload to the ROOT of a GitHub repo).
Render settings: Build `npm install`, Start `node server.js`.
Environment variables on Render: GROQ_API_KEY, APP_TOKEN.
App URL: https://<name>.onrender.com/ai

## Checklist if the app shows an HTTP error
1. Open https://<n>.onrender.com/ in a browser -> must show {"ok":true,"service":"FreshMate proxy"} (first load can take ~60s).
2. Service type must be Web Service (not Static Site); Root Directory must contain server.js.
3. Env vars GROQ_API_KEY and APP_TOKEN set; APP_TOKEN equals FRESHMATE_APP_TOKEN in src/proxy_config.h.
4. Render dashboard -> Logs shows "FreshMate proxy running".
