#!/bin/sh
# Tests. Cases with prompt.md run a real Claude Code session (claude -p) in a fresh temp project
# with the skill installed as "rp", then check the files and the answer. Cases with check.sh only
# (no prompt.md) run without a model.
# Usage: tests/run.sh [case-id] [--runs N] [--model haiku|sonnet]
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CASES="$ROOT/tests/cases"
RUNS=2
MODEL=haiku
ONLY=""
TIMEOUT=900
DEFAULT_TOOLS='Read Glob Grep Write Bash(perl:*) Bash(ls:*) Bash(cat:*) Bash(mkdir:*) Bash(git worktree:*) Bash(git status:*) Bash(git rev-parse:*)'
# The converter is the same file as in mentor (xtompie/mentor). Copy it from there when it changes.
CONVERTER="$ROOT/skills/repro/scripts/session-text.pl"

while [ $# -gt 0 ]; do
    case "$1" in
        --runs) RUNS=$2; shift 2 ;;
        --model) MODEL=$2; shift 2 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) ONLY=$1; shift ;;
    esac
done

install() { # project dir
    mkdir -p "$1/.claude/skills/rp"
    cp -R "$ROOT/skills/repro/." "$1/.claude/skills/rp/"
    sed -e 's/^name: repro$/name: rp/' -e 's#/repro#/rp#g' "$ROOT/skills/repro/SKILL.md" > "$1/.claude/skills/rp/SKILL.md"
}

total_fail=0
for dir in "$CASES"/*/; do
    id=$(basename "$dir")
    [ -n "$ONLY" ] && [ "$id" != "$ONLY" ] && continue
    if [ ! -f "$dir/prompt.md" ]; then
        if CONVERTER="$CONVERTER" FIXTURES="$ROOT/tests/fixtures" sh "$dir/check.sh"; then echo "$id pass"; else echo "$id fail"; total_fail=1; fi
        continue
    fi
    command -v claude >/dev/null 2>&1 || { echo "claude not found"; exit 2; }
    pass=0
    i=1
    while [ "$i" -le "$RUNS" ]; do
        p=$(mktemp -d "${TMPDIR:-/tmp}/repro-test.XXXXXX")
        (cd "$p" && git init -q && git commit -q --allow-empty -m init)
        install "$p"
        [ -f "$dir/setup.sh" ] && (cd "$p" && FIXTURES="$ROOT/tests/fixtures" env -u CLAUDE_CODE_MESSAGING_SOCKET -u CLAUDE_CODE_SESSION_ID -u CLAUDE_PID sh "$dir/setup.sh")
        tools=$DEFAULT_TOOLS
        [ -f "$dir/allowed-tools" ] && tools=$(cat "$dir/allowed-tools")
        stream="$p.stream"
        # shellcheck disable=SC2086
        (cd "$p" && env -u CLAUDE_CODE_MESSAGING_SOCKET -u CLAUDE_CODE_MESSAGING_TOKEN -u CLAUDE_CODE_SESSION_ID -u CLAUDE_PID \
            perl -e 'alarm shift; exec @ARGV' "$TIMEOUT" \
            claude -p "$(cat "$dir/prompt.md")" --model "$MODEL" --permission-mode default --output-format stream-json --verbose \
            --allowedTools $tools) > "$stream" 2>&1
        out="$p.out"
        perl -CS -MJSON::PP -ne 'my $j = eval { decode_json($_) } or next; print $j->{result} if ($j->{type} // "") eq "result"' "$stream" > "$out"
        reason=$(sh "$dir/check.sh" "$p" "$out" "$stream" 2>&1)
        ok=$?
        if [ "$ok" -eq 0 ]; then
            pass=$((pass + 1))
            echo "$id #$i pass"
            rm -rf "$stream"
        else
            echo "$id #$i fail $reason (log: $stream)"
        fi
        (cd "$p" && git worktree prune 2>/dev/null)
        rm -rf "$p" "$out"
        i=$((i + 1))
    done
    echo "$id $pass/$RUNS"
    [ "$pass" -lt "$RUNS" ] && total_fail=1
done
exit $total_fail
