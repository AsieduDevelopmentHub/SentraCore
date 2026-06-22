## Repository Git Hooks

This repository uses **project-managed Git hooks** stored in `.githooks/` to enforce lightweight repository standards and maintain a clean commit history.

Git hooks are version-controlled so contributors share the same commit workflow and repository behavior.

---

### Enable Hooks

Run the following command once after cloning the repository:

```bash
git config core.hooksPath .githooks
```

Verify the configuration:

```bash
git config core.hooksPath
```

Expected output:

```text
.githooks
```

---

### Installed Hooks

| Hook | Purpose |
|---|---|
| `commit-msg` | Removes automatically generated `Co-authored-by: Cursor ...` trailers before commit finalization |
| `prepare-commit-msg` | Performs the same cleanup earlier in the commit creation flow (best effort) |

---

### Hook Workflow

```text
Create Commit
      ↓
prepare-commit-msg
      ↓
Edit Commit Message
      ↓
commit-msg
      ↓
Commit Finalized
```

---

### Why This Exists

These hooks help maintain:

- Consistent commit history
- Cleaner repository metadata
- Reduced commit message noise
- Predictable contributor workflows
- Repository-wide commit standards

The hooks only modify commit message metadata and never alter project source files.

---

### Disable Hooks

To restore Git’s default hook location:

```bash
git config --unset core.hooksPath
```

---

### Repository Structure

```text
.githooks/
├── commit-msg
└── prepare-commit-msg
```

---

### Notes

- Hooks run locally and are executed by Git.
- Hooks are not automatically enabled after cloning.
- Each contributor must enable hooks once per local repository clone.
- Hook execution may vary slightly across operating systems and Git versions.

---

### Validation

You can confirm hooks are active using:

```bash
git config --get core.hooksPath
```

Expected result:

```text
.githooks
```