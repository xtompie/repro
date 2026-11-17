# Changelog

The installed version is in `<skills dir>/repro/VERSION`. To upgrade, see "Upgrading" in `INSTALL.md`.

## 0.1.1

- README: a diagram that follows one problem through every step.
- Calmer color: muted vermilion #e2643f instead of #ff5a1f.

## 0.1.0

- First release: `/repro` reads a session, lists suspects with a cause (ignored, gap, operator, unknown), reproduces the chosen one in a git worktree with forked replays, proposes a text fix, proves it with the same runs, and applies it only on yes.
