// @ts-nocheck
// supabase/functions/ai-food-scan/index.ts

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Main model for AI Food Scan.
// If this model is unavailable for your Gemini key, change it to:
// const GEMINI_MODEL = "gemini-3.6-flash";
const GEMINI_MODEL = "gemini-3.5-flash-lite";

type Ingredient = {
  name: string;
  calories_kcal: number;
};

type FoodScanResult = {
  food_name: string;
  calories_kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  ingredients: Ingredient[];
};

function extractJson(text: string): string {
  const trimmed = text.trim();

  if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
    return trimmed;
  }

  const jsonBlockMatch = trimmed.match(/```json\s*([\s\S]*?)\s*```/i);
  if (jsonBlockMatch) {
    return jsonBlockMatch[1].trim();
  }

  const codeBlockMatch = trimmed.match(/```\s*([\s\S]*?)\s*```/i);
  if (codeBlockMatch) {
    return codeBlockMatch[1].trim();
  }

  const objectMatch = trimmed.match(/\{[\s\S]*\}/);
  if (!objectMatch) {
    throw new Error("Gemini response did not contain JSON.");
  }

  return objectMatch[0];
}

function toInt(value: unknown): number {
  const numberValue = Number(value);

  if (!Number.isFinite(numberValue)) {
    return 0;
  }

  return Math.max(0, Math.round(numberValue));
}

function toStringValue(value: unknown, fallback: string): string {
  if (value === null || value === undefined) {
    return fallback;
  }

  const text = String(value).trim();

  if (text.length === 0) {
    return fallback;
  }

  return text;
}

function normalizeResult(value: any): FoodScanResult {
  const ingredients = Array.isArray(value?.ingredients)
    ? value.ingredients.map((item: any) => {
        return {
          name: toStringValue(item?.name, "Ingredient"),
          calories_kcal: toInt(item?.calories_kcal),
        };
      })
    : [];

  return {
    food_name: toStringValue(value?.food_name, "Unknown Food"),
    calories_kcal: toInt(value?.calories_kcal),
    protein_g: toInt(value?.protein_g),
    carbs_g: toInt(value?.carbs_g),
    fat_g: toInt(value?.fat_g),
    ingredients,
  };
}

function buildPrompt(correction: string, previousResult: unknown): string {
  const correctionSection =
    correction.length > 0
      ? `

IMPORTANT — USER CORRECTION MODE:
The user has reviewed the previous analysis and provided a correction.
You MUST re-analyze the image using the user's correction as the primary source of truth.

Previous result JSON:
${JSON.stringify(previousResult ?? {})}

User correction:
${correction}

When applying the correction:
- Recalculate ALL nutrition values (calories, protein, carbs, fat) together so they are internally consistent.
- If the user says the portion is different, scale ALL values proportionally.
- If the user identifies a different food, replace the food_name and recalculate everything from scratch.
- If the user corrects specific ingredients, update the ingredients list and recalculate totals so the sum of ingredient calories matches the total calories_kcal.
- Do NOT keep old values that contradict the correction. Every field must reflect the corrected analysis.
- The relationship calories ≈ protein_g*4 + carbs_g*4 + fat_g*9 should approximately hold.
`
      : "";

  return `
You are an AI food nutrition scanner for a fitness mobile app.

Analyze the food image and estimate the visible meal's nutrition.

Return JSON only.
Do not return markdown.
Do not return explanations.
Do not include any text outside the JSON object.

Rules:
- Estimate nutrition for the whole visible food portion.
- Use integers only.
- If the image is unclear, still make a reasonable estimate.
- If the image does not contain food, return "Unknown Food" with 0 nutrition values.
- Ingredients should include visible main ingredients only.
- The sum of ingredient calories should approximately match the total calories_kcal.
- The relationship calories ≈ protein_g*4 + carbs_g*4 + fat_g*9 should approximately hold.
- If user correction is provided, use it to fix the previous result. The correction takes priority over your initial assessment.
- Do not return null values.

Required JSON shape:
{
  "food_name": "string",
  "calories_kcal": 0,
  "protein_g": 0,
  "carbs_g": 0,
  "fat_g": 0,
  "ingredients": [
    {
      "name": "string",
      "calories_kcal": 0
    }
  ]
}
${correctionSection}
`;
}

async function callGemini(params: {
  apiKey: string;
  imageBase64: string;
  mimeType: string;
  correction: string;
  previousResult: unknown;
}): Promise<FoodScanResult> {
  const prompt = buildPrompt(params.correction, params.previousResult);

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${params.apiKey}`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      generationConfig: {
        responseMimeType: "application/json",
        maxOutputTokens: 800,
      },
      contents: [
        {
          role: "user",
          parts: [
            {
              text: prompt,
            },
            {
              inline_data: {
                mime_type: params.mimeType,
                data: params.imageBase64,
              },
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini request failed: ${errorText}`);
  }

  const result = await response.json();

  const content = result?.candidates?.[0]?.content?.parts
    ?.map((part: any) => part?.text ?? "")
    .join("")
    .trim();

  if (!content || typeof content !== "string") {
    throw new Error("Missing Gemini content.");
  }

  const jsonText = extractJson(content);
  const parsed = JSON.parse(jsonText);

  return normalizeResult(parsed);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({
        error: "Method not allowed.",
      }),
      {
        status: 405,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) {
      throw new Error("Missing GEMINI_API_KEY secret.");
    }

    const body = await req.json();

    const imageBase64 = body?.imageBase64;
    const mimeType = body?.mimeType ?? "image/jpeg";
    const correction =
      typeof body?.correction === "string" ? body.correction.trim() : "";
    const previousResult = body?.previousResult ?? null;

    if (!imageBase64 || typeof imageBase64 !== "string") {
      throw new Error("Missing imageBase64.");
    }

    const scanResult = await callGemini({
      apiKey,
      imageBase64,
      mimeType,
      correction,
      previousResult,
    });

    return new Response(JSON.stringify(scanResult), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});