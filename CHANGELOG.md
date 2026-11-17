# Changelog

The installed version is in `<skills dir>/repro/VERSION`. To upgrade, see "Upgrading" in `INSTALL.md`.

## 0.1.2

- Replays use the model the session used, read from its last assistant message. `--model` still overrides it. The run prints which model it uses.
- A replay of a moment with nothing before it starts a new session instead of failing to resume.
- `/repro` asks before reproducing, even with one suspect, unless you described the problem.
- Shell commands run one at a time, so plain permission mode does not reject them.
- Tests: allowed tools with spaces (`Bash(git worktree:*)`) are passed whole.

## 0.1.1

- README: a diagram that follows one problem through every step.
- Calmer color: muted vermilion #e2643f instead of #ff5a1f.

## 0.1.0

- First release: `/repro` reads a session, lists suspects with a cause (ignored, gap, operator, unknown), reproduces the chosen one in a git worktree with forked replays, proposes a text fix, proves it with the same runs, and applies it only on yes.
