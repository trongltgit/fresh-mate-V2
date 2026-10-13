// FreshMate proxy for Render. No dependencies.
// The Groq key is an environment variable on Render, never inside the app.
const http = require("http");

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
// Thay vì chặn cứng, bạn có thể cho phép check linh hoạt hoặc bổ sung model bạn dùng vào đây
const ALLOWED_MODELS = new Set([
  "qwen/qwen3.8-27b", 
  "openai/gpt-oss-20b",
  "llama-3.3-70b-versatile", // Thêm model hay dùng
  "llama3-70b-8192"
]);
const MAX_BODY = 6 * 1024 * 1024;
const MAX_TOKENS_CAP = 1500;

function send(res, status, obj) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(obj));
}

http.createServer((req, res) => {
  // Health check / wake-up (open the URL in a browser to test)
  if (req.method === "GET") return send(res, 200, { ok: true, service: "FreshMate proxy" });
  if (req.method !== "POST") return send(res, 405, { error: "POST only" });

  // Kiểm tra APP_TOKEN (Nếu app iOS có gửi header x-app-token)
  if (process.env.APP_TOKEN && req.headers["x-app-token"] !== process.env.APP_TOKEN)
    return send(res, 401, { error: "token mismatch" });

  let size = 0;
  const chunks = [];
  req.on("data", (c) => {
    size += c.length;
    if (size > MAX_BODY) { send(res, 413, { error: "too large" }); req.destroy(); return; }
    chunks.push(c);
  });
  req.on("end", async () => {
    if (size > MAX_BODY) return;
    let body;
    try { body = JSON.parse(Buffer.concat(chunks).toString("utf8")); }
    catch { return send(res, 400, { error: "bad json" }); }

    // Nếu muốn thoáng hơn, có thể bỏ qua check ALLOWED_MODELS hoặc cho phép tất cả bằng cách bỏ dòng dưới:
    // if (!ALLOWED_MODELS.has(body.model)) return send(res, 400, { error: "model not allowed: " + body.model });

    if (!process.env.GROQ_API_KEY) return send(res, 500, { error: "GROQ_API_KEY env var not set on Render" });
    
    // Đảm bảo body có model mặc định nếu phía client không truyền lên
    if (!body.model) {
      body.model = "llama-3.3-70b-versatile";
    }

    body.max_tokens = Math.min(body.max_tokens || 800, MAX_TOKENS_CAP);
    body.stream = false;

    try {
      const up = await fetch(GROQ_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + process.env.GROQ_API_KEY,
        },
        body: JSON.stringify(body),
      });
      const text = await up.text();
      if (!up.ok) console.log("Groq error", up.status, text.slice(0, 300));
      res.writeHead(up.status, { "Content-Type": "application/json" });
      res.end(text);
    } catch (e) {
      console.log("fetch failed", e && e.message);
      send(res, 502, { error: "upstream failed: " + (e && e.message) });
    }
  });
}).listen(process.env.PORT || 3000, () => console.log("FreshMate proxy running"));