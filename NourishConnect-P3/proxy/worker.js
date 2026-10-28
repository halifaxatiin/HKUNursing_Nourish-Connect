// Nourish & Connect chat proxy (Cloudflare Worker).
//
// Why it exists: the OpenRouter API key must never be inside the iPhone app. The app calls this
// proxy; the proxy holds the key, adds the safety instructions, limits use, and calls OpenRouter,
// which routes to a DeepSeek model. DeepSeek is used for text only.
//
// Secrets (set with `wrangler secret put`): OPENROUTER_API_KEY, APP_TOKEN
// Optional variables: MODEL, DATA_COLLECTION ("deny" by default), REQUIRE_ZDR ("true"),
//   DAILY_LIMIT (messages per phone per day), GLOBAL_DAILY_LIMIT, APP_URL
// Optional KV binding: LIMITS (needed for the daily limits to work)

export const SYSTEM_PROMPT = [
  "你係「健康伴你行」手機應用程式入面嘅陪伴助手，同一位香港長者用廣東話傾偈。",
  "規則：",
  "1. 用繁體中文書寫嘅廣東話口語。句子要短，每次最多三句。唔好用英文、表情符號或者markdown。",
  "2. 你係電腦程式，唔係真人、醫生、護士或者危機熱線。唔可以扮係人，亦唔可以話自己係醫護人員。",
  "3. 耐心聆聽，同理對方嘅感受。可以建議做呼吸練習、同家人朋友傾偈、喺屋企附近慢慢行幾步（量力而為）。",
  "4. 唔可以講藥物、劑量、胰島素、診斷、預測血糖或者病情。遇到呢類問題，請對方問醫生或者護士。",
  "5. 唔好提供任何電話號碼或者網址。如果對方好唔開心或者有危險，叫佢按畫面上嘅「求助」掣搵人幫手。",
  "6. 講食物嘅時候，只可以話糖或者鈉偏高嘅時候可以食少啲、揀細份啲。唔好叫人戒口，亦唔好叫人改變用藥。"
].join("\n");

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const DEFAULT_MODEL = "~deepseek/deepseek-flash-latest";
const DEFAULT_DAILY_LIMIT = 40;
const DEFAULT_GLOBAL_DAILY_LIMIT = 2000;
const MAX_BODY_CHARS = 8000;

const MAX_MESSAGES = 12;
const MAX_MESSAGE_CHARS = 500;
const MAX_CONTEXT_LINES = 5;
const MAX_CONTEXT_CHARS = 80;

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" }
  });
}

/** Checks the request body from the app. Returns { ok, value } or { ok: false, error }. */
export function validate(body) {
  if (!body || typeof body !== "object") return { ok: false, error: "bad_body" };

  const { messages, context, installId } = body;

  if (typeof installId !== "string" || !/^[A-Za-z0-9-]{8,64}$/.test(installId)) {
    return { ok: false, error: "bad_install_id" };
  }
  if (!Array.isArray(messages) || messages.length < 1 || messages.length > MAX_MESSAGES) {
    return { ok: false, error: "bad_messages" };
  }
  const cleanMessages = [];
  for (const m of messages) {
    if (!m || (m.role !== "user" && m.role !== "assistant")) {
      return { ok: false, error: "bad_role" };
    }
    if (typeof m.content !== "string") return { ok: false, error: "bad_content" };
    const content = m.content.trim();
    if (content.length < 1 || content.length > MAX_MESSAGE_CHARS) {
      return { ok: false, error: "bad_content_length" };
    }
    cleanMessages.push({ role: m.role, content });
  }
  if (cleanMessages[cleanMessages.length - 1].role !== "user") {
    return { ok: false, error: "last_must_be_user" };
  }

  let cleanContext = [];
  if (context !== undefined) {
    if (!Array.isArray(context) || context.length > MAX_CONTEXT_LINES) {
      return { ok: false, error: "bad_context" };
    }
    for (const line of context) {
      if (typeof line !== "string" || line.length > MAX_CONTEXT_CHARS) {
        return { ok: false, error: "bad_context" };
      }
      cleanContext.push(line.replace(/[\r\n]+/g, " ").trim());
    }
  }

  return { ok: true, value: { messages: cleanMessages, context: cleanContext, installId } };
}

/** The safety instructions come only from here, never from the app. */
export function buildMessages(value) {
  let system = SYSTEM_PROMPT;
  if (value.context.length > 0) {
    system +=
      "\n\n以下係手機提供嘅今日記錄，只供參考，唔好逐句重複：\n" +
      value.context.map((l) => `- ${l}`).join("\n");
  }
  return [{ role: "system", content: system }, ...value.messages];
}

export function buildUpstreamBody(value, env) {
  const provider = {
    // "deny" only uses providers that do not collect user data. If no DeepSeek provider
    // qualifies, OpenRouter returns an error; set DATA_COLLECTION=allow for demos on fictional data.
    data_collection: env.DATA_COLLECTION === "allow" ? "allow" : "deny"
  };
  if (env.REQUIRE_ZDR === "true") provider.zdr = true;

  return {
    model: env.MODEL || DEFAULT_MODEL,
    messages: buildMessages(value),
    max_tokens: 200,
    temperature: 0.5,
    provider
  };
}

async function underLimits(env, installId, now) {
  if (!env.LIMITS) return true; // no KV bound: limits are off
  const day = now.toISOString().slice(0, 10);
  const perKey = `d:${installId}:${day}`;
  const globalKey = `g:${day}`;
  const perLimit = Number(env.DAILY_LIMIT) || DEFAULT_DAILY_LIMIT;
  const globalLimit = Number(env.GLOBAL_DAILY_LIMIT) || DEFAULT_GLOBAL_DAILY_LIMIT;

  const [per, glob] = await Promise.all([env.LIMITS.get(perKey), env.LIMITS.get(globalKey)]);
  const perCount = Number(per || 0);
  const globalCount = Number(glob || 0);
  if (perCount >= perLimit || globalCount >= globalLimit) return false;

  const opts = { expirationTtl: 172800 };
  await Promise.all([
    env.LIMITS.put(perKey, String(perCount + 1), opts),
    env.LIMITS.put(globalKey, String(globalCount + 1), opts)
  ]);
  return true;
}

export async function handleRequest(request, env, fetchImpl = fetch, now = new Date()) {
  const url = new URL(request.url);
  if (request.method !== "POST" || url.pathname !== "/chat") {
    return json(404, { error: "not_found" });
  }
  if (!env.OPENROUTER_API_KEY || !env.APP_TOKEN) {
    return json(500, { error: "not_configured" });
  }
  if (request.headers.get("X-App-Token") !== env.APP_TOKEN) {
    return json(401, { error: "unauthorized" });
  }

  const text = await request.text();
  if (text.length > MAX_BODY_CHARS) return json(413, { error: "too_large" });

  let body;
  try {
    body = JSON.parse(text);
  } catch {
    return json(400, { error: "bad_json" });
  }
  const checked = validate(body);
  if (!checked.ok) return json(400, { error: checked.error });

  if (!(await underLimits(env, checked.value.installId, now))) {
    return json(429, { error: "limit" });
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const headers = {
      Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
      "X-Title": "Nourish and Connect"
    };
    if (env.APP_URL) headers["HTTP-Referer"] = env.APP_URL;

    const upstream = await fetchImpl(OPENROUTER_URL, {
      method: "POST",
      headers,
      body: JSON.stringify(buildUpstreamBody(checked.value, env)),
      signal: controller.signal
    });
    if (!upstream.ok) return json(502, { error: "upstream" });

    const data = await upstream.json();
    const choice = data && data.choices && data.choices[0];
    const content = choice && choice.message && choice.message.content;
    if (!choice || choice.error || typeof content !== "string" || content.trim() === "") {
      return json(502, { error: "upstream" });
    }
    return json(200, { reply: content.trim() });
  } catch {
    return json(502, { error: "upstream" });
  } finally {
    clearTimeout(timer);
  }
}

export default {
  fetch(request, env) {
    return handleRequest(request, env);
  }
};
