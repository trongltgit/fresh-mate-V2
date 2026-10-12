# FreshMate proxy (keeps your Groq key off the phone)

Needs Node.js and a free Cloudflare account.

```bash
cd worker
npx wrangler login
npx wrangler secret put GROQ_API_KEY     # paste your gsk_... key (stored on Cloudflare only)
npx wrangler secret put APP_TOKEN        # make up a long random string, e.g. 40+ characters
npx wrangler deploy
```

Wrangler prints your URL, like `https://freshmate-proxy.yourname.workers.dev`.

Then edit `src/proxy_config.h`:

```c
#define FRESHMATE_PROXY_URL  "https://freshmate-proxy.yourname.workers.dev"
#define FRESHMATE_APP_TOKEN  "the same APP_TOKEN string"
```

Rebuild the app. The 🔑 button disappears and nobody needs a Groq key.

## Limit abuse (recommended)
The APP_TOKEN is inside the APK, so a determined person could extract it.
It stops casual misuse, but you should also cap usage:
- Cloudflare dashboard → your domain/Worker → Security → add a **rate limiting rule**, or add a Workers rate-limit binding named `RATE_LIMITER` (worker.js already uses it when present).
- Set a spending/usage limit on your Groq account.
- If the token leaks: run `npx wrangler secret put APP_TOKEN` with a new value and ship a new app version.
