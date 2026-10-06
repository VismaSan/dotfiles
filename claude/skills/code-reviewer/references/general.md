# General Review Principles

Language-agnostic rules. Language files in `languages/` refine and override these.

## Contents
1. Severity scale
2. Correctness
3. Security
4. Performance & efficiency
5. Cleanliness & code smells
6. Right-sizing: neither over- nor under-engineered
7. Style & conventions
8. What not to comment on

---

## 1. Severity scale

| Severity | Meaning | Examples |
|---|---|---|
| **Blocker** | Must fix before merge. Data loss/corruption, security hole, crash on a normal path, broken upgrade/deploy. | Deletes from a real table instead of a temp one; secret in source; unfiltered modify-all. |
| **Major** | Should fix before merge. Wrong result in a realistic edge case, significant performance problem at production volume, missing error handling that leaves inconsistent state, design that will be costly to undo. | Lookup inside a loop over all ledger entries; error swallowed silently; missing permission. |
| **Minor** | Worth fixing, won't hurt much if deferred. Readability, small inefficiencies, smells with local blast radius. | 4-level nested ifs; magic number; duplicated 10-line block. |

There is deliberately no "Nit" level. Taste and polish (naming tweaks, comment wording, ordering, formatting a formatter would fix) are not reported. A style issue is reported only if it clears the Minor bar: it hurts readability, breaks a project/platform convention, or would fail an enabled analyzer.

Calibrate to consequences, not to how confident or how clever the finding feels. When unsure between two levels, pick the lower one and say what would make it higher ("Major if this runs on posting").

## 2. Correctness

Ask of every change: what does this do when the data isn't what the author imagined?

- **Empty / missing**: no records found, null/blank input, zero quantity, division by zero, first-run state with no setup data.
- **Many**: what happens with 1 row vs 1,000,000? With duplicates?
- **Boundaries**: off-by-one, inclusive/exclusive ranges, date/time zones, rounding of money and quantities.
- **State & order**: does the code assume a previous step ran? Is a variable reused across iterations without reset? Are filters/state left behind for the caller?
- **Concurrency & transactions**: two users at once; partial failure mid-way — is the data left consistent? Are commits/rollbacks placed where they can't split a logical unit?
- **Error paths**: errors surfaced with useful context; nothing swallowed; no "catch and continue" that hides failure; failure doesn't leave half-written state.
- **Contract with callers**: changed signature/behaviour of something others call or subscribe to; side effects callers don't expect.
- **Intent**: does it actually do what the PR/task says? Missing requirement is a correctness finding.

## 3. Security

- **Trust boundaries**: any value from a user, file, API, or another tenant is untrusted. Look for it reaching queries/filters, file paths, URLs, commands, HTML.
- **Secrets**: no credentials, tokens, keys, connection strings in source, config committed to git, logs, or error messages. Use the platform's secret storage.
- **Least privilege**: code and permission definitions grant only what's needed; no blanket elevation to "make it work".
- **Data exposure**: personal/sensitive data classified, not logged, not sent to telemetry or third parties unintentionally.
- **Outbound calls**: HTTPS, certificate validation not disabled, timeouts, response validated before use.
- **Access surface**: things that don't need to be public/external aren't.

## 4. Performance & efficiency

Think in terms of *work per row* and *round-trips*:

- Database/API calls inside loops (N+1). Prefer set-based operations, joins/queries, or pre-loading into a lookup.
- Loading more than needed: all columns when two are used, all rows when one is checked, counting when existence suffices.
- Repeated computation of the same value inside a loop.
- Lock scope and duration: locking more rows or longer than necessary; long-running work inside a transaction.
- Work on hot paths (UI rendering per row, triggers fired on every insert, event subscribers on frequent events) deserves extra scrutiny; one-off setup code deserves much less.
- Don't demand micro-optimizations that cost readability on cold paths. Say "fine at current volume" when that's the honest assessment.

## 5. Cleanliness & code smells

Flag these — they're the things that make code expensive to change:

- **Deep nesting.** More than ~2–3 levels of `if`/loop nesting in one procedure. Usual fix: guard clauses / early exit, invert conditions, extract the inner block into a well-named procedure, or replace if-chains on one value with a `case`.
  ```
  // smell                               // better
  if A then                              if not A then exit;
    if B then                            if not B then exit;
      if C then                          if not C then exit;
        DoWork();                        DoWork();
  ```
- **Long procedures** doing several things (rule of thumb: >40–60 lines or more than one level of abstraction mixed together). Suggest the split along responsibilities, not arbitrary line counts.
- **Long parameter lists** (>4–5), boolean flag parameters that switch behaviour ("DoIt(true, false, true)") — suggest separate procedures or a parameter object/record.
- **Duplication** of non-trivial logic (same 5+ lines in 2+ places, or the same condition re-derived in several places).
- **Magic values**: unexplained literals that encode business rules — name them (constant, label, enum, setup field).
- **Dead code**: unused variables/parameters/procedures, commented-out code, unreachable branches.
- **Misleading names**: names that lie about what the thing does or holds; abbreviations that aren't standard in the domain.
- **Comments that restate code** or are stale. Good comments explain *why*.
- **Hidden side effects**: a "Get"/"Calc"/"Check" procedure that also modifies data.
- **Mutable global/shared state** used to pass data between procedures instead of parameters.

## 6. Right-sizing: neither over- nor under-engineered

Good code is the simplest thing that correctly solves today's problem and is easy to change tomorrow. Push back in **both** directions.

**Over-engineering — flag when you see:**
- An interface/abstract layer/strategy/factory with exactly one implementation and no realistic second one (or no external extender who needs it).
- Wrapper/facade procedures that only forward a call.
- Configuration, setup fields, or parameters for variations nobody asked for.
- Generic "framework" code (generic handlers, reflection/RecordRef-style dynamic access) where plain typed code would do.
- Premature optimization that makes code harder to read on a cold path.
- Extra layers ("manager", "helper", "service", "handler" all for one operation).

**Under-engineering — flag when you see:**
- The smells in section 5.
- Copy-paste instead of a small shared procedure.
- Business rules hard-coded in several places that will obviously change together.
- One giant procedure/object that mixes UI, validation, persistence and integration.

When flagging over-engineering, name the concrete simpler alternative ("inline this codeunit's single procedure into X", "replace the interface + 1 impl with a direct call"). When an abstraction *is* justified (public extensibility point, genuinely multiple implementations, testing seam the project already uses), don't flag it.

## 7. Style & conventions

- The project's established conventions win over generic ones; consistency within the codebase matters more than any single rule.
- Platform/language conventions (from the language file) come next.
- Only raise style issues that affect readability or would fail the project's linters/analyzers. Batch them.

## 8. What not to comment on

- Things the compiler/enabled analyzers/formatter already catch and block on.
- Pre-existing issues in untouched code — unless the change makes them worse or depends on them. You can mention a serious one separately as "pre-existing, not introduced here".
- Nits: pure preference, polish, or anything with no readability/maintenance argument.
- Speculative "what if someday" concerns without a realistic scenario.
