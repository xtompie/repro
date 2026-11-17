# Lists the gen/ edit as the suspect with cause "ignored", does not count the creative "Join" change, asks which one, runs nothing.
grep -qi 'gen/' "$2" || { echo "suspect about gen/ missing"; exit 1; }
grep -qi 'ignored' "$2" || { echo "cause 'ignored' missing"; exit 1; }
grep -q '?' "$2" || { echo "does not ask which one"; exit 1; }
perl "$(dirname "$0")/../../bash-commands.pl" "$3" | grep -Eq 'runs\.pl|claude -p|worktree add' && { echo "started a reproduction before asking"; exit 1; }
[ "$(cat "$1/AGENTS.md")" = "$(printf "# Site\n\nNever edit files in gen/. They are generated. Change templates/ and run make gen.")" ] || { echo "changed AGENTS.md"; exit 1; }
exit 0
