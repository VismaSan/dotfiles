# AL (Microsoft Dynamics 365 Business Central) Review Rules

Applies to `.al` files in BC extensions. Builds on `../general.md`; where they conflict, this file wins.

Rule IDs in brackets let the author look things up or enable the analyzer: **AA** = CodeCop, **AS** = AppSourceCop, **PTE** = PerTenantExtensionCop, **AW** = UICop (all Microsoft), **LC** = LinterCop (community; IDs can shift between versions). No ID = reviewer judgement or Microsoft guidance without a rule.

Baseline as of late 2026: BC 2026 wave 2 = v29 / runtime 18. Don't recommend a language feature newer than the extension's `runtime` in `app.json`.

## Contents
0. Context to gather first (PTE vs AppSource, analyzers, runtime)
1. Correctness
2. Security
3. Performance & efficiency
4. Cleanliness & code smells
5. Right-sizing in AL
6. Style & naming
7. Platform best practices (app.json, extensibility, upgrade, permissions, tests, translation)
8. Quick checklist

---

## 0. Context to gather first

**Distribution model — decides which rules apply:**

| Signal | Likely |
|---|---|
| `idRanges` within 50000–99999 | PTE |
| `AppSourceCop.json` present, `mandatoryAffixes` set, `${AppSourceCop}` in `al.codeAnalyzers` | AppSource |
| `${PerTenantExtensionCop}` in `al.codeAnalyzers` | PTE |
| Marketplace metadata filled (privacyStatement, EULA, help, logo, url) | AppSource |
| `idRanges` in a registered ISV range (70000000+ etc.) | AppSource |

Default to PTE when signals are weak, and state your assumption in the review header. Consequences:
- **AppSource**: breaking-change rules (AS0001–AS0151) matter for every change to an already-published object; mandatory affixes; DataClassification mandatory; TranslationFile required; public API surface is a long-term liability.
- **PTE**: no AppSource validation, but affixes still strongly recommended (a conflict with a future Microsoft/AppSource object forces *you* to rename), still need permission sets, DataClassification, and everything about correctness/perf/security.

**Also read:**
- `app.json`: `runtime`, `application`, `target` (Cloud vs OnPrem), `features` (`NoImplicitWith`, `TranslationFile`), `resourceExposurePolicy`, `idRanges`, dependencies.
- `.vscode/settings.json` → `al.codeAnalyzers`, `al.ruleSetPath`; `*.ruleset.json` (what's suppressed and why).
- `AppSourceCop.json` (affixes, baseline version for breaking-change checks).
- Existing objects: naming/affix pattern, folder layout, whether the repo already has a test app, permission sets, install/upgrade codeunits.

---

## 1. Correctness

### 1.1 Temporary vs real records — check first, it's the classic data-loss bug
- `DeleteAll`/`ModifyAll`/`Delete`/`Insert` on a record that's *meant* to be a buffer: verify it's actually temporary **at every call site**. A `var Buffer: Record X` parameter does *not* enforce temporariness — a caller passing a normal record makes `Buffer.DeleteAll()` wipe the real table.
- Fix: declare parameters `var TempBuffer: Record X temporary`, name temp variables with `Temp` prefix [AA0073; never on non-temp: AA0237], guard with `if not TempBuffer.IsTemporary() then Error(...)`, or use `TableType = Temporary` on pure buffer tables.
- Table-event subscribers should usually start with `if Rec.IsTemporary() then exit;`.

### 1.2 Record retrieval
- `Get` = primary key lookup, ignores filters. `FindFirst`/`FindLast` = one record honouring filters. `FindSet` = loop. `IsEmpty` = existence.
- `FindFirst` followed by `repeat..Next()` → should be `FindSet` [AA0233]. `FindSet` without `Next` → `FindFirst` [AA0181].
- **Unchecked `Get`/`FindFirst`** throws a context-free platform error ("The X does not exist. Identification fields and values: ..."). Acceptable only when absence is truly a bug; otherwise `if not X.Get(...) then Error(MyLabelErr, ...)` or `exit` [LC0084].
- **Record variable reuse**: a record reused across loop iterations or customers keeps field values; `Init()` does **not** clear primary-key fields. A header record reused for a second `Insert(true)` keeps the old `"No."` → duplicate key or wrong number. Use a fresh local variable, or `Clear(Rec)` before re-initialising.
- Leftover filters on reused/global/`var` records: `Reset()` before reusing; don't change filters on a caller's `var` record without restoring (copy with `CopyFilters`/`Copy` into a local).
- Accumulators (`Total += ...`) declared outside a loop must be reset per outer iteration when the intent is per-item.

### 1.3 Triggers and validation
- `Insert()`/`Modify()`/`Delete()` default `RunTrigger = false` → table triggers *and* OnBefore/OnAfter trigger events other apps rely on are skipped. Should be a deliberate choice; challenge `false`/omitted on business tables outside upgrade/buffer code [LC0040].
- Direct assignment (`SalesLine."No." := ...`) bypasses OnValidate, TableRelation checks, defaulting of dependent fields (prices, posting groups, dimensions, descriptions). For base-app document/journal tables this is almost always a **Major** correctness bug. Use `Validate` in the same order the UI would (header: customer → dates…; line: Type → No. → Quantity → Unit Price). Direct assignment is fine for own logic-free fields, upgrade code, or deliberate bypass with a comment.
- FlowFields are empty until `CalcFields` / `SetAutoCalcFields`. `CalcFields` on a normal field is a runtime error [AA0211]. Don't write to FlowFields [LC0001].

### 1.4 Transactions & Commit
- Every `Commit()` is a review point. It breaks atomicity: a later error leaves half-done data. **Never** inside loops [LC0002 requires a justifying comment].
- `Commit()` inside an **event subscriber** commits the *publisher's* transaction — in posting events this can leave a half-posted document, and it errors during **preview posting**. Treat as Blocker in posting/release subscribers.
- `if Codeunit.Run(...) then` requires no open write transaction beforehand and commits on success.
- Publishers that must not be committed by subscribers: `[CommitBehavior(CommitBehavior::Ignore|Error)]`.

### 1.5 Error handling
- `Error`, `Message`, `Confirm` text must come from **Labels** with placeholders, not concatenation or `StrSubstNo` inside `Error` [AA0231, AA0216, AA0217; placeholder `Comment` AA0470; args match AA0131]. Why: translation, and telemetry logs label text with correct data classification.
- Use `FieldCaption`/`TableCaption`, not `FieldName`/`TableName`, in user messages [AA0448].
- `ErrorInfo` for actionable errors (`AddNavigationAction`), collectible errors for bulk validation, `ErrorType::Internal` for technical detail.
- **`[TryFunction]`**: database writes inside a try method are **not rolled back** on failure (online it's not blocked — the bug is silent). No DB writes in try functions; only the risky non-DB call. A try function only catches if its return value is used. `if not TryX() then;` silently swallows the error — at minimum log `GetLastErrorText()` / surface it. For "attempt and roll back" use `if not Codeunit.Run(...)`.

### 1.6 Filters
- `SetFilter(Field, UserOrExternalText)` is **filter injection**: `*`, `|`, `..`, `<>`, `@` in the value change the meaning (e.g. a value of `*` matches everything). Use `SetRange(Field, Value)` for exact values or `SetFilter(Field, '%1', Value)` / `'@*%1*'` with substitution.
- Filter operators inside `SetRange` don't work as filters [LC0008].
- `SetCurrentKey` should match an existing key for large tables.

### 1.7 Enums, options, events
- New choice fields should be `enum`, not `Option` [LC0088]. Value 0 = "empty"/default [LC0045]. `Extensible = true` only if other apps should extend it.
- Event subscribers: `local procedure` [AA0207]; signature `var` modifiers must match the publisher [LC0065]; don't assume subscriber order.
- Subscribers to `IsHandled` events: `if IsHandled then exit;` first, never set it back to `false`. Microsoft now discourages *adding* new IsHandled publishers — prefer positive events or interfaces.
- Subscribers to posting events (`Sales-Post`, `Purch.-Post`, `Gen. Jnl.-Post Line`, …) run inside posting, background/job-queue posting and preview posting: no `Message`/`Confirm`/`Page.Run` (breaks non-UI sessions; use `GuiAllowed()` if truly needed), no `Commit`, and check document type/context before acting.

### 1.8 Common AL boolean/expression traps
- `not` binds tighter than comparison: `not X.AsInteger() > 0` is not "X is not > 0" (and won't compile on integers). Write `X = X::" "` or `not (A > B)`.
- Option/enum comparisons by literal integer instead of the named value.
- Date arithmetic with string formulas: `CalcDate('<1M>', D)` must use `<>`-wrapped formulas [AA0462].
- Text truncation when assigning longer text to a shorter field → runtime error [AA0139, LC0051]; use `CopyStr(..., 1, MaxStrLen(Target))` where truncation is acceptable.

---

## 2. Security

- **Secrets**: no tokens, keys, passwords, or secret-bearing URLs in source, labels, or plain table fields visible on pages. Store in `IsolatedStorage` (`DataScope::Module`, `SetEncrypted` where possible); carry as `SecretText` (runtime 13+) and fetch in `[NonDebuggable]` procedures; build auth headers with `SecretStrSubstNo` and pass `SecretText` to `HttpHeaders.Add` [LC0043]. A "setup" page for a secret should write to IsolatedStorage and show a masked field (`ExtendedDatatype = Masked`), not persist the value in a table.
- **HttpClient**: HTTPS only; check the boolean from `Send/Get/Post` (platform failure — `Response` is invalid if false) *and* `Response.IsSuccessStatusCode()`; read endpoint URLs from setup, not literals; build JSON with `JsonObject`/`JsonArray`, never string concatenation (injection/escaping bugs); certificate validation must not be disabled. Calls block the session — keep them off UI-critical paths and out of posting transactions where possible.
- **DataClassification**: every normal field needs a real value — not `ToBeClassified` [AS0016]. Table-level value is the default for its fields. Personal data (names of people, phone, email, address) → `EndUserIdentifiableInformation`; IDs that map to a person → `EndUserPseudonymousIdentifiers`. Hardcoded emails/phones in code [AA0240].
- **Permissions**: every new table/page/codeunit/report/query covered by a `permissionset` object (`Assignable = true`) [PTE0004, AS0103, LC0015]. No XML permission sets [PTE0014, AS0094]. Use the `Permissions = tabledata X = rimd` object property for indirect access in posting-style code instead of broad user permissions. `InherentPermissions` only for buffer/setup/install-type objects, never for ledger or business data.
- **Access**: `Access = Internal` on codeunits/tables not meant as API, `local`/`internal` procedures by default. This is API hygiene, **not** a security boundary [AS0081/PTE0012 for internalsVisibleTo]. Events expose their parameters to any subscriber — don't pass secrets or unnecessary sensitive data.
- **IP / source exposure**: `resourceExposurePolicy` (`allowDebugging`, `allowDownloadingSource`, `includeSourceInSymbolFile`) — check values are intentional; for a customer PTE `true` is often fine, for AppSource it's usually `false`. Don't invent a finding if it's a deliberate choice — ask.
- **Cloud restrictions**: `target: Cloud` for SaaS [PTE0005, AS0053]; no on-prem-only/unsafe methods [PTE0006, AS0060]; no `OnCompanyOpen*` subscribers [PTE0003, AS0061].

---

## 3. Performance & efficiency

Think: how many SQL round-trips per row, and how many rows on a real tenant (ledger tables have millions).

- **Set-based operations**: totals with `CalcSums` (needs a key with `SumIndexFields` for big tables), not a loop adding values. Counts with `Count()` not a loop incrementing. Existence with `IsEmpty()`, never `Count() > 0` or `FindFirst` with the record unused [AA0175, LC0081].
- **N+1**: `Get`/`FindFirst`/`CalcSums` on another table inside a loop. Alternatives: drive the loop from the smaller/filtered table, a `query` object (join), a FlowField, caching in a `Dictionary of [Code[20], ...]`, or hoisting work that depends only on the outer key out of the inner loop.
- **Partial records**: `SetLoadFields(...)` before `Get`/`Find*` when only a few fields are read — especially on wide tables (Customer, Item, Sales Line, ledger entries) and in loops. Don't use it on records you then `Insert`/`Modify`/`TransferFields`/copy (forces a JIT reload). Reading a field not loaded triggers a hidden extra query [AA0242].
- **Loops over whole tables** without filters (e.g. `Customer.FindSet()` then filter children per customer) when the child table could be filtered directly.
- **FlowFields in loops**: `SetAutoCalcFields` before the loop, not `CalcFields` per row.
- **ModifyAll/DeleteAll** are bulk only if no trigger code / table-event subscribers; still far better than a manual loop for simple updates. Consider `IsEmpty` guard before `DeleteAll` on hot paths.
- **Locking**: prefer `Rec.ReadIsolation := IsolationLevel::UpdLock` on the specific instance over `LockTable()` (which affects all reads of that table for the rest of the transaction) [LC0031]. `FindSet(true)` when modifying in the loop. Read setup before starting writes. Keep transactions short.
- **Pages**: `OnAfterGetRecord`/`OnAfterGetCurrRecord` run per row rendered — no queries in loops, no DB writes, no `CurrPage.Update()`. Use a FlowField, a `Count()`, a page background task, or move to a FactBox/drill-down. Hidden (`Visible = false`) FlowFields still calculate.
- **Event subscribers** on frequent events (table OnAfterModify, posting line events): keep cheap, exit early on irrelevant records; subscriber codeunits small, `SingleInstance` where appropriate. Table-event subscribers make `ModifyAll`/`DeleteAll` row-by-row for everyone.
- **Text**: `TextBuilder` for concatenation in loops. `Dictionary`/`List` instead of temp tables for simple in-memory lookups.
- **Long work**: batch jobs → Job Queue / `TaskScheduler`, not a button the user waits on.
- **Reports/queries/API pages**: `DataAccessIntent = ReadOnly` where they don't write.
- Don't over-flag: a `Get` on a setup table or a loop over a 10-row config table is fine — say so if relevant.

---

## 4. Cleanliness & code smells (AL forms)

- **Nesting**: `if ... then begin if ... then begin ...` more than ~2 deep → guard clauses with `exit`, or extract the loop body into a local procedure where early `exit` works per item (or `continue` on runtime 15+). No `else` after `exit`/`Error`. No `= true`/`= false`. `case` for >2 alternatives on one value [AA0022]; `case true of` hiding complex branching is a smell.
  ```al
  // smell: 4 levels inside the repeat
  repeat
      if ServiceItem.Status = ServiceItem.Status::Installed then begin
          if Customer.Get(ServiceItem."Customer No.") then begin
              if Customer.Blocked = Customer.Blocked::" " then begin
                  ...
  // better
  repeat
      ProcessServiceItem(ServiceItem);
  until ServiceItem.Next() = 0;

  local procedure ProcessServiceItem(var ServiceItem: Record "Service Item")
  var
      Customer: Record Customer;
  begin
      if ServiceItem.Status <> ServiceItem.Status::Installed then
          exit;
      if not Customer.Get(ServiceItem."Customer No.") then
          exit;
      if Customer.Blocked <> Customer.Blocked::" " then
          exit;
      ...
  end;
  ```
- **Long procedures / god codeunits**: one "Mgt." codeunit doing UI, validation, posting and HTTP → split by responsibility (also makes subscriber codeunits cheaper to load). Cyclomatic complexity ≥8 [LC0010], cognitive complexity [LC0090].
- **Dead code**: unused variables [AA0137], unused local procedures [AA0228], assigned-never-read [AA0206], unreachable [AA0136], empty statements `if X then;` [LC0069], `var` params never modified [AA0150], unused parameters (no rule — check manually), commented-out code.
- **Magic values**: hardcoded G/L accounts, item numbers, posting groups, prices, URLs, object IDs [LC0003, LC0012] → setup table fields, enums, or `Locked` `Tok` labels. Use `Database::"X"`/`Codeunit::"Y"`, not integers.
- **Globals**: global record variables carry filters/state between procedures — prefer locals and parameters.
- **`with` statements**: deprecated; `NoImplicitWith` should be in `features` [AL0604/AL0606].
- **Suppressions**: `#pragma warning disable` without a restore and justification [AA0246 forbids disabling all].

---

## 5. Right-sizing in AL

Over-engineering patterns common in BC code — flag with the concrete simpler alternative:
- `interface` + single implementing codeunit + a "factory" codeunit, in a **PTE** with no second implementation planned → call the codeunit directly. (In AppSource, an interface/enum-implementation pair is justified when partners are meant to plug in alternatives.)
- Publishing `IntegrationEvent`s / `IsHandled` events "just in case" in a PTE nobody extends. In AppSource every public event/procedure is a breaking-change commitment.
- Setup tables/fields for values with one fixed answer, or generic `RecordRef`/`FieldRef` code where typed records work.
- Wrapper codeunits that forward one call; "Helper"/"Mgt."/"Handler" chains for one operation.

Under-engineering patterns to flag:
- Copy-pasted validation/posting blocks across pages/codeunits.
- Business logic in page triggers (`OnAction` with 40 lines) instead of a codeunit — untestable and unreusable.
- Hardcoded business values that belong in setup (G/L accounts, number series, rates).

---

## 6. Style & naming

Batch these; only raise what hurts readability or would fail the enabled analyzers.

- **Affixes**: all new objects carry the project's prefix/suffix (AppSource: mandatory [AS0011, AS0079]; PTE: strongly recommended). Fields/actions/controls/procedures added to *base-app* objects via extensions need the affix too. Namespaces (2+ levels) can replace object affixes for own objects in AppSource [AS0127]. Object names ≤ 30 characters.
- **Files**: `<ObjectNameWithoutSpaces>.<ObjectType>.al` (e.g. `ABCServiceContract.Table.al`, `ABCCustomerCard.PageExt.al`) [AA0215], organised by feature under `src/`, tests in a separate test app.
- **Variables**: PascalCase, no special characters [AA0100]; named after the type (`Customer: Record Customer;`, `SalesPost: Codeunit "Sales-Post"`) [AA0072]; `Temp` prefix only for temporary records [AA0073, AA0237].
- **Labels**: suffixes `Err`, `Msg`, `Qst`, `Lbl`, `Txt`, `Tok` [AA0074]; `Tok` labels `Locked = true` [LC0046]; placeholders documented with `Comment` [AA0470].
- **Pages**: every field and action has a `ToolTip` [AA0218]; field tooltips start with "Specifies …" [AA0219] (since 2024 wave 1 tooltips can live on the table field instead [AA0234] — don't duplicate); `ApplicationArea` on controls/actions [PTE0008, AS0062]; captions on fields/actions; `UsageCategory` on searchable pages [AW0006]; `Image` on actions [AW0005]; `AutoFormatType` on decimal amount fields [AA0471–AA0474].
- **Formatting**: lowercase keywords, 4-space indent, `begin..end` only around compound statements [AA0005], `begin` on the same line as `then`/`else`/`do` [AA0013], one statement per line, method calls with parentheses `Next()`, `FindSet()` [AA0008]. Object layout: properties → fields/layout/actions → triggers → global vars (labels, then variables) → procedures.
- **Modern features (check runtime first)**: `this.` (runtime 14+), ternary `?:` (2024 wave 2+), `continue` (runtime 15+), namespaces + `using`.

---

## 7. Platform best practices

### app.json
- `target: "Cloud"` for SaaS; `features` include `NoImplicitWith` (and `TranslationFile` for AppSource or multi-language customers).
- `application`/`platform` instead of explicit Base/System App dependencies [PTE0020, AS0100]; dependency versions are minimums.
- `idRanges` valid, non-overlapping [PTE0001, PTE0002].
- `runtime` not ahead of what the target BC version supports; not so old that useful features are unavailable [LC0033].
- Changing `id` orphans data; renaming `name`/`publisher` breaks dependents.

### Extending the base app
- `tableextension` for data that must be on the base record (shown in lists, filtered, searched); otherwise a related table + FlowField. All table extensions on one table share one companion table (one join).
- `pageextension`: `addlast`/`addfirst`/anchor to stable controls; affix added controls/actions.
- Subscribe to the most specific event; check `IsTemporary`, document type, and context early.

### Install / upgrade
- Install codeunit `Subtype = Install`; per-company setup also handled via `Company-Initialize` `OnCompanyInitialize` [AA0235].
- Upgrade codeunit `Subtype = Upgrade`; every step guarded by upgrade tags (`HasUpgradeTag` → work → `SetUpgradeTag`; register tags; set them on install). Steps must be idempotent and order-independent. `DataTransfer` for bulk copies. `Access = Internal` [LC0030].
- Field type changes, removals, renames on published tables: obsolete first (`ObsoleteState = Pending` + `ObsoleteReason` + `ObsoleteTag`, later `Removed`) [AA0213, AS0115]; PTE cannot move tables/fields [PTE0024].

### Tests
- A new extension with business logic and no test app is a **Major** finding for anything posting/financial, Minor otherwise — recommend the most valuable 2–3 test scenarios rather than "add tests".
- Test codeunits: `Subtype = Test`, `[Test]` procedures, `// [SCENARIO] / [GIVEN] / [WHEN] / [THEN]` comments, `Initialize()` pattern, `Library Assert`, standard library codeunits for data, `[HandlerFunctions(...)]` for UI, mocked HTTP. Assert functions never in production code [PTE0007, AS0058].

### Translation
- `TranslationFile` feature; commit `.g.xlf` + target `.xlf` files per locale; never translate `Locked` labels; renaming controls/labels changes translation IDs.

---

## 8. Quick checklist

Run through this per file after the detailed pass; it catches the highest-impact AL issues.

**Blocker candidates**
- [ ] `DeleteAll`/`ModifyAll`/`Delete` on a record that could be non-temporary at any call site
- [ ] Secrets in code, labels, or plain table fields/pages
- [ ] `Commit()` in a posting/release event subscriber or mid-process
- [ ] Record reused for a second `Insert` without clearing the primary key
- [ ] Unfiltered `ModifyAll`/`DeleteAll`/loop-with-Modify on a business table

**Major candidates**
- [ ] Direct assignment on base-app document/journal fields instead of `Validate`
- [ ] DB writes inside `[TryFunction]`; swallowed errors (`if not TryX() then;`)
- [ ] `SetFilter` with user/external text
- [ ] HTTP: http://, unchecked `Send`/`Post` result, JSON by concatenation
- [ ] N+1: `Get`/`Find`/`CalcSums` per row of a large loop; summing/counting by loop
- [ ] Heavy work in `OnAfterGetRecord`; `Message`/`Confirm` in posting or background code
- [ ] Accumulators/state not reset per iteration; data marked processed when it was skipped
- [ ] Missing permission set for new objects; `ToBeClassified` / personal data misclassified
- [ ] No tests for posting/financial logic

**Minor candidates**
- [ ] Nesting > 2–3 levels; procedures doing several things
- [ ] `Count() > 0` instead of `IsEmpty()`; missing `SetLoadFields` on wide tables
- [ ] `Option` instead of `enum`; magic numbers/G-L accounts; hardcoded URLs
- [ ] Error text by concatenation instead of Label; missing ToolTips/captions
- [ ] Unused variables/parameters; naming/affix/file-name inconsistencies
- [ ] Interface/factory/event publishers without a real consumer (over-engineering)
