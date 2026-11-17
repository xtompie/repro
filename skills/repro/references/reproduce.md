# Reproducing a moment

## The expected result

Write it down before the first run, in one sentence that a run either meets or not. Example: "The report is written to `reports/`, not to the project root." For a gap, take it from the user's last correction.

## The sandbox

- `git worktree add --detach .repro/<short id>` from the project root. Inside the project, because writing outside it asks for permission every time.
- A worktree has the committed files only. Copy into it any uncommitted file the moment depends on.
- The fix goes into the sandbox, never into the real files, until step 8.
- Remove it at the end: `git worktree remove --force .repro/<short id>`, then delete `.repro/`.
- User-level skills (`~/.claude/skills/`) win over project skills with the same name, so a sandbox cannot swap them. For a fix to a user-level skill, give the new text in the replayed session with `cut.pl --replace`, and say this is how it was tested.

## Cutting the session

`perl cut.pl <session.jsonl> <cut.jsonl> --before "<start of the failing user message>"`

- Keeps every line before that user message, so the run has the real context up to that point.
- `--replace <old file> <new file>` swaps text everywhere in the copy. Use it when the fixed instruction was loaded earlier in the session (a skill body, a file the model read), or the run would still see the old text.
- The real session file is never changed.

## Running

`perl runs.pl --dir <sandbox> --session <cut.jsonl> --prompt <prompt file> --runs <n> --out <out dir> [--model <name>]`

- The prompt file holds the failing user message, as the user wrote it.
- Each run resumes a fork of the cut session inside the sandbox, so the runs do not change the original and do not see each other.
- Runs use `--permission-mode acceptEdits`: file edits in the throwaway sandbox are allowed, everything else follows the user's own settings. If a run stops on a permission, say which and ask.
- For each run `<out dir>` gets `run-<n>.txt` (the answer) and `run-<n>.tools` (one line per tool call). Judge from these.

## How many runs

- Start with 5.
- 5 of 5 failing before and 0 of 5 after: the fix works (p about 0.004).
- 3 of 3 against 0 of 3 is borderline. Do not stop there.
- Fails only 2 or 3 of 5 before: sharpen the reproduction (cut closer, a clearer expected result) or use 10 and 10.
- 0 failures in 10 runs still allows a failure rate up to about 26%. Say so when it matters.
- A smaller model fails more often, which makes a gap easier to see. Use it only if the user agrees.
