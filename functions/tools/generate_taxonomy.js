'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const REPO = path.resolve(__dirname, '..', '..');
const CATEGORIES_DART = path.join(REPO, 'lib', 'core', 'constants', 'categories.dart');
const ENUMS_DART = path.join(REPO, 'lib', 'core', 'constants', 'enums.dart');
const OUT_DIR = path.join(__dirname, '..', 'src', 'generated');
const OUT_FILE = path.join(OUT_DIR, 'taxonomy.json');

function readOrDie(p) {
  if (!fs.existsSync(p)) {
    console.error(`✖ source not found: ${p}`);
    console.error('  The taxonomy lives in Dart. If these files moved, update');
    console.error('  the paths at the top of functions/tools/generate_taxonomy.js.');
    process.exit(2);
  }
  return fs.readFileSync(p, 'utf8');
}

function parseCategories(src) {
  const categories = {};
  const order = [];

  const clean = src.replace(/^\s*\/\/.*$/gm, '');

  const ctorRe = /\b(CategoryField|SubCategory|Category)\s*\(/g;
  const idRe = /\bid:\s*'([^']*)'/;

  const stack = [];
  let depth = 0;
  let currentCategory = null;

  for (let i = 0; i < clean.length; i++) {
    const ch = clean[i];

    if (ch === '(') {
      ctorRe.lastIndex = Math.max(0, i - 40);
      let name = null;
      let m;
      while ((m = ctorRe.exec(clean)) !== null) {
        if (m.index + m[0].length - 1 === i) { name = m[1]; break; }
        if (m.index > i) break;
      }
      depth++;
      if (name) {
        const window = clean.slice(i, i + 400);
        const idm = window.match(idRe);
        const id = idm ? idm[1] : null;
        stack.push({ name, depth, id });
        if (name === 'Category' && id) {
          currentCategory = id;
          if (!categories[id]) { categories[id] = []; order.push(id); }
        } else if (name === 'SubCategory' && id && currentCategory) {
          if (!categories[currentCategory].includes(id)) {
            categories[currentCategory].push(id);
          }
        }
      }
      continue;
    }

    if (ch === ')') {
      depth--;
      while (stack.length && stack[stack.length - 1].depth > depth) {
        const closed = stack.pop();
        if (closed.name === 'Category') currentCategory = null;
      }
    }
  }

  return { categories, order };
}

function parseConditions(src) {
  const clean = src.replace(/^\s*\/\/.*$/gm, '');
  const m = clean.match(/enum\s+ProductCondition\s*\{([\s\S]*?)\}/);
  if (!m) return [];
  return m[1]
      .split(',')
      .map((s) => s.trim())
      .map((s) => (s.match(/^([A-Za-z_][A-Za-z0-9_]*)/) || [])[1])
      .filter(Boolean);
}

function main() {
  const check = process.argv.includes('--check');

  const catSrc = readOrDie(CATEGORIES_DART);
  const enumSrc = readOrDie(ENUMS_DART);

  const { categories, order } = parseCategories(catSrc);
  const conditions = parseConditions(enumSrc);

  const catCount = order.length;
  const subCount = new Set(
      Object.values(categories).reduce((a, b) => a.concat(b), [])).size;

  if (catCount < 5 || subCount < 20 || conditions.length < 3) {
    console.error('✖ refusing to write: parse looks wrong');
    console.error(`  categories=${catCount} subcategories=${subCount} ` +
        `conditions=${conditions.length}`);
    console.error('  Expected roughly 15 / 77 / 5. Did categories.dart change shape?');
    process.exit(3);
  }

  const sourceHash = crypto.createHash('sha256')
      .update(catSrc).update(enumSrc).digest('hex').slice(0, 16);

  const artifact = {
    _comment: 'GENERATED — do not edit. Source of truth is ' +
        'lib/core/constants/categories.dart + enums.dart. ' +
        'Regenerate with: node functions/tools/generate_taxonomy.js',
    generator: 'functions/tools/generate_taxonomy.js',
    sourceHash,
    categoryOrder: order,
    categories,
    conditions,
  };

  const json = JSON.stringify(artifact, null, 2) + '\n';

  if (check) {
    if (!fs.existsSync(OUT_FILE)) {
      console.error('✖ taxonomy.json is missing — run the generator and commit it.');
      process.exit(1);
    }
    const existing = fs.readFileSync(OUT_FILE, 'utf8');
    const existingHash = (JSON.parse(existing) || {}).sourceHash;
    if (existingHash !== sourceHash) {
      console.error('✖ taxonomy.json is STALE.');
      console.error(`  committed sourceHash=${existingHash} actual=${sourceHash}`);
      console.error('  Run: node functions/tools/generate_taxonomy.js');
      process.exit(1);
    }
    console.log(`✓ taxonomy.json is current (${catCount} categories, ` +
        `${subCount} subcategories, ${conditions.length} conditions)`);
    return;
  }

  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.writeFileSync(OUT_FILE, json, 'utf8');
  console.log(`✓ wrote ${path.relative(REPO, OUT_FILE)}`);
  console.log(`  ${catCount} categories, ${subCount} subcategories, ` +
      `${conditions.length} conditions, sourceHash=${sourceHash}`);
  console.log(`  categories: ${order.join(', ')}`);
}

main();
