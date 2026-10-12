#pragma once
// ─────────────────────────────────────────────────────────────────────────────
// Secure mode: the Groq key lives ONLY on your server (Cloudflare Worker).
// Put your Worker URL and the app token here (see worker/README.md).
// Leave FRESHMATE_PROXY_URL empty to use the old "type your own key" mode.
// ─────────────────────────────────────────────────────────────────────────────
#define FRESHMATE_PROXY_URL   ""   // Cloudflare: "https://freshmate-proxy.xxx.workers.dev"  Vercel: "https://xxx.vercel.app/api/ai"  Render: "https://xxx.onrender.com/ai"
#define FRESHMATE_APP_TOKEN   ""   // same value as the APP_TOKEN secret in the Worker
