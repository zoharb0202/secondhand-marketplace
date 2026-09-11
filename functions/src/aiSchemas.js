const TaxonomySource = Object.freeze({
  GENERATED: "generated",
  INJECTED: "injected",
  UNAVAILABLE: "unavailable",
});

let taxonomySource = TaxonomySource.UNAVAILABLE;
let taxonomyMeta = null;
let categoryIds = null;
let subcategoryIds = null;
let subcategoriesByCategory = null;
let conditionValues = null;

function adoptTaxonomy(raw, source) {
  if (!raw || typeof raw !== "object") return false;
  const cats = raw.categories;
  const conds = raw.conditions;
  if (!cats || typeof cats !== "object") return false;
  if (!Array.isArray(conds) || conds.length === 0) return false;

  const byCategory = new Map();
  const allCategories = new Set();
  const allSubcategories = new Set();
  for (const id of Object.keys(cats)) {
    if (typeof id !== "string" || !id) continue;
    const subs = Array.isArray(cats[id]) ? cats[id] : [];
    const set = new Set();
    for (const sub of subs) {
      if (typeof sub === "string" && sub) {
        set.add(sub);
        allSubcategories.add(sub);
      }
    }
    allCategories.add(id);
    byCategory.set(id, set);
  }
  if (allCategories.size === 0) return false;

  const condSet = new Set(conds.filter((c) => typeof c === "string" && c));
  if (condSet.size === 0) return false;

  categoryIds = allCategories;
  subcategoryIds = allSubcategories;
  subcategoriesByCategory = byCategory;
  conditionValues = condSet;
  taxonomySource = source;
  taxonomyMeta = {
    generatedFrom: typeof raw.generatedFrom === "string" ? raw.generatedFrom : null,
    generatedAt: typeof raw.generatedAt === "string" ? raw.generatedAt : null,
    sourceHash: typeof raw.sourceHash === "string" ? raw.sourceHash : null,
  };
  return true;
}

function loadGeneratedTaxonomy() {
  let raw = null;
  try {
    // eslint-disable-next-line global-require
    raw = require("./generated/taxonomy.json");
  } catch (e) {
    console.error(
        "🚨 [AI_SCHEMAS] functions/src/generated/taxonomy.json is missing — " +
        "category/subcategory/condition values will be PASSED THROUGH " +
        "UNVERIFIED. Run the taxonomy generator (see this module's wiring " +
        "notes) or call setTaxonomy() at startup.");
    return;
  }
  if (!adoptTaxonomy(raw, TaxonomySource.GENERATED)) {
    console.error(
        "🚨 [AI_SCHEMAS] generated/taxonomy.json is present but malformed — " +
        "taxonomy checks are DISABLED. Expected {categories:{id:[subIds]}, " +
        "conditions:[...]}.");
  }
}

loadGeneratedTaxonomy();

function setTaxonomy(raw) {
  return adoptTaxonomy(raw, TaxonomySource.INJECTED);
}

function taxonomyStatus() {
  return {
    ok: taxonomySource !== TaxonomySource.UNAVAILABLE,
    source: taxonomySource,
    categories: categoryIds ? categoryIds.size : 0,
    subcategories: subcategoryIds ? subcategoryIds.size : 0,
    conditions: conditionValues ? conditionValues.size : 0,
    meta: taxonomyMeta,
  };
}

function vocabulary(name) {
  switch (name) {
    case "category": return categoryIds;
    case "subcategory": return subcategoryIds;
    case "condition": return conditionValues;
    default: return null;
  }
}

const MODERATION_CATEGORIES =
    new Set(["explicit", "violence", "drugs", "hate", "illegal"]);

const CONFIDENCE_LEVELS = new Set(["high", "medium", "low"]);

const MAX_SAFE_ABS = 1e15;

const MAX_PRICE_ILS = 1e8;

const MAX_TITLE_LEN = 140;
const MAX_SHORT_TEXT_LEN = 300;
const MAX_DESCRIPTION_LEN = 2000;
const MAX_TOKEN_LEN = 60;
const MAX_BRAND_LEN = 40;
const MAX_CITY_LEN = 60;
const MAX_MODEL_LEN = 40;
const MAX_ID_LEN = 128;

function isSafeNumber(v) {
  return typeof v === "number" && Number.isFinite(v) && Math.abs(v) <= MAX_SAFE_ABS;
}

function coerceNumber(v) {
  if (typeof v !== "string") return null;
  const s = v.trim().replace(/,/g, "");
  if (!s) return null;
  const n = Number(s);
  return isSafeNumber(n) ? n : null;
}

function newContext(options) {
  const ctx = {
    errors: [],
    warnings: [],
    options: options || {},
    context: (options && options.context) || {},
    addError(path, code, extra) {
      ctx.errors.push({path, code, ...(extra || {})});
    },
    addWarning(path, code, extra) {
      ctx.warnings.push({path, code, ...(extra || {})});
    },
  };
  return ctx;
}

function validateString(path, spec, value, ctx) {
  if (typeof value !== "string") {
    ctx.addError(path, "wrong_type", {expected: "string"});
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    if (spec.requireNonEmpty || spec.required) {
      ctx.addError(path, "empty");
      return null;
    }
    return null;
  }
  const max = spec.maxLen || MAX_SHORT_TEXT_LEN;
  if (trimmed.length > max) {
    ctx.addWarning(path, "truncated");
    return trimmed.slice(0, max);
  }
  return trimmed;
}

function validateNumber(path, spec, value, ctx) {
  let n = null;
  if (typeof value === "number") {
    if (!isSafeNumber(value)) {
      ctx.addError(path, "not_finite");
      return null;
    }
    n = value;
  } else if (spec.coerce !== false) {
    n = coerceNumber(value);
    if (n === null) {
      ctx.addError(path, "wrong_type", {expected: "number"});
      return null;
    }
    ctx.addWarning(path, "coerced_number");
  } else {
    ctx.addError(path, "wrong_type", {expected: "number"});
    return null;
  }

  if (spec.min !== undefined && n < spec.min) {
    ctx.addError(path, "out_of_range", {expected: `>= ${spec.min}`});
    return null;
  }
  if (spec.max !== undefined && n > spec.max) {
    ctx.addError(path, "out_of_range", {expected: `<= ${spec.max}`});
    return null;
  }
  return n;
}

function validateBoolean(path, spec, value, ctx) {
  if (typeof value === "boolean") return value;
  if (value === "true" || value === "false") {
    ctx.addWarning(path, "coerced_boolean");
    return value === "true";
  }
  ctx.addError(path, "wrong_type", {expected: "boolean"});
  return null;
}

function validateEnum(path, spec, value, ctx) {
  if (typeof value !== "string") {
    ctx.addError(path, "wrong_type", {expected: "enum string"});
    return null;
  }
  const token = value.trim();
  if (!token) return null;

  const values = spec.values || vocabulary(spec.vocab);
  if (!values) {
    ctx.addWarning(path, "taxonomy_unverified");
    return token.length > MAX_TOKEN_LEN ? token.slice(0, MAX_TOKEN_LEN) : token;
  }
  if (values.has(token)) return token;

  const detail = {safe: true, got: token};
  if (spec.unknownIsWarning) {
    ctx.addWarning(path, "not_in_enum", detail);
    return token.length > MAX_TOKEN_LEN ? token.slice(0, MAX_TOKEN_LEN) : token;
  }
  ctx.addError(path, "not_in_enum", detail);
  return null;
}

function validateArray(path, spec, value, ctx) {
  if (!Array.isArray(value)) {
    ctx.addError(path, "wrong_type", {expected: "array"});
    return null;
  }
  let items = value;
  if (spec.maxItems && items.length > spec.maxItems) {
    ctx.addWarning(path, "too_many_items");
    items = items.slice(0, spec.maxItems);
  }

  const out = [];
  for (let i = 0; i < items.length; i++) {
    const itemPath = `${path}[${i}]`;
    const sub = newContext(ctx.options);
    const validated = validateValue(itemPath, spec.of, items[i], sub);
    if (validated === null || sub.errors.length > 0) {
      if (spec.dropInvalid === false) {
        for (const e of sub.errors) ctx.errors.push(e);
      } else {
        ctx.addWarning(itemPath, "item_dropped");
      }
      continue;
    }
    for (const w of sub.warnings) ctx.warnings.push(w);
    out.push(validated);
  }
  return out;
}

function validateObject(path, spec, value, ctx) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    ctx.addError(path, "wrong_type", {expected: "object"});
    return null;
  }
  const out = {};
  const known = spec.fields || {};

  for (const key of Object.keys(known)) {
    const childPath = path ? `${path}.${key}` : key;
    const fieldSpec = known[key];
    const raw = value[key];

    if (raw === undefined || raw === null) {
      if (fieldSpec.required) {
        ctx.addError(childPath, "missing");
      }
      out[key] = null;
      continue;
    }
    const validated = validateValue(childPath, fieldSpec, raw, ctx);
    out[key] = validated;
  }

  for (const key of Object.keys(value)) {
    if (!Object.prototype.hasOwnProperty.call(known, key)) {
      ctx.addWarning(path ? `${path}.${key}` : key, "unknown_key");
    }
  }
  return out;
}

function validateValue(path, spec, value, ctx) {
  switch (spec.kind) {
    case "string": return validateString(path, spec, value, ctx);
    case "number": return validateNumber(path, spec, value, ctx);
    case "boolean": return validateBoolean(path, spec, value, ctx);
    case "enum": return validateEnum(path, spec, value, ctx);
    case "array": return validateArray(path, spec, value, ctx);
    case "object": return validateObject(path, spec, value, ctx);
    default:
      ctx.addError(path, "unsupported_spec");
      return null;
  }
}

function priceField(required) {
  return {kind: "number", min: 0, max: MAX_PRICE_ILS, required: !!required};
}

function tokenField(maxLen) {
  return {kind: "string", maxLen: maxLen || MAX_TOKEN_LEN};
}

function checkPriceOrder(v, ctx) {
  if (typeof v.minPrice === "number" && typeof v.maxPrice === "number" &&
      v.minPrice > v.maxPrice) {
    const min = v.maxPrice;
    v.maxPrice = v.minPrice;
    v.minPrice = min;
    ctx.addWarning("minPrice", "range_inverted");
  }
}

function checkSubcategoryInCategory(v, ctx, opts) {
  const categoryKey = opts.categoryKey || "category";
  const subKey = opts.subcategoryKey || "subcategory";
  const category = v[categoryKey];
  const sub = v[subKey];
  if (!category || !sub) return;
  if (!subcategoriesByCategory) {
    ctx.addWarning(subKey, "taxonomy_unverified");
    return;
  }
  const allowed = subcategoriesByCategory.get(category);
  if (allowed && allowed.has(sub)) return;

  if (opts.warnOnly) {
    ctx.addWarning(subKey, "subcategory_not_in_category", {safe: true, got: sub});
    return;
  }
  ctx.addWarning(subKey, "subcategory_not_in_category", {safe: true, got: sub});
  v[subKey] = null;
}

function checkDerivedFlag(v, ctx, opts) {
  const threshold = opts.threshold;
  if (!isSafeNumber(threshold)) return;
  const score = v[opts.scoreKey];
  if (!isSafeNumber(score)) return;
  const expected = score >= threshold;
  if (v[opts.flagKey] !== expected) {
    ctx.addWarning(opts.flagKey, "derived_flag_disagreed");
    v[opts.flagKey] = expected;
  }
}

function checkRecommendationsAgainstCandidates(v, ctx) {
  const list = Array.isArray(v.recommendations) ? v.recommendations : [];
  const allowedRaw = ctx.context.allowedProductIds;
  const allowed = allowedRaw instanceof Set ? allowedRaw :
      (Array.isArray(allowedRaw) ? new Set(allowedRaw) : null);

  const seen = new Set();
  const kept = [];
  for (const rec of list) {
    if (!rec || typeof rec.productId !== "string") continue;
    if (seen.has(rec.productId)) {
      ctx.addWarning("recommendations", "duplicate_product");
      continue;
    }
    if (allowed && !allowed.has(rec.productId)) {
      ctx.addWarning("recommendations", "product_not_in_candidates");
      continue;
    }
    seen.add(rec.productId);
    kept.push(rec);
  }
  if (!allowed) ctx.addWarning("recommendations", "candidates_not_supplied");
  v.recommendations = kept;
}

const SchemaName = Object.freeze({
  SEARCH_INTENT: "search_intent",
  PRODUCT_EXTRACTION: "product_extraction",
  MODERATION_VERDICT: "moderation_verdict",
  PHOTO_QUALITY: "photo_quality",
  ALERT_MATCH: "alert_match",
  ALERT_CRITERIA: "alert_criteria",
  RECOMMENDATIONS: "recommendations",
  RETAIL_PRICE: "retail_price",
  BRAND_VERIFICATION: "brand_verification",
});

const SCHEMAS = {};

SCHEMAS[SchemaName.SEARCH_INTENT] = {
  fields: {
    keywords: {
      kind: "array", of: tokenField(), maxItems: 25, required: true,
    },
    category: {kind: "enum", vocab: "category"},
    subcategory: {kind: "enum", vocab: "subcategory", unknownIsWarning: true},
    brand: {kind: "string", maxLen: MAX_BRAND_LEN},
    brandAliases: {
      kind: "array", of: {kind: "string", maxLen: MAX_BRAND_LEN}, maxItems: 5,
    },
    model: {kind: "string", maxLen: MAX_MODEL_LEN},
    minPrice: priceField(),
    maxPrice: priceField(),
    condition: {kind: "enum", vocab: "condition"},
    city: {kind: "string", maxLen: MAX_CITY_LEN},
  },
  checks: [
    checkPriceOrder,
    function searchSubcategory(v, ctx) {
      checkSubcategoryInCategory(v, ctx, {warnOnly: true});
    },
  ],
};

SCHEMAS[SchemaName.PRODUCT_EXTRACTION] = {
  fields: {
    blocked: {kind: "boolean"},
    reason: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
    title: {kind: "string", maxLen: MAX_TITLE_LEN},
    brand: {kind: "string", maxLen: MAX_BRAND_LEN},
    model: {kind: "string", maxLen: MAX_BRAND_LEN},
    color: {kind: "string", maxLen: MAX_BRAND_LEN},
    condition: {kind: "enum", vocab: "condition"},
    category: {kind: "enum", vocab: "category"},
    subcategory: {kind: "enum", vocab: "subcategory"},
    priceEstimate: {
      kind: "object",
      fields: {min: priceField(), max: priceField()},
    },
    description: {kind: "string", maxLen: MAX_DESCRIPTION_LEN},
    features: {kind: "array", of: tokenField(120), maxItems: 12},
    missingInfo: {kind: "array", of: tokenField(120), maxItems: 12},
  },
  checks: [
    function blockOrAnalysis(v, ctx) {
      if (v.blocked === true) return;
      if (!v.title) ctx.addError("title", "missing");
    },
    function extractionSubcategory(v, ctx) {
      checkSubcategoryInCategory(v, ctx, {});
    },
    function priceEstimateOrder(v, ctx) {
      const pe = v.priceEstimate;
      if (!pe || !isSafeNumber(pe.min) || !isSafeNumber(pe.max)) return;
      if (pe.min > pe.max) {
        const lo = pe.max;
        pe.max = pe.min;
        pe.min = lo;
        ctx.addWarning("priceEstimate", "range_inverted");
      }
    },
  ],
};

SCHEMAS[SchemaName.MODERATION_VERDICT] = {
  fields: {
    isAppropriate: {kind: "boolean", required: true},
    reason: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
    category: {kind: "enum", values: MODERATION_CATEGORIES},
  },
  checks: [
    function blockNeedsReason(v, ctx) {
      if (v.isAppropriate === false && !v.reason) {
        ctx.addWarning("reason", "block_without_reason");
      }
    },
  ],
};

SCHEMAS[SchemaName.PHOTO_QUALITY] = {
  fields: {
    overallScore: {kind: "number", min: 0, max: 10, required: true},
    scores: {
      kind: "object",
      fields: {
        lighting: {kind: "number", min: 0, max: 10},
        sharpness: {kind: "number", min: 0, max: 10},
        angle: {kind: "number", min: 0, max: 10},
        background: {kind: "number", min: 0, max: 10},
        presentation: {kind: "number", min: 0, max: 10},
      },
    },
    isGoodEnough: {kind: "boolean"},
    feedback: {
      kind: "object",
      fields: {
        lighting: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
        sharpness: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
        angle: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
        background: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
        presentation: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
      },
    },
    suggestions: {kind: "array", of: tokenField(200), maxItems: 8},
  },
  checks: [
    function goodEnoughIsDerived(v, ctx) {
      checkDerivedFlag(v, ctx, {
        flagKey: "isGoodEnough",
        scoreKey: "overallScore",
        threshold: ctx.context.photoQualityThreshold,
      });
    },
  ],
};

SCHEMAS[SchemaName.ALERT_MATCH] = {
  fields: {
    isMatch: {kind: "boolean", required: true},
    matchScore: {kind: "number", min: 0, max: 100, required: true},
    matchReason: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
  },
  checks: [
    function matchIsDerived(v, ctx) {
      checkDerivedFlag(v, ctx, {
        flagKey: "isMatch",
        scoreKey: "matchScore",
        threshold: ctx.context.minMatchScore,
      });
    },
  ],
};

SCHEMAS[SchemaName.ALERT_CRITERIA] = {
  fields: {
    categoryId: {kind: "enum", vocab: "category"},
    category: {kind: "string", maxLen: MAX_CITY_LEN},
    keywords: {kind: "array", of: tokenField(), maxItems: 20},
    minPrice: priceField(),
    maxPrice: priceField(),
    condition: {kind: "enum", vocab: "condition"},
    city: {kind: "string", maxLen: MAX_CITY_LEN},
    maxDistance: {kind: "number", min: 0, max: 500},
    summary: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
  },
  checks: [checkPriceOrder],
};

SCHEMAS[SchemaName.RECOMMENDATIONS] = {
  fields: {
    recommendations: {
      kind: "array",
      maxItems: 20,
      required: true,
      of: {
        kind: "object",
        fields: {
          productId: {kind: "string", maxLen: MAX_ID_LEN, required: true},
          reason: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN, required: true},
          score: {kind: "number", min: 0, max: 10, required: true},
        },
      },
    },
  },
  checks: [checkRecommendationsAgainstCandidates],
};

SCHEMAS[SchemaName.RETAIL_PRICE] = {
  fields: {
    retailNewIls: {kind: "number", min: 1, max: MAX_PRICE_ILS},
    confidence: {kind: "enum", values: CONFIDENCE_LEVELS, required: true},
    identifiedModel: {kind: "string", maxLen: MAX_TITLE_LEN},
  },
  checks: [
    function confidenceNeedsAPrice(v, ctx) {
      if (v.retailNewIls === null && v.confidence === "high") {
        v.confidence = "low";
        ctx.addWarning("confidence", "confidence_without_value");
      }
    },
  ],
};

SCHEMAS[SchemaName.BRAND_VERIFICATION] = {
  fields: {
    isRealBrand: {kind: "boolean", required: true},
    confidence: {kind: "number", min: 0, max: 1, required: true},
    reasoning: {kind: "string", maxLen: MAX_SHORT_TEXT_LEN},
  },
};

function validate(schemaName, input, options) {
  const schema = SCHEMAS[schemaName];
  const ctx = newContext(options);

  if (!schema) {
    ctx.addError("$", "unknown_schema");
    return {
      ok: false, value: null, partial: null, errors: ctx.errors,
      warnings: ctx.warnings, stage: "schema", taxonomySource,
    };
  }

  const value = validateObject("", schema, input, ctx);
  const shapeErrors = ctx.errors.length;

  if (value !== null && shapeErrors === 0) {
    const checks = (schema.checks || [])
        .concat((options && options.businessChecks) || []);
    for (const check of checks) {
      try {
        check(value, ctx);
      } catch (e) {
        console.error("⚠️ [AI_SCHEMAS] check threw:", e && e.message);
        ctx.addError("$", "check_failed");
      }
    }
  }

  const ok = ctx.errors.length === 0 && value !== null;
  let stage = "ok";
  if (!ok) stage = shapeErrors > 0 || value === null ? "schema" : "business";

  return {
    ok,
    value: ok ? value : null,
    partial: value,
    errors: ctx.errors,
    warnings: ctx.warnings,
    stage,
    taxonomySource,
  };
}

let jsonExtractor = null;

function setJsonExtractor(fn) {
  if (fn === null) {
    jsonExtractor = null;
    return;
  }
  if (typeof fn !== "function") {
    console.error(
        "🚨 [AI_SCHEMAS] setJsonExtractor called with a " + typeof fn +
        " — keeping the existing extractor. Pass null to clear deliberately.");
    return;
  }
  jsonExtractor = fn;
}

function parseAiResponse(raw, schemaName, options) {
  const opts = options || {};

  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    return validate(schemaName, raw, opts);
  }

  if (typeof raw !== "string" || !raw.trim()) {
    return {
      ok: false,
      value: null,
      partial: null,
      errors: [{path: "$", code: "empty_response"}],
      warnings: [],
      stage: "empty",
      taxonomySource,
    };
  }

  let parsed = null;
  try {
    const direct = JSON.parse(raw.trim());
    if (direct && typeof direct === "object" && !Array.isArray(direct)) {
      parsed = direct;
    }
  } catch (e) {
    parsed = null;
  }

  if (parsed === null) {
    const extractor = typeof opts.extractJsonObject === "function" ?
        opts.extractJsonObject : jsonExtractor;
    if (extractor) {
      try {
        const extracted = extractor(raw, opts.requiredKeys);
        if (extracted && typeof extracted === "object" && !Array.isArray(extracted)) {
          parsed = extracted;
        }
      } catch (e) {
        console.error("⚠️ [AI_SCHEMAS] json extractor threw:", e && e.message);
      }
    } else {
      console.warn("⚠️ [AI_SCHEMAS] no JSON extractor installed — " +
          "call setJsonExtractor(aiSearch.extractJsonObject) at startup");
    }
  }

  if (parsed === null) {
    return {
      ok: false,
      value: null,
      partial: null,
      errors: [{path: "$", code: "no_json_object"}],
      warnings: [],
      stage: "parse",
      taxonomySource,
    };
  }

  return validate(schemaName, parsed, opts);
}

exports.SchemaName = SchemaName;
exports.validate = validate;
exports.parseAiResponse = parseAiResponse;
exports.setJsonExtractor = setJsonExtractor;
exports.setTaxonomy = setTaxonomy;
exports.taxonomyStatus = taxonomyStatus;
exports.TaxonomySource = TaxonomySource;

exports._internals = {
  isSafeNumber, coerceNumber, validateValue, vocabulary, adoptTaxonomy,
  checkPriceOrder, checkSubcategoryInCategory, checkDerivedFlag,
  checkRecommendationsAgainstCandidates,
  MODERATION_CATEGORIES, CONFIDENCE_LEVELS, MAX_PRICE_ILS, MAX_SAFE_ABS,
  SCHEMAS,
};
