const crypto = require("crypto");

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const GROQ_TEXT_MODEL = "openai/gpt-oss-120b";

const DEFAULT_MAX_TOKENS = 2048;

function isSchemaRejection(status, body) {
  if (status !== 400 && status !== 404 && status !== 422) return false;
  return /response_format|json_schema|schema/i.test(String(body || ""));
}

async function callGroqStructured(apiKey, prompt, schemaName, schema, options) {
  const opts = options || {};
  const response = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: GROQ_TEXT_MODEL,
      messages: [{role: "user", content: prompt}],
      temperature: typeof opts.temperature === "number" ? opts.temperature : 0.1,
      max_tokens: Number(opts.maxTokens) > 0 ?
        Number(opts.maxTokens) : DEFAULT_MAX_TOKENS,
      reasoning_effort: "low",
      reasoning_format: "hidden",
      response_format: {
        type: "json_schema",
        json_schema: {name: schemaName, strict: true, schema},
      },
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    const err = new Error(
        `Groq API error: ${response.status} - ${String(body).slice(0, 400)}`);
    err.groqStatus = response.status;
    err.schemaUnsupported = isSchemaRejection(response.status, body);
    throw err;
  }

  const data = await response.json();
  const message = data && Array.isArray(data.choices) && data.choices[0] ?
    data.choices[0].message : null;
  if (message && typeof message.refusal === "string" && message.refusal) {
    const err = new Error(
        `Groq refused the request: ${message.refusal.slice(0, 200)}`);
    err.groqRefusal = true;
    throw err;
  }
  const content = message && typeof message.content === "string" ?
    message.content : null;
  if (!content) throw new Error("Groq API returned no message content");

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (e) {
    const err = new Error(
        `Groq returned non-JSON under json_schema: ${content.slice(0, 200)}`);
    err.schemaUnsupported = true;
    throw err;
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    const err = new Error("Groq returned a non-object under json_schema");
    err.schemaUnsupported = true;
    throw err;
  }
  return parsed;
}

async function callGroqJson(apiKey, spec) {
  try {
    const value = await callGroqStructured(
        apiKey, spec.prompt, spec.schemaName, spec.schema, spec);
    return {value, mode: "json_schema"};
  } catch (e) {
    const canFallBack = e && e.schemaUnsupported === true &&
        typeof spec.plainCall === "function";
    if (!canFallBack) throw e;
    console.error("⚠️ groqJson: provider would not honour json_schema for " +
        `"${spec.schemaName}" — falling back to prose JSON: ${e.message}`);
  }

  const raw = await spec.plainCall(apiKey, spec.plainPrompt || spec.prompt);
  const value = typeof spec.plainExtract === "function" ?
    spec.plainExtract(raw) : null;
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(
        `groqJson: unparseable prose fallback for ${spec.schemaName}`);
  }
  return {value, mode: "prose_fallback"};
}

function asDelimitedData(label, text) {
  const nonce = crypto.randomBytes(8).toString("hex");
  const marker = `${label}_${nonce}`;
  const body = text === null || text === undefined ? "" : String(text);
  return {
    marker,
    block: `<<<BEGIN ${marker}>>>\n${body}\n<<<END ${marker}>>>`,
  };
}

module.exports = {
  callGroqJson,
  callGroqStructured,
  asDelimitedData,
  isSchemaRejection,
  GROQ_TEXT_MODEL,
};
