export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }
    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }
    if (!env.OPENAI_API_KEY) {
      return json({ error: "missing_openai_key" }, 500);
    }

    const body = await request.json().catch(() => null);
    if (!body || !body.input || !body.merchantId) {
      return json({ error: "invalid_request" }, 400);
    }

    const prompt = buildPrompt(body);
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: env.OPENAI_MODEL || "gpt-4.1-mini",
        input: [
          {
            role: "system",
            content:
              "Du bist ein Assistent fuer lokale Haendler. Antworte nur als kompaktes JSON ohne Markdown.",
          },
          { role: "user", content: prompt },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "feed_suggestion",
            schema: {
              type: "object",
              additionalProperties: false,
              properties: {
                type: { type: "string" },
                title: { type: "string" },
                subtitle: { type: "string" },
                description: { type: "string" },
                ctaLabel: { type: "string" },
                reason: { type: "string" },
              },
              required: ["type", "title", "subtitle", "description", "ctaLabel", "reason"],
            },
          },
        },
      }),
    });

    if (!response.ok) {
      return json({ error: "openai_failed" }, 502);
    }
    const data = await response.json();
    const text = data.output_text || "{}";
    const suggestion = JSON.parse(text);
    return json({ suggestion });
  },
};

function buildPrompt(body) {
  return JSON.stringify({
    task:
      "Erzeuge einen fertigen lokalen Feed-Beitrag auf Deutsch. Kurz, freundlich, verstaendlich fuer normale Haendler. Kein Marketing-Blabla.",
    selectedType: body.type,
    merchantInput: body.input,
    merchant: body.merchant || {},
    categories: body.categories || [],
    items: body.items || [],
    allowedTypes: ["offer", "news", "newProduct", "happyHour", "quickSell", "info"],
    rules: {
      title: "max 55 Zeichen",
      subtitle: "max 80 Zeichen",
      description: "2 bis 4 kurze Saetze",
      ctaLabel: "max 24 Zeichen oder leer",
    },
  });
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders(),
      "Content-Type": "application/json",
    },
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}
