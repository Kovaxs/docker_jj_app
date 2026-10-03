# Jujutsu (`jj`) cheat sheet

**Write code. Shape the history. Push when it makes sense.**

A practical reference for everyday work, selective commits, bookmarks, merging, recovery, and a few tricks worth learning.

Command syntax checked against **jj 0.45.1** on **2026-10-03**. Examples use `origin` and `main`; substitute your repository's names. Examples are independent recipes, not one script to run from top to bottom. Replace `CHANGE`, `SOURCE`, `TARGET`, and `OP_ID` with real IDs or bookmark names. Quote revsets containing shell punctuation.

## Contents

- [The mental model](#the-mental-model)
- [Everyday commands](#everyday-commands)
- [Start a repository](#start-a-repository)
- [Create commits and select files or lines](#create-commits-and-select-files-or-lines)
- [Create a branch and push it](#create-a-branch-and-push-it)
- [Fetch and rebase](#fetch-and-rebase)
- [Merge branches and resolve conflicts](#merge-branches-and-resolve-conflicts)
- [Amend, squash, and split](#amend-squash-and-split)
- [Undo, reflog, and recovery](#undo-reflog-and-recovery)
- [Discard changes or revert a commit](#discard-changes-or-revert-a-commit)
- [Cool tricks](#cool-tricks)
- [Revsets you will actually use](#revsets-you-will-actually-use)
- [Bookmarks and remotes](#bookmarks-and-remotes)
- [A comfortable Neovim setup](#a-comfortable-neovim-setup)
- [Git translation card](#git-translation-card)

## The mental model

| Concept   | Meaning                                                                    |
| --------- | -------------------------------------------------------------------------- |
| `@`       | The commit represented by your current working files.                      |
| `@-`      | Its parent; after `jj commit`, usually the commit you just finished.       |
| Change ID | The logical identity of a change; normally survives edits and rebases.     |
| Commit ID | A particular snapshot; changes when you rewrite a commit.                  |
| Bookmark  | A named pointer to a commit, corresponding to a Git branch.                |
| Operation | A recorded repository-state change, recoverable through the operation log. |

Your working copy is already a commit. Most `jj` commands snapshot tracked working files, and new non-ignored files are normally tracked automatically. There is no staging step. Set up `.gitignore` early.

**Creating another commit does not normally advance your bookmark.** Rewriting the commit a bookmark already points to does make the bookmark follow that rewritten commit.

```text
Before jj commit:               After jj commit:

@  Your edits                  @  Empty next change
○  Earlier commit              ○  Your finished commit (@-)
                               ○  Earlier commit
```

See [working-copy concepts](https://docs.jj-vcs.dev/latest/working-copy/) and [bookmarks](https://docs.jj-vcs.dev/latest/bookmarks/).

## Everyday commands

| Intent                            | Command                          |
| --------------------------------- | -------------------------------- |
| Status                            | `jj status`                      |
| Commit graph                      | `jj log`                         |
| Include all visible history       | `jj log -r 'all()'`              |
| Current diff                      | `jj diff`                        |
| File summary                      | `jj diff --summary`              |
| Inspect a commit                  | `jj show CHANGE`                 |
| Diff of a particular change       | `jj diff -r CHANGE`              |
| Combined difference from main     | `jj diff --from main --to @`     |
| Name the current change           | `jj describe -m "Add login"`     |
| Finish it and start the next      | `jj commit -m "Add login"`       |
| New change on a chosen base       | `jj new main`                    |
| Edit an existing change           | `jj edit CHANGE`                 |
| List bookmarks, including remotes | `jj bookmark list --all-remotes` |
| Undo / redo                       | `jj undo` / `jj redo`            |
| Help for any command              | `jj squash --help`               |

## Start a repository

Choose **one** starting point:

```bash
# Clone an existing GitHub repository
jj git clone --colocate git@github.com:YOUR_NAME/YOUR_REPO.git

# OR: initialize in a local project (also works with an existing Git repo)
jj git init --colocate
```

Set your identity once:

```bash
jj config set --user user.name "Your Name"
jj config set --user user.email "you@example.com"
```

For a new local project and an **empty** GitHub repository:

```bash
# Create/edit your project files first
jj status
jj commit -m "Initial commit"
jj bookmark create main -r @-
jj git remote add origin git@github.com:YOUR_NAME/YOUR_REPO.git
jj bookmark track main@origin
jj git push --remote origin --bookmark main
```

Create the GitHub repository without an initial README/license for this recipe. The SSH URL assumes GitHub SSH authentication; an HTTPS URL also works with suitable credentials.

Colocation lets Git tools use the same directory. Check it with `jj git colocation status`; enable it in an existing jj repository with `jj git colocation enable`. Git may be in detached HEAD. Finish any Git merge/rebase before resuming jj, and resolve jj's conflicted commits with jj. [Git compatibility](https://docs.jj-vcs.dev/latest/git-compatibility/)

## Create commits and select files or lines

**Everything in `@`:**

```bash
jj commit -m "Add login page"
```

Equivalent everyday sequence:

```bash
jj describe -m "Add login page"
jj new
```

**A few files:**

```bash
jj commit -m "Add login page" src/login.ts tests/login.test.ts
```

**Choose files, hunks, or lines interactively:**

```bash
jj commit -i --tool :builtin -m "Add login page"
```

Selected changes form the finished commit at `@-`; leftovers stay in `@`. No extra `jj new` is needed. With `ui.diff-editor = ":builtin"`, you can omit `--tool :builtin`.

Prefer naming your work before selecting? Use `jj describe -m "Add login page"`, then `jj commit -i`. The existing description is carried into the commit workflow; an editor may open when you omit `-m`.

```bash
jj show @- --git    # Check the finished commit
jj diff --git      # Check what remains
```

**Watch the message target:** `jj commit -m "Done"` names the change you are leaving; `jj new -m "Next task"` names the new change you are starting.

## Create a branch and push it

You can work without a branch name and attach a bookmark when ready to publish:

```bash
jj git fetch --remote origin
jj new main@origin

# Edit files
jj commit -m "Add search"

jj bookmark create feature-search -r @-
jj bookmark track feature-search@origin
jj git push --remote origin --bookmark feature-search
```

Continue working on its new child `@`, then advance the bookmark:

```bash
# Edit files
jj commit -m "Test search edge cases"
jj bookmark set feature-search -r @-
jj git push --remote origin --bookmark feature-search
```

To start more work from that branch later:

```bash
jj new feature-search
```

`jj new feature-search` starts a child; `jj edit feature-search` edits the bookmarked commit itself. To resume unfinished work, use `jj edit` with that unfinished change's ID.

In 0.45.1, explicit `--bookmark` pushes automatically track a new bookmark; the explicit `bookmark track` step above also makes the relationship clear and supports older workflows.

**Remote rule:** rewriting your own feature branch is usually fine when its policy allows it. Shared/protected branches need coordination or new commits. `jj git push` handles rewritten history with a remote-state check similar to `git push --force-with-lease`. If rejected because the remote changed, fetch and inspect before deciding how to reconcile. [GitHub workflow](https://docs.jj-vcs.dev/latest/github/)

## Fetch and rebase

Fetch updates, then move your feature stack onto the latest main:

```bash
jj git fetch --remote origin
jj rebase -b feature-search -o main@origin
jj git push --remote origin --bookmark feature-search
```

Choose what moves:

| Command                                      | Scope                                                                                       |
| -------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `jj rebase -b feature-search -o main@origin` | The branch relative to the destination, including descendants of its selected base commits. |
| `jj rebase -s CHANGE -o main@origin`         | That change and all its descendants.                                                        |
| `jj rebase -r CHANGE -o main@origin`         | Only that change; its old children are reattached to its old parents.                       |

Use `jj log` afterward to check the graph. `-o` means `--onto`; you may see the older alias `-d` in tutorials.

## Merge branches and resolve conflicts

For a repository where you may update `main` directly, and local `main` is up to date:

```bash
jj new main feature-search
jj describe -m "Merge feature-search"

jj resolve --list
# If conflicts exist:
jj resolve
# Or edit the conflict markers manually and save the files

jj status
# Run your project checks; proceed once conflicts are resolved
jj bookmark set main -r @
jj new
jj git push --remote origin --bookmark main
```

Multiple parents to `jj new` create a merge commit. There is no `jj merge --continue`: resolved file contents are snapshotted normally. For protected `main`, push your feature and merge through the repository's PR process.

If `main` is already an ancestor of the feature tip, simply fast-forward the bookmark instead:

```bash
jj bookmark set main -r feature-search
jj git push --remote origin --bookmark main
```

Find conflicts anywhere in visible history:

```bash
jj log -r 'conflicts()'
jj edit CHANGE
jj resolve
```

Conflicts can be stored in commits, so a rebase can finish with conflicts that still need resolution. Check the result rather than expecting Git's paused-rebase workflow. [Conflict guide](https://docs.jj-vcs.dev/latest/conflicts/)

## Amend, squash, and split

### Amend a message or an existing change

```bash
jj describe -r @- -m "Better commit message"

# Or edit an existing commit's files directly
jj edit CHANGE
# Edit files
jj new
```

Descendants are rebased automatically after a rewrite. If you left unfinished work in a child, record its change ID first and return with `jj edit CHILD_ID` instead of creating another child with `jj new`.

### Move changes into another commit

```bash
jj squash -u                          # All of @ into @-
jj squash -i -u                       # Select pieces of @ for @-
jj squash -u src/login.ts              # One file's changes into @-
jj squash --into CHANGE -i -u          # Selected changes into an older commit
jj squash --from SOURCE --into TARGET -u
jj squash -m "Combined implementation" # Supply a new destination message
```

`-u` keeps the destination's message. Unselected changes remain in the source. An emptied source is normally abandoned; `--keep-emptied` retains it. If `@` is abandoned, jj supplies a new working commit.

**Direction matters:** plain `jj squash` sends `@` into its parent. `jj squash --from CHANGE` sends that change into `@`.

### Split a mixed commit after the fact

```bash
jj split -r CHANGE --tool :builtin

# Or split by file without an interactive editor
jj split -r CHANGE src/login.ts -m "Add login implementation"
```

Selected changes form the first commit; the remainder becomes its child. Unlike `jj commit`, ordinary `jj split` moves bookmarks on the original change forward to the child, keeping the full stack under the bookmark.

## Undo, reflog, and recovery

| Need                                    | Command                |
| --------------------------------------- | ---------------------- |
| Undo your latest repository operation   | `jj undo`              |
| Redo what you just undid                | `jj redo`              |
| See repository operations (reflog-like) | `jj op log`            |
| Inspect an operation                    | `jj op show OP_ID`     |
| See the graph at an old operation       | `jj --at-op OP_ID log` |
| Restore that local repository state     | `jj op restore OP_ID`  |
| See past versions of one logical change | `jj evolog -r CHANGE`  |

Two histories: `jj log` tracks commits; `jj op log` tracks actions such as rebase, squash, and bookmark moves. `jj evolog` follows rewrites of one change.

Preview an old state before restoring it. Undo and operation restore affect local state; **they do not undo a push on GitHub**. Operation history also cannot recover unsaved editor text or files jj never snapshotted, such as ignored files. [Operation-log guide](https://docs.jj-vcs.dev/latest/operation-log/)

## Discard changes or revert a commit

These commands discard local content; inspect `jj diff` first.

```bash
jj restore src/login.ts       # Reset that file to @'s parent version
jj restore                    # Reset all files; keep @ and its message
jj abandon CHANGE             # Remove a commit's changes; rebase its descendants
```

Discard all descendants of `@`, while keeping `@`:

```bash
jj log -r '@:: ~ @'            # Preview the exact set
jj abandon '@:: ~ @'
```

This includes every descendant branch, not everything visually above `@`. Abandoning a bookmarked commit normally deletes its bookmark; `--retain-bookmarks` moves it to the parent instead. Immutable commits are protected by default.

For shared history, create a reversal commit instead of rewriting the original:

```bash
jj revert -r CHANGE -o main@origin
jj log                        # Locate the new reversal commit
jj bookmark create revert-fix -r REVERT_CHANGE_ID
jj git push --remote origin --bookmark revert-fix
```

The reversal can be reviewed through a PR. `jj revert` creates a new commit; inspect its ID rather than assuming it changed `@`.

## Cool tricks

### 1. Fix several old commits at once

Make small fixes in `@` on top of your stack, then:

```bash
jj absorb
jj op show -p
jj diff
```

Absorb assigns edits to mutable ancestor commits based on which ones last changed the affected lines. Ambiguous edits stay in `@`. Inspect the operation's patch and leftovers. This can replace several manual fixup commits and an autosquash rebase.

### 2. Switch tasks without a stash

```bash
jj describe -m "WIP: search"
jj log                        # Note @'s change ID
jj new main@origin
# Work on something else
jj edit WIP_CHANGE_ID          # Resume the saved work
```

Your unfinished change stays in history while you work elsewhere.

### 3. Publish without inventing a branch name

After finishing a commit:

```bash
jj git push --remote origin --change @-
```

jj generates and tracks a bookmark for that change.

### 4. Cherry-pick without moving the original

```bash
jj duplicate CHANGE -o main@origin
jj log
```

This copies the change onto a new base with a new change ID. Attach a bookmark to the resulting commit when ready to push. Use `rebase` when you want to move the original instead.

### 5. Insert a missing step into your stack

```bash
jj new --before CHANGE -m "Add prerequisite validation"
# Edit files; descendants automatically follow the inserted commit
```

No need to rebuild the stack by hand. Inspect descendants for conflicts after editing.

### 6. Work in two directories

```bash
jj workspace add ../project-hotfix -r main@origin
jj workspace list
```

Each workspace has its own working commit, sharing repository history. After another workspace rewrites your base, a stale workspace can be refreshed with `jj workspace update-stale`.

## Revsets you will actually use

Revsets select commits. Use them first with `jj log -r` before using a broad set in a modifying command.

| Expression           | Selects                                                |
| -------------------- | ------------------------------------------------------ |
| `@`                  | Current working commit                                 |
| `@-` / `@--`         | Parent / grandparent in a linear stack                 |
| `@+`                 | Direct children; can be more than one                  |
| `::@`                | Current commit and its ancestors                       |
| `@::`                | Current commit and its descendants                     |
| `@:: ~ @`            | Descendants, excluding current commit                  |
| `main..@`            | Ancestors of `@` that are not ancestors of `main`      |
| `A::B`               | Commits descended from A and ancestral to B, inclusive |
| `A \| B`             | Union of two sets                                      |
| `A ~ B`              | Set A excluding set B                                  |
| `bookmarks()`        | Commits pointed to by local bookmarks                  |
| `conflicts()`        | Conflicted commits                                     |
| `mine() & mutable()` | Your mutable commits                                   |

```bash
jj log -r 'main@origin..@'
jj log -r 'mine() & mutable()'
jj log -r 'description("login")'
```

The highlighted ID prefix is normally enough to identify a change. Older tutorials use an `all:` modifier for multiple revisions; **jj 0.45.1 no longer accepts that modifier**. Use the revset directly in commands that accept sets, as above. [Revset reference](https://docs.jj-vcs.dev/latest/revsets/)

## Bookmarks and remotes

```bash
jj bookmark list --all-remotes
jj bookmark create feature-name -r CHANGE
jj bookmark set feature-name -r @-       # Create or move
jj bookmark rename feature-name new-name
jj bookmark track feature-name@origin
jj git remote list
jj git remote add upstream REPOSITORY_URL
jj git fetch --remote origin
jj git push --remote origin --bookmark feature-name --dry-run
```

Deleting a bookmark does not delete its commits:

```bash
jj bookmark delete feature-name
jj git push --remote origin --bookmark feature-name
```

The push propagates deletion of a tracked remote bookmark. To forget the local bookmark and its tracking relationship **without deleting the remote branch**, use `jj bookmark forget feature-name` instead.

## A comfortable Neovim setup

Run `jj config edit --user`. Merge these sections with any existing ones rather than duplicating table headers:

```toml
[ui]
editor = "nvim"
diff-formatter = ":git"
diff-editor = ":builtin"
merge-editor = "vimdiff"

[colors]
rest = "default"

[merge-tools.vimdiff]
program = "nvim"

[merge-tools.nvim_difftool]
program = "nvim"
diff-args = ["-d", "$left", "$right"]
diff-invocation-mode = "file-by-file"
edit-args = ["-d", "$left", "$right"]
edit-invocation-mode = "file-by-file"

[aliases]
st = ["status"]
ci = ["commit"]
amend = ["squash", "--use-destination-message"]
pick = ["commit", "--interactive", "--tool", ":builtin"]
```

`rest = "default"` makes the faint tail of IDs use your terminal's normal foreground. Terminal diffs and interactive selection stay separate from your Neovim merge tool. [Configuration reference](https://docs.jj-vcs.dev/latest/config/)

```bash
jj diff                                            # Terminal diff
jj diff --git --no-pager                            # Bypass external diff tool/pager
jj pick -m "Selected changes"                      # File/hunk/line selector
jj diff --tool nvim_difftool --no-pager src/login.ts
jj resolve                                         # Neovim conflict resolver
```

For detailed interactive editing of a particular file:

```bash
jj commit --tool nvim_difftool -m "Selected fix" src/login.ts
```

Edit the temporary **right** buffer to contain only the desired commit contents. Save it and exit Neovim; omitted changes remain in the next working commit. This tool visits files individually, so prefer `:builtin` when selecting across many files. The plain `nvim -d` configuration avoids requiring the optional `nvim.difftool` runtime plugin.

## Git translation card

These are workflow analogies, not identical state models. For amend examples, think of jj's `@` as Git's working edits and `@-` as Git's `HEAD`.

| Git habit                      | jj workflow                                                     |
| ------------------------------ | --------------------------------------------------------------- |
| `git status`                   | `jj status`                                                     |
| `git log --graph`              | `jj log`                                                        |
| `git add -A` + `git commit`    | `jj commit -m "Message"`                                        |
| `git add -p` + `git commit`    | `jj commit -i -m "Message"`                                     |
| Start a branch                 | `jj new main`, then create a bookmark when needed               |
| `git commit --amend`           | `jj squash` for new edits; `jj describe` for the message        |
| Fixup + autosquash             | `jj squash --into CHANGE` or `jj absorb`                        |
| `git rebase main`              | `jj rebase -b feature -o main`                                  |
| `git merge feature`            | `jj new main feature`, then move `main`                         |
| `git cherry-pick CHANGE`       | `jj duplicate CHANGE -o TARGET`                                 |
| `git stash` / resume           | Leave the WIP change with `jj new`; return with `jj edit`       |
| `git reflog`                   | `jj op log` for operations; `jj evolog` for a change's rewrites |
| `git restore path`             | `jj restore path`                                               |
| Push rewritten feature history | `jj git push --bookmark feature`                                |

See the [official Git command comparison](https://docs.jj-vcs.dev/latest/git-command-table/) and [full CLI reference](https://docs.jj-vcs.dev/latest/cli-reference/). Your installed `jj COMMAND --help` is the best authority when versions differ.
