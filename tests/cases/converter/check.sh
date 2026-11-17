# No model: the converter turns the fixture into numbered turns with tool lines and a masked home path.
o=$(perl "$CONVERTER" "$FIXTURES/ignored.jsonl") || { echo "converter failed"; exit 1; }
echo "$o" | grep -q "^\[1\] USER: Fix the typo 'Welcom'" || { echo "first user turn missing"; exit 1; }
echo "$o" | grep -q "tool Edit: ~/site/gen/home.html" || { echo "tool line missing"; exit 1; }
echo "$o" | grep -q "/home/dev" && { echo "home path not masked"; exit 1; }
perl "$CONVERTER" /nonexistent >/dev/null 2>&1 && { echo "no error for a missing file"; exit 1; }
exit 0
