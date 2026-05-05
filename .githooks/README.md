## Repo git hooks

This repository keeps git hooks in `.githooks/`.

### Enable

Run this once in the repo:

```bash
git config core.hooksPath .githooks
```

### What it does

- `commit-msg`: removes any `Co-authored-by: Cursor ...` trailer lines from commit messages.
- `prepare-commit-msg`: same removal earlier in the flow (best-effort).

