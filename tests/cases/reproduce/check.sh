# Reproduces with runs.pl before and after a fix, proposes a reports/ rule for AGENTS.md, and does not apply it.
n=$(perl "$(dirname "$0")/../../bash-commands.pl" "$3" | grep -c 'runs\.pl')
[ "$n" -ge 2 ] || { echo "runs.pl called $n times, expected before and after"; exit 1; }
perl "$(dirname "$0")/../../bash-commands.pl" "$3" | grep -q 'cut\.pl' || { echo "did not cut the session"; exit 1; }
grep -q 'reports/' "$2" || { echo "fix does not mention reports/"; exit 1; }
grep -q 'AGENTS.md' "$2" || { echo "does not name AGENTS.md as the owner"; exit 1; }
grep -q 'reports/' "$1/AGENTS.md" && { echo "applied the fix without a yes"; exit 1; }
exit 0
