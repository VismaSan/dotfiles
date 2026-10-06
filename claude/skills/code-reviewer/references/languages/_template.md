# Adding a Language Rule File

Create `references/languages/<lang>.md` and add a row to the detection table in `SKILL.md` (step 2) listing the file signals (extensions, manifest files) that should load it.

Keep the file to what's **specific to that language/platform** — `general.md` already covers universal principles, so don't repeat them. Use the same section order as `al.md` so reviewers can find things predictably:

```markdown
# <Language> Review Rules

## Contents

## 0. Context to gather first
<config files, linters/analyzers and how to tell which are enabled, target/runtime versions>

## 1. Correctness
## 2. Security
## 3. Performance & efficiency
## 4. Cleanliness & code smells   (language-specific forms of the general smells)
## 5. Right-sizing                (what over-engineering looks like in this ecosystem)
## 6. Style & naming
## 7. Platform best practices     (framework/packaging/testing/upgrade concerns)
## 8. Quick checklist
```

For each rule give: the check, **why** it matters (the consequence), a short bad → good snippet when it helps, and the linter rule ID if one exists (so the author can look it up or enable it). Prefer rules that catch real bugs over pure style.

If the file grows past ~400 lines, split it into `languages/<lang>/` with one file per section group and an index file the SKILL.md table points to.
