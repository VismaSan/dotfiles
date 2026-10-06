# Delivering the Review

## Contents
1. Confirm before posting
2. Posting inline comments on a GitHub PR
3. Chat report (fallback)

---

## 1. Confirm before posting

A posted review is visible to the whole team and notifies people, so the user sees it first. Show the full chat report (section 3), then ask something like: "Post these N findings as inline comments on PR #123?" Respect partial answers ("only Blockers and Majors", "skip the Minors", "drop #7").

Post as a single review with event `COMMENT`. Don't use `APPROVE` or `REQUEST_CHANGES` unless the user asks — the verdict is theirs to give.

## 2. Posting inline comments on a GitHub PR

GitHub only accepts inline comments on lines that are part of the PR diff. A comment on any other line makes the whole request fail with HTTP 422, so sort findings first:

- **Line is in the diff** (an added/changed line, or a context line inside a hunk on the RIGHT side) → inline comment.
- **Line is outside the diff** (e.g. a caller in an untouched file) → put it in the review body under "Comments outside the diff", with `file:line`.

To check, look at `gh pr diff <n>` hunk headers (`@@ -a,b +c,d @@` → new-file lines `c` .. `c+d-1`).

### Build the payload

Write it to a file in the scratchpad (not the repo):

```json
{
  "commit_id": "<headRefOid from gh pr view>",
  "event": "COMMENT",
  "body": "<summary — see below>",
  "comments": [
    {
      "path": "src/Codeunits/SalesPosting.Codeunit.al",
      "line": 42,
      "side": "RIGHT",
      "body": "**[Major] Performance:** `Customer.Get` inside the loop over all sales lines (N+1).\n\n**Why:** ...\n\n**Fix:**\n```al\n...\n```"
    },
    {
      "path": "src/Tables/Setup.Table.al",
      "start_line": 10,
      "line": 18,
      "side": "RIGHT",
      "body": "..."
    }
  ]
}
```

- `path` is repo-relative, exactly as shown in the diff.
- Use `start_line` + `line` for a range; just `line` for one line.
- For a pattern repeated in many places, comment inline on the first one and list the others in that comment ("Same issue at: X.al:12, Y.al:88").

### Send it

```bash
gh api repos/{owner}/{repo}/pulls/<n>/reviews --method POST --input <payload.json>
```

(`{owner}/{repo}` is filled automatically by `gh` inside the repo.) The GitHub MCP tools (`pull_request_review_write` create → `add_comment_to_pending_review` → `submit_pending`) are an equivalent alternative.

If the call fails with 422, the error names the offending comment — move it to the body and retry rather than dropping it. Report the review URL to the user when done.

### Review body (summary)

```markdown
## Review summary
<1–3 sentences: overall assessment and the most important thing to fix>

| Severity | Count |
|---|---|
| Blocker | n |
| Major | n |
| Minor | n |

**Done well:** <1–3 items, if genuinely true>

### Comments outside the diff
- **[Major] Correctness** `path:line` — ...
```

## 3. Chat report (fallback)

Use when there's no PR, the remote isn't GitHub, the user declined posting, or as the preview before posting.

```markdown
## Code review: <scope — PR #n / branch / path>
Language rules applied: <general + al, ...>   Target: <e.g. PTE, runtime 14.0>

<1–3 sentence overall assessment>

### Blockers
1. **<Dimension>: <claim>** — `path:line`
   Why: ...
   Fix: ...

### Major
...

### Minor
...

### Done well
- ...
```

Number findings continuously across sections so the user can refer to them ("skip 4 and 9"). Omit empty sections.
