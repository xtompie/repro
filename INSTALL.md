# Installing repro: instructions for an AI agent

You are an AI coding agent. The user asked you to install repro. Ask one question at a time and wait for the answer. Talk in the user's language.

## 1. Get the files

```bash
git clone --depth 1 https://github.com/xtompie/repro.git /tmp/repro-install
```

## 2. Ask

1. **For your user or for this project?** Recommend user.
   - User (recommended): `~/.claude/skills/repro/`. repro works on any session, so it is useful in every project.
   - Project: `<project>/.claude/skills/repro/`. Anyone who clones the repo gets it. A user skill with the same name wins over it.
2. **Name?** Suggest `repro` (`/repro`).

## 3. Copy

Let `<skills-dir>` be the chosen folder and `<name>` the name.

```bash
mkdir -p <skills-dir>/<name>
cp -R /tmp/repro-install/skills/repro/. <skills-dir>/<name>/
cp /tmp/repro-install/VERSION <skills-dir>/<name>/VERSION
```

- If `<name>` is not `repro`, change the `name:` line in `SKILL.md` and every `/repro` mention in the copied files.
- If a skill with this name already exists, stop and ask.

## 4. Check

```bash
perl <skills-dir>/<name>/scripts/session-text.pl /nonexistent
```

It should print a usage line, which shows that `perl` and its core modules work. Remove `/tmp/repro-install`.

## 5. Explain

Tell the user briefly:

- `/<name>` after a session that went wrong, or `/<name> <session id> <what went wrong>`.
- It lists suspects with a cause, reproduces the one you pick in a worktree, proposes a fix and proves it with reruns.
- Nothing changes in your files until you say yes.

If you installed into a project, ask whether to commit. Never push without being asked.

## Upgrading

When repro is already installed (`<skills-dir>/<name>/SKILL.md` exists):

1. Read the installed version from `<skills-dir>/<name>/VERSION`.
2. Get the files (step 1) and read `CHANGELOG.md`. Take every version newer than the installed one.
3. Copy the skill folder and `VERSION` again, as in step 3, with the same `<name>`. Remove files the repo no longer has.
4. Do the "Upgrade" steps of each newer version, oldest first.
5. Tell the user what changed, in a few lines, from the changelog.
