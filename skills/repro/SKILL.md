---
name: repro
description: Find where a Claude Code session went wrong, reproduce it in a sandbox, and fix the prompt. Tells a model that ignored its instructions from a missing or vague instruction, or a vague operator. Proposes a text fix, proves it with reruns, and changes nothing until the user says yes.
argument-hint: "[session id or path] [what went wrong]"
disable-model-invocation: true
---

Talk in the user's language. Ask one question at a time. Never edit the user's files before step 8.

## 1. Read the session

- No session given: this session, id `${CLAUDE_SESSION_ID}`.
- An argument that ends in `.jsonl` or contains `/` is a file path: use it. Anything else is a session id: find the file with `ls ~/.claude/projects/*/<id>.jsonl`. Several: take them one by one.
- Convert it: `perl ${CLAUDE_SKILL_DIR}/scripts/session-text.pl <file>`. Read the output, not the JSONL. Turn numbers like `[12]` are how you point at moments.
- Note which instructions were in play: the skills that ran, `AGENTS.md`, `CLAUDE.md`, docs the model read. Read them.

## 2. Find suspects

If the user said what went wrong, go to that moment. Otherwise list moments where the result differed from what the user wanted: corrections, interrupts, rejected tool calls, "done" followed by a failure, an instruction broken in plain sight.

For each suspect pick one cause. Read `${CLAUDE_SKILL_DIR}/references/causes.md` first.

- **ignored**: a clear instruction was loaded and the model did otherwise.
- **gap**: the instruction was missing or imprecise; the model did a reasonable thing with what it had.
- **operator**: the user was vague, contradictory, or expected something never said.
- **unknown**: the session does not show which.

A cause is a hypothesis. The reproduction tests it.

## 3. Ask which one

Show the suspects as a short list: turn, what happened, cause, one line of evidence. Ask which one to work on. Stop and wait.

## 4. Operator cause

Say plainly what was unclear or contradictory, with the turns. Give the sentence the user could say next time, ready to paste. If the same thing will come up again, offer one line for the project docs. No reproduction. Stop.

## 5. Reproduce

Read `${CLAUDE_SKILL_DIR}/references/reproduce.md` and follow it. In short:

1. Write down the expected result in one sentence before any run. For a gap, the user's final correction is the expected result.
2. Make a sandbox inside the project: `git worktree add --detach .repro/<short id>`, plus any uncommitted files the moment depends on. Keep the cut session, the prompt file and the outputs in `.repro/` too.
3. Cut the session just before the failing user message: `perl ${CLAUDE_SKILL_DIR}/scripts/cut.pl <session.jsonl> <cut.jsonl> --before "<start of that user message>"`.
4. Run it: `perl ${CLAUDE_SKILL_DIR}/scripts/runs.pl --dir .repro/<short id> --session <cut.jsonl> --prompt <prompt file> --runs 5 --out <out dir>`. Add `--model <name>` if the user asked for another model.
5. Judge every run against the expected result. Count failures.

0 failures: the problem does not reproduce. Say so and stop. 1 to 3 of 5: sharpen the reproduction or go to 10 runs before and after.

## 6. Propose the fix

Change the text, not the model. Name the one file that owns the rule: the skill, `AGENTS.md`, a doc. The smallest change that says the missing thing plainly. For **ignored**, keep the meaning and change the form or the place: shorter, earlier, a concrete example, a check.

## 7. Prove it

Put the fix into the sandbox and run the same prompt the same number of times. If the fixed text was loaded earlier in the session, the cut session still holds the old text: give the new text with `cut.pl --replace <old file> <new file>`, and say so. 5 of 5 failing before and 0 of 5 after is enough. Anything weaker: say how strong the result is.

## 8. Apply on yes

Show the diff and the counts before and after. Ask whether to apply it to the real file. Apply only on yes. Then remove the sandbox: `git worktree remove --force .repro/<short id>`, then delete `.repro/`. Tests are not kept.
