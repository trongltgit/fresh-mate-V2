// FreshMate proxy — Cloudflare Worker.
// The Groq key is stored as a Worker secret and NEVER ships inside the app.
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

// Only these models may be used through the proxy
const ALLOWED_MODELS = new Set(["qwen/qwen3.8-27b", "openai/gpt-oss-20b"]);
const MAX_BODY_BYTES = 6 * 1024 * 1024;   // photos are ~200-600 KB after the app shrinks them
const MAX_TOKENS_CAP = 1500;

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json" } });

export default {
  async fetch(request, env) {
    if (request.method !== "POST") return json({ error: "POST only" }, 405);

    // 1) app token
    if (request.headers.get("X-App-Token") !== env.APP_TOKEN)
      return json({ error: "unauthorized" }, 401);

    // 2) optional rate limit (per client IP) if you add the binding, see README
    if (env.RATE_LIMITER) {
      const ip = request.headers.get("CF-Connecting-IP") || "unknown";
      const { success } = await env.RATE_LIMITER.limit({ key: ip });
      if (!success) return json({ error: "too many requests" }, 429);
    }

    // 3) size + shape checks
    const text = await request.text();
    if (text.length > MAX_BODY_BYTES) return json({ error: "too large" }, 413);
    let body;
    try { body = JSON.parse(text); } catch { return json({ error: "bad json" }, 400); }
    if (!ALLOWED_MODELS.has(body.model)) return json({ error: "model not allowed" }, 400);
    body.max_tokens = Math.min(body.max_tokens || 800, MAX_TOKENS_CAP);
    body.stream = false;

    // 4) forward to Groq with the secret key
    const upstream = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + env.GROQ_API_KEY,
      },
      body: JSON.stringify(body),
    });
    return new Response(upstream.body, {
      status: upstream.status,
      headers: { "Content-Type": "application/json" },
    });
  },
};
