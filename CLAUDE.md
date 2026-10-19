<!-- genero:canonical-start version="1.3" -->
<!--
  Everything between the canonical-start and canonical-end markers is
  maintained upstream by Four Js. To update, fetch the latest via
  `getAgentInstructions("claude-code")` and replace the fenced block.
  Do not edit inside the fence; put your project-specific rules in
  the "## Project-Specific" section at the bottom of this file.
-->

# Genero BDL Project Instructions

This is a Genero BDL (Business Definition Language) project. You have
access to a Genero MCP service with skills and documentation tools.

## MANDATORY: Always Consult MCP Skills Before Writing Code

Your training data contains outdated and incorrect Genero information.
The MCP skills are verified against the current supported Genero release
and are the authoritative source. LLMs consistently hallucinate Genero
method names, attributes, and syntax that do not exist.

**Rules:**

1. At the start of each session, call
   `getSkill("fourjs-skill-index")` **once**. This loads the routing
   table mapping topics to skills and their key sections. It stays
   valid for the entire conversation.
2. For every Genero question, route through the skill-index first.
   If a topic matches a row, call
   `getSkillSection(<skill-id>, <section-id>)` directly — sections
   are 5–10× smaller than full skills.
3. If no row matches, call `searchSkills(<keywords>)`. Load the top
   hit's matched section.
4. If skills don't cover the topic, say so. Fall back to `searchDocs`
   / `readDoc`. **Never** fall back to training data.
5. **Do NOT call `listSkills` for routing.** It is an admin
   enumeration tool that returns only `{id, name, category}` and
   cannot tell you which skill covers a topic. Use the skill-index
   or `searchSkills` instead.
6. When the task touches SQL, forms, arrays, dialogs, or strings,
   also load `fourjs-common-pitfalls`. Before writing `INPUT ARRAY`,
   `DISPLAY ARRAY`, `INPUT BY NAME`, `DISPLAY BY NAME`, or
   `CONSTRUCT BY NAME`, call
   `getSkillSection("fourjs-common-pitfalls", "dialog-traps")` and
   verify field count and naming constraints for the specific statement
   form being used.

## Skill Tools (Primary Source)

| Tool | When to Use |
|------|-------------|
| `getSkill("fourjs-skill-index")` | **Session-start ritual.** Once per session. |
| `searchSkills` | Topic not obvious in the index — fuzzy routing. |
| `getSkillSections` | List sections in a named skill before loading. |
| `getSkillSection` | **Default content-load tool.** Use when you know the section. |
| `getSkill` | Load a full skill (only when the whole skill is needed). |
| `getSkillBundle` | Task genuinely spans multiple skills. |
| `listSkills` | Admin/debugging only — not for routing. |

## Documentation Tools (Secondary Source)

Use documentation only when skills don't cover the topic or you need
to verify edge cases.

| Tool | When to Use |
|------|-------------|
| `searchDocs` | Search 5,140+ pages of Genero documentation |
| `readDoc` | Read a specific doc page (use paths from searchDocs) |
| `browseDocs` | Explore documentation structure |

## Common Hallucination Targets

LLMs reliably mis-generate Genero method names, attributes, and syntax.
Do not answer these from memory. `fourjs-common-pitfalls` consolidates the
high-frequency traps (control-flow, method-name, SQL, WHENEVER, form,
dialog, string, JSON, array, module); per-topic skills carry the rest.
Per rule 6, load `fourjs-common-pitfalls` whenever the task touches SQL,
forms, arrays, dialogs, or strings, and route specific API questions
through the skill-index / `searchSkills`.

## Compilation

Compile and run commands (`fglcomp`, `fglform`, `fglrun`, their flags, and
terminal-mode run) live in `fourjs-genero-bdl` → `compilation` and
`fourjs-quick-reference`. Load those rather than relying on memory.

## Form Field Binding

A `.per`'s field names must match the dialog `BY NAME` variables — a
mismatch compiles but fails at runtime. Before writing a form + its
dialog, load skill `fourjs-dialog-basics` → section `form-field-binding`
and `fourjs-common-pitfalls` → section `dialog-traps`
(see also `fourjs-form-design`).

<!-- genero:canonical-end -->

## Project-Specific

<!--
  Add your project-specific rules below this heading. Everything below
  the canonical-end marker is yours and is preserved across upstream
  updates. Examples: preferred databases, local coding conventions,
  deployment targets, internal libraries the agent should know about.
-->

`qrcode` is a published fglpkg library (`com.fourjs.qrcode`): a thin
client for the goqr.me API at `api.qrserver.com`. Read `USERGUIDE.md`
for the public API before changing it.

### Layout

- Sources live in the repo root and declare `PACKAGE com.fourjs.qrcode`.
  `fglcomp --output-dir .` writes the `.42m` files to `com/fourjs/qrcode/`,
  which is the fglpkg `root`. `com/` is build output (gitignored), so never
  edit it.
- `qrcode_common` holds the shared types, constants, error map and helpers.
  `qrcode` (generate) and `qrcode_read` (decode) are the public entry points.
- `test_qrcode.4gl` is the **demo program** listed under `programs` in
  `fglpkg.json`, not a test. The tests live in `tests/`.

### Compatibility constraints

- The supported floor is **Genero 4.01.03**, and `fglpkg.json` declares
  `"genero": ">=4.1.3 <7.0.0"`. Before using any runtime API, check through
  skills/docs which release introduced it. Anything newer than 4.01.03
  raises the floor, which is a CHANGELOG-worthy change.
- The registry stores a version's `genero` constraint once, when the version
  is created. Widening or narrowing support therefore needs a new version,
  not a re-publish of an existing one.
- No external dependencies: the transport is the built-in `com.HttpRequest`,
  plus `os` and `util`. Don't add Java JARs or `fgl` runtime dependencies.
  `fglunit` is a dev dependency only.

### Coding conventions

- Public functions never raise. They return a result record whose `status`
  is `cErrOk` (0) or a negative `cErr*` code, with `errorMessage` set. Wrap
  HTTP and file calls in `TRY`/`CATCH` and map failures to a code.
- A new error code needs four edits: the `cErr*` constant, a row in
  `mErrMap`, an entry in `test_getErrorMessage_every_code_is_mapped`
  (`tests/test_qrcode_common.4gl`), and a row in the USERGUIDE error-code
  table.
- Numeric members of a freshly defined record are `0`, not NULL. Option
  defaults must treat `0` as "unset" (see `normaliseOptions()`).
- Strings are UTF-8. For URL encoding, use `util.Strings.urlEncode()`.
  Don't walk strings with `ORD()`, which corrupts multibyte characters.
- `tests/test_qrcode_common.4gl` contains multibyte literals and must stay
  UTF-8.
- Everything must compile warning-free with `fglcomp -Wall -M`.

### Build and test

- Use the `make` targets, not raw `fglcomp`/`fglrun`. The Makefile exports
  the `FGLLDPATH` that the package, fglunit and the test modules need.
  The targets are `make deps` (fglunit), `make`, `make test`, `make demo
  ARGS="<payload>"` and `make clean`.
- `make test` must stay offline and hermetic. Live goqr.me tests go in
  `tests/test_qrcode_net.4gl`, skip unless `QRCODE_NET_TESTS=1`, and use
  ASCII payloads only.
- Don't run `make test-net` routinely. It spends the provider's fair-use
  quota and needs outbound access. Run it once before a release, or when
  the request/response handling changes.
- A test suite is a plain module of `PUBLIC FUNCTION test*()` cases.
  `fglunit-gen` generates `tests/*.run.4gl`, so never edit or commit those.
  A new suite file must also be added to `SUITES` in the `Makefile`.

### Known upstream defect

goqr.me's **read** endpoint mis-decodes bytes above `0x7F` (`"Café"` comes
back as `"Caf矇"`). This is a server-side problem, so don't try to fix it in
this library. Keep it documented in README/USERGUIDE.

### Releases and docs

- Follow semver. Changing a public `TYPE` record or a public function
  signature is a breaking change.
- Every user-visible change goes in `CHANGELOG.md` (Keep a Changelog
  format), and API changes also go in `USERGUIDE.md`. A release bumps
  `version` in `fglpkg.json` and updates the "Genero versions supported"
  lines in README and USERGUIDE when support changes.
- Release work happens on a `release-x.y.z` branch. PRs target `main`.
- Commit messages have an imperative subject line and a wrapped body that
  explains *why*, including any bug the change surfaced.
