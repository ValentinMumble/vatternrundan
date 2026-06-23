#!/usr/bin/env node
// Server-free verification for the single-file web app.
//
// Why this exists: ~/dev hosts several projects and the Claude preview MCP shares
// one browser + one launch.json keyed by port, so `preview_start` repeatedly handed
// back the wrong project's server. This page is a static, data-driven HTML file —
// a dev server proves nothing the data can't. This harness loads index.html, stubs
// Leaflet + the DOM, runs the inline script, and inspects what actually rendered.
// No port, no browser, no shared state → it can never collide with another project.
//
// Run:  node verify.mjs       (exits non-zero if anything looks broken)

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(here, 'index.html'), 'utf8');
const script = html.split('<script>')[1].split('</script>')[0];

// Chainable no-op stub so any Leaflet call (L.map(...).addTo(...).bindPopup(...)) just works.
const noop = () => stub;
const stub = new Proxy(function () { return stub; }, { get: () => noop, apply: () => stub });

const els = {};
const makeEl = () => ({ _html: '', set innerHTML(v) { this._html = v; }, get innerHTML() { return this._html; } });
globalThis.L = stub;
globalThis.document = {
  getElementById: (id) => (els[id] ||= makeEl()),
  querySelectorAll: () => [],
  addEventListener: noop,
};
globalThis.window = { innerWidth: 1200, addEventListener: noop };

try {
  // eslint-disable-next-line no-eval
  (0, eval)(script.replace(/^'use strict';/, '')); // drop strict so we can read globals below if needed
} catch (error) {
  console.error('❌ FAIL — script threw at load:', error.message);
  process.exit(1);
}

const text = (html) => html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
const rows = (cardId) =>
  [...(els[cardId]?.innerHTML ?? '').matchAll(/<div class="row([^"]*)"[^>]*>(.*?)<\/div>\s*(?=<div class="row|<div class="dir-stats|$)/gs)]
    .map((match) => text(match[2]));

const problems = [];
const cards = ['out-card', 'ret-card'];
const chips = text(els['chips']?.innerHTML ?? '');

if (!chips) problems.push('header chips did not render');
for (const card of cards) {
  const html = els[card]?.innerHTML ?? '';
  if (!html) problems.push(`${card} did not render`);
  if (/undefined|NaN|\$\{/.test(html)) problems.push(`${card} contains undefined/NaN/unrendered template`);
}

console.log('— Header chips —\n ', chips, '\n');
for (const card of cards) {
  console.log(`— ${card} —`);
  for (const row of rows(card)) console.log('  ', row);
  console.log('');
}

if (problems.length) {
  console.error('❌ FAIL:\n' + problems.map((problem) => '  - ' + problem).join('\n'));
  process.exit(1);
}
console.log('✅ PASS — script ran clean, chips + both cards rendered, no undefined/NaN.');
