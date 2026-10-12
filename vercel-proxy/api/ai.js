// FreshMate proxy for Vercel. The Groq key is an environment variable on Vercel,
// it is NOT inside the app.
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const ALLOWED_MODELS = new Set(["qwen/qwen3.8-27b", "openai/gpt-oss-20b"]);
const MAX_TOKENS_CAP = 1500;

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });

  if (!process.env.APP_TOKEN || req.headers["x-app-token"] !== process.env.APP_TOKEN)
    return res.status(401).json({ error: "unauthorized" });

  const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body;
  if (!body || !ALLOWED_MODELS.has(body.model))
    return res.status(400).json({ error: "model not allowed" });

  body.max_tokens = Math.min(body.max_tokens || 800, MAX_TOKENS_CAP);
  body.stream = false;

  try {
    const upstream = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer " + process.env.GROQ_API_KEY,
      },
      body: JSON.stringify(body),
    });
    const text = await upstream.text();
    res.status(upstream.status).setHeader("Content-Type", "application/json").send(text);
  } catch (e) {
    res.status(502).json({ error: "upstream failed" });
  }
}
