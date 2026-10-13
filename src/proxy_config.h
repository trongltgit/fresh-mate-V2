#pragma once
// ─────────────────────────────────────────────────────────────────────────────
// Secure mode: the Groq key lives ONLY on your server (Cloudflare Worker).
// Put your Worker URL and the app token here (see worker/README.md).
// Leave FRESHMATE_PROXY_URL empty to use the old "type your own key" mode.
// ─────────────────────────────────────────────────────────────────────────────
#define FRESHMATE_PROXY_URL   "https://fresh-mate-v2.onrender.com/ai"
#define FRESHMATE_APP_TOKEN   ""