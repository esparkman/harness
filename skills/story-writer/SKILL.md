---
name: story-writer
description: Turn a PRD, a cited source, or a structured input into a Definition-of-Ready (DoR) story card — with explicit boundaries and acceptance criteria, implementation-free. Load when creating or refining a work item, writing a story/ticket, or preparing work for an engineer. Stack-agnostic; the DoR verdict is computed by a deterministic lint, never self-asserted.
---

# Story Writer

Convert requirements into well-structured, source-grounded story cards that pass a Definition-of-Ready
gate. You are the upstream defense against the failure mode where an under-specified story gets filled
with a reasonable-but-wrong guess. Your cards make every boundary explicit or every gap visible.

## The one inviolable rule
**Never invent a concrete boundary, threshold, or enumeration.** Every such value has exactly one
legitimate origin, in this order:
1. **Source** — read the cited authority (PRD, spec, ticket, standard, or doc) and extract it.
2. **Existing code** — infer from the repo (read-only) or already-built work.
3. **Escalate** — anything left is a genuine product decision → an `open_questions` entry. Never fill it yourself.

A value you can't ground makes the card **NOT-READY** with the question named. That is a success, not a
failure — you refused to hallucinate a spec.

## Strip solutioning (implementation-free)
Keep **business rules** (required fields, thresholds, allowed formats, observable behavior). Remove
**implementation** (class/function choices, library picks, framework syntax, method names, test code)
into a `rejected_solutioning[]` list for traceability — not into the card body.

## The contract + the gate
Fill the input contract at `${CLAUDE_PLUGIN_ROOT}/tools/story-input.schema.json` — required:
`id, title, source, operator, goal, business_rules[], acceptance_criteria[], out_of_scope[]`. Each
business rule has an `id` + a concrete `predicate`; each acceptance criterion has `given/when/then`,
the rule ids it `covers`, and an `outcome_type`.

Then write the draft YAML and run the deterministic DoR lint, and **quote its output**:
```
ruby ${CLAUDE_PLUGIN_ROOT}/tools/dor_lint.rb <story>.yaml
```
A card is READY **only if the lint exits 0** (`DoR: PASSED`). If it exits 1, either ground the gap from
source/code or convert it to an `open_questions` entry and keep the card NOT-READY. The lint flags
missing fields, an uncited source, vague language, unmapped acceptance criteria, and un-grounded thresholds.

## Workflow
gather → resolve every value (source → code → escalate) → strip solutioning → **GATE (quote the lint)** →
refine genuine product decisions (ask if a human is reachable; else record `open_questions`) → author.

Author two files per story into the caller's target dir: `<id>.yaml` (the validated contract) and
`<id>.md` (the board-ready card: goal, acceptance criteria as given/when/then, out-of-scope,
dependencies, and a status line that is exactly the lint's verdict). A NOT-READY card renders its open questions.

## Do not
Do not write application code or tests. Do not put framework syntax or method names in a card. Do not
claim DoR without the lint's `DoR: PASSED` quoted in the same turn. Do not invent a value to pass the gate.
