## Repository Git Hooks

This repository uses **project-managed Git hooks** stored in `.githooks/` to enforce lightweight repository standards and maintain a clean commit history.

Git hooks are version-controlled so contributors share the same commit workflow and repository behavior.

---

### Enable Hooks

Run the following command once after cloning the repository:

```bash
git config core.hooksPath .githooks

```

Verify:

git config core.hooksPath

Expected output:

.githooks

---

Installed Hooks

Hook| Purpose
"commit-msg"| Removes automatically generated "Co-authored-by: Cursor ..." trailers before commit finalization
"prepare-commit-msg"| Performs the same cleanup earlier in the commit creation flow (best effort)

---

Why This Exists

These hooks help maintain:

- Consistent commit history
- Cleaner repository metadata
- Reduced commit message noise
- Predictable contributor workflows

The hooks only modify commit message metadata and do not alter source files.

---

Disable Hooks

To revert to Git’s default hook location:

git config --unset core.hooksPath

---

Repository Structure

.githooks/
├── commit-msg
└── prepare-commit-msg

---

Notes

- Hooks are executed locally by Git.
- Hooks are not automatically enabled after cloning.
- Each contributor must enable hooks once per local repository clone.
- Hook execution behavior may vary slightly across operating systems and Git versions.