export const meta = {
  name: 'calibration-audit-parallel',
  description:
    'Read-only calibration audit that fans the 9 per-feature evaluators out deterministically at the workflow layer, then synthesizes the baseline reports. Ships with the claude-calibration plugin; mirrors /claude-calibration:calibration-audit.',
  whenToUse:
    'When you want the read-only calibration baseline (per-feature findings + interactions + intent-flow) with the 9-feature fan-out guaranteed-parallel by the orchestrator instead of LLM-batched inside the evaluator.',
  phases: [
    { title: 'Resolve', detail: 'compute paths/timestamp + run folder' },
    { title: 'Init', detail: 'calibration-planner writes plan.md (audit-flow)' },
    { title: 'Fan-out', detail: '9 calibration-feature-evaluator workers in parallel' },
    { title: 'Synthesize', detail: 'calibration-evaluator merges drafts + writes reports' },
  ],
}

// The nine fixed calibration features, in canonical merge order. Must stay in sync with
// agents/calibration-evaluator.md and rules/dispatch.md.
const FEATURES = [
  'claude-md',
  'rules',
  'settings',
  'skills',
  'subagents',
  'hooks',
  'mcp',
  'plugins',
  'general',
]

// Structured output of the resolve step — every downstream phase reads these absolute paths.
const RESOLVE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['runFolder', 'projectDir', 'bundlesDir', 'docsDir', 'pluginFilter', 'nowIso', 'gitHead'],
  properties: {
    runFolder: { type: 'string', description: 'Absolute path to <projectDir>/.claude/calibration/<timestamp>/' },
    projectDir: { type: 'string', description: 'Absolute path to the audited project' },
    bundlesDir: { type: 'string', description: 'Absolute path to the plugin skills/ dir, or the literal UNKNOWN' },
    docsDir: { type: 'string', description: 'Absolute path to the plugin docs/ dir, or the literal UNKNOWN' },
    pluginFilter: { type: 'string', description: 'Canonical include:..|exclude:..|scope:.. spec, or empty string for all plugins' },
    nowIso: { type: 'string', description: 'UTC ISO-8601 timestamp for plan.md "Started"' },
    gitHead: { type: 'string', description: 'git rev-parse HEAD, or not-a-git-repo' },
  },
}

// Optional caller-supplied overrides (args). Everything is auto-discovered when omitted, so the
// workflow runs with no args inside the plugin repo itself.
const a = args || {}
const argProject = a.projectDir ? `Project dir override: ${a.projectDir}.` : ''
const argBundles = a.bundlesDir ? `Bundles dir override: ${a.bundlesDir}.` : ''
const argDocs = a.docsDir ? `Docs dir override: ${a.docsDir}.` : ''
const argFilter = a.pluginFilter ? `Plugin filter override: ${a.pluginFilter}.` : ''
const restart = a.restart ? 'true' : 'false'

phase('Resolve')

// Phase 1a — resolve the same values the calibration-audit SKILL computes in its `!` preprocessing
// block. Workflow scripts cannot run bash or read the clock, so a cheap agent does it for us.
const ctx = await agent(
  `You are bootstrapping a read-only **parallel calibration audit**. Resolve the paths and run
metadata the /claude-calibration:calibration-audit flow normally computes, then return them as
structured output. DO NOT create any files in this step — the planner does that next.

Resolve, using bash where useful:

1. projectDir = the audited project. ${argProject || 'Default: the current working directory (run `pwd`).'}
2. bundlesDir = the claude-calibration plugin's \`skills/\` directory (holds \`calibrate-claude-md/\`, etc.).
   ${argBundles || `Discover it: prefer \`./skills\` if \`./skills/calibrate-claude-md/reference.md\` exists (running inside the plugin repo);
   else search the plugin install/cache, e.g. \`find ~/.claude -maxdepth 6 -type d -path '*claude-calibration*/skills' 2>/dev/null | head -1\`
   and verify it contains \`calibrate-claude-md/\`. If nothing is found, return the literal string UNKNOWN.`}
3. docsDir = ${argDocs || 'the sibling `docs/` of bundlesDir (i.e. `<bundlesDir>/../docs`). If bundlesDir is UNKNOWN, return UNKNOWN.'}
4. pluginFilter = ${argFilter || `if \`<bundlesDir>/lib/resolve-plugin-filter.sh\` exists, run
   \`bash <bundlesDir>/lib/resolve-plugin-filter.sh "" "<projectDir>"\` and use its (trimmed) output; otherwise the empty string (audit all plugins).`}
5. timestamp = \`date +%Y%m%d-%H%M%S\`; nowIso = \`date -u +%Y-%m-%dT%H:%M:%SZ\`; gitHead = \`git -C <projectDir> rev-parse HEAD\` (or "not-a-git-repo").
6. runFolder = \`<projectDir>/.claude/calibration/<timestamp>\` (absolute). ${restart === 'true' ? 'Always a fresh timestamped folder (restart requested).' : 'A fresh timestamped folder is fine.'}

Return the structured object. All paths must be absolute.`,
  { label: 'resolve-paths', phase: 'Resolve', model: 'haiku', schema: RESOLVE_SCHEMA },
)

if (!ctx) throw new Error('resolve step failed — cannot continue audit')

const { runFolder, projectDir, bundlesDir, docsDir, pluginFilter, nowIso, gitHead } = ctx
const filterLine = pluginFilter && pluginFilter.length ? pluginFilter : ''
log(`Run folder: ${runFolder} · bundles: ${bundlesDir} · filter: ${filterLine || '(all plugins)'}`)

phase('Init')

// Phase 1b — the canonical planner, init mode. Creates the run folder, writes plan.md with
// intent_source: audit-flow (which arms the shipped audit-write-guard hook), and the .drafts/ dir.
await agent(
  `Agent(calibration-planner)
Mode: init.
Intent: "audit (read-only)".
Intent source: audit-flow.
Run folder: ${runFolder}.
Project dir: ${projectDir}.
Rubric dir: ${docsDir}.
Bundles dir: ${bundlesDir}.
Git HEAD: ${gitHead}.
Started: ${nowIso}.
Audit scope: user (~/.claude/) + project + enabled plugins.
Plugin filter: ${filterLine}.

After writing plan.md, also create the intermediate drafts directory: \`mkdir -p ${runFolder}/.drafts\`
(the parallel fan-out below writes per-feature drafts there).`,
  { label: 'planner-init', phase: 'Init', agentType: 'calibration-planner' },
)

phase('Fan-out')

// Phase 2 — the actual parallelization. One calibration-feature-evaluator (haiku) per feature,
// all concurrent. This replaces the evaluator's internal "spawn 9 in one tool-use block" with a
// deterministic parallel() barrier at the orchestration layer.
const fanout = await parallel(
  FEATURES.map((feature) => () =>
    agent(
      `Agent(calibration-feature-evaluator)
Pass: 1 (baseline).
Feature: ${feature}.
Run folder: ${runFolder}.
Bundles dir: ${bundlesDir}.
Rubric dir: ${docsDir}.
Project dir: ${projectDir}.
Plugin filter: ${filterLine}.
Draft path: ${runFolder}/.drafts/feat-${feature}.md.`,
      { label: `feat:${feature}`, phase: 'Fan-out', agentType: 'calibration-feature-evaluator' },
    ).then((line) => ({ feature, line })),
  ),
)

const drafted = fanout.filter(Boolean)
const failed = drafted.filter((r) => typeof r.line === 'string' && r.line.startsWith('ERROR:'))
log(`Fan-out complete: ${drafted.length}/${FEATURES.length} workers returned · ${failed.length} ERROR`)

phase('Synthesize')

// Phase 3 — reuse the canonical evaluator for the merge + cross-feature synthesis, but tell it the
// drafts already exist so it skips its own fan-out (Pass-1 steps 1–3) and runs only steps 4–8.
const summary = await agent(
  `Agent(calibration-evaluator)
Pass: 1 (baseline).
Run folder: ${runFolder}.
Plan: ${runFolder}/plan.md.
Rubric dir: ${docsDir}.
Bundles dir: ${bundlesDir}.
Project dir: ${projectDir}.
Audit scope: user + project + plugins.
Plugin filter: ${filterLine}.

PARALLEL-WORKFLOW OVERRIDE — read carefully:
The 9 per-feature baseline drafts already exist at \`${runFolder}/.drafts/feat-<feature>.md\`
(features: ${FEATURES.join(', ')}). They were produced by a deterministic parallel fan-out at the
workflow layer. DO NOT spawn calibration-feature-evaluator and DO NOT re-run the fan-out — skip
Pass-1 steps 1–3 entirely. Resume at Pass-1 **step 4** (merge the existing drafts into
\`eval-features-<ts>.md\` in canonical feature order; a missing draft gets the
"feature evaluator failed" placeholder) and complete steps 4–8 exactly as your instructions
specify: prepend the diagnostics-ask block, compose \`eval-interactions-<ts>.md\` and
\`eval-intent-flow-<ts>.md\`, update \`plan.md\` frontmatter (last_phase_completed: baseline-eval,
baseline_severity, baseline_reports), then \`rm -rf ${runFolder}/.drafts\`. Return your usual
baseline summary line.`,
  { label: 'synthesize', phase: 'Synthesize', agentType: 'calibration-evaluator' },
)

log(`Baseline ready in ${runFolder}`)

return {
  runFolder,
  pluginFilter: filterLine,
  featuresDrafted: drafted.length,
  featuresFailed: failed.map((r) => r.feature),
  summary,
}
