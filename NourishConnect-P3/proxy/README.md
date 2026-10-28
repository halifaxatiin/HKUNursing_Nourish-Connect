# Chat proxy (OpenRouter, DeepSeek)

The iPhone app never holds the OpenRouter key. It calls this small Cloudflare Worker, which holds the key, adds the safety instructions, limits use, and calls OpenRouter. OpenRouter routes the request to a DeepSeek model. DeepSeek reads text only, so no photos or audio ever go through here.

```
iPhone app  --(text + today's counts)-->  Worker  --(adds key + safety prompt)-->  OpenRouter  -->  DeepSeek
```

## What the app sends

Up to 8 recent chat turns (each cut to 400 characters), up to 5 short lines such as "今日心情記錄：有啲寂寞", and a random install id for per-phone limits. No name, no phone number, no product names, no photos. Distress messages and medication questions are handled on the phone and are never sent.

## Set it up (about 15 minutes)

1. Make an OpenRouter account at openrouter.ai, add a small amount of credit, and create an API key. **Set a credit limit on that key.** It is the final cap on spending if anything goes wrong.
2. Make a free Cloudflare account.
3. In this folder: `npm install -g wrangler` (or use `npx wrangler`), then `wrangler login`.
4. Set the two secrets (they are stored by Cloudflare, not in any file):
   ```
   wrangler secret put OPENROUTER_API_KEY
   wrangler secret put APP_TOKEN        # any long random string you invent
   ```
5. For daily limits, create a KV namespace, then paste its id into `wrangler.toml` and remove the `#` marks:
   ```
   wrangler kv namespace create LIMITS
   ```
6. `wrangler deploy`. It prints an address like `https://nourish-proxy.your-name.workers.dev`.
7. In the app, open `Resources/Config.swift` and set `chatEndpoint` to that address plus `/chat`, and `appToken` to the same string you used for `APP_TOKEN`. Rebuild.

Check it works from a terminal (replace the address, token and id):

```
curl -s https://nourish-proxy.your-name.workers.dev/chat \
  -H "Content-Type: application/json" -H "X-App-Token: YOUR_APP_TOKEN" \
  -d '{"installId":"11111111-2222-3333-4444-555555555555","messages":[{"role":"user","content":"你好"}]}'
```

You should get `{"reply":"..."}`.

## Choices you should know about

- **Model.** `wrangler.toml` uses `~deepseek/deepseek-flash-latest`, an OpenRouter alias that moves to newer DeepSeek versions over time. That can change replies and price without notice. Before any evaluation, look up the current model on openrouter.ai, copy its exact id into `MODEL`, and re-run the 20 safety prompts in the main README.
- **Privacy setting.** The proxy sends `provider: {data_collection: "deny"}`, so OpenRouter only uses providers that do not collect user data. If no DeepSeek provider qualifies, requests fail with an error. For a demo on fictional data you can set `DATA_COLLECTION = "allow"`. `REQUIRE_ZDR = "true"` goes further (zero data retention) and narrows the choice of providers more.
- **The app token is not a secret.** It sits inside the app. It only turns away casual traffic. The real protections are the key staying here, the per-phone and global daily limits, and the credit limit on the OpenRouter key.
- **Where the data goes.** Chat text passes through Cloudflare, OpenRouter and a DeepSeek provider. Check where each processes data and review it against Hong Kong's Personal Data (Privacy) Ordinance before any real user data is used. The demo should use fictional data.

## Tests

`npm test` (Node 18 or later). They check: the app cannot send a system message, limits work, the key never appears in an error, the safety prompt and privacy setting are always sent, and bad requests never reach OpenRouter.
