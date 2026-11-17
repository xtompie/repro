# Telling the causes apart

Read the instruction that was loaded at that moment literally, word for word. Then pick one cause.

## ignored

The instruction was loaded, it was clear, and it covered this case. The model did otherwise.

- Evidence: quote the instruction and the action that broke it.
- The fix keeps the meaning and changes the form or the place: shorter, earlier in the file, a concrete example of right and wrong, or a check that fails loudly.

## gap

The instruction was missing, or it allowed several readings, and the model picked a reasonable one. The user then corrected it, often over several messages.

- Evidence: the instruction as written, and the user's correction.
- The user's last correction is the expected result for the reproduction. The model should reach it alone, without help.
- The fix adds the missing sentence, with names, paths, commands. Keep the contrast "X, not Y" when there was one.

## operator

The user was vague, contradicted an earlier message, used one word for two things, or expected something never said.

- Evidence: the two messages that disagree, or the expectation and where it was never stated.
- Say it without blame. Give the sentence to use next time.
- No reproduction: there is nothing in the instructions to fix.

## unknown

The session does not show which. Say what would decide it: a reproduction, or a question to the user. Do not guess.

## Notes

- Several causes can mix. Name the main one.
- A verdict is a hypothesis. People who label real sessions agree on the cause only about two times in three (Tang et al. 2026, 20,574 sessions: about 36% ignored a clear instruction, 15% ambiguous or missing instruction, 27% could not be decided). The reproduction is what makes it a finding.
- Creative iteration ("shorter", "another color") is not a failure.
