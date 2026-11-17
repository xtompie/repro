# The user asked for tabs, then said they had asked for spaces: an operator cause. Says so and gives a sentence. No reproduction.
grep -qi 'tab' "$2" && grep -Eqi 'space|spacj' "$2" || { echo "does not name both tabs and spaces"; exit 1; }
grep -Eqi 'operator|contradict|sprzeczn|you asked|you said|your (first|own)|poprosiłeś|napisałeś' "$2" || { echo "does not point at the operator"; exit 1; }
perl "$(dirname "$0")/../../bash-commands.pl" "$3" | grep -Eq 'runs\.pl|claude -p|worktree add' && { echo "reproduced an operator issue"; exit 1; }
exit 0
