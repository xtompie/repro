# A real session with an instruction gap: AGENTS.md says nothing about where reports go.
printf '# Shop\n\nReports are short Markdown files.\n' > AGENTS.md
printf 'A tiny shop app.\n' > README.md
git add AGENTS.md README.md && git commit -q -m base
id=$(claude -p "Write a three-line report about this project to a Markdown file." --model haiku --permission-mode acceptEdits --output-format json < /dev/null | perl -MJSON::PP -0ne 'print decode_json($_)->{session_id}')
claude -p --resume "$id" "No, reports go in the reports/ folder. Move it there." --model haiku --permission-mode acceptEdits --allowedTools "Bash(mkdir:*)" "Bash(mv:*)" "Bash(git mv:*)" < /dev/null > /dev/null 2>&1
cp "$(ls ~/.claude/projects/*/"$id".jsonl)" session.jsonl
git clean -fdq -e session.jsonl -e .claude
git checkout -q -- .
