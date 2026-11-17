#!/usr/bin/env perl
# Claude Code session (JSONL) to compact text for /mentor.
# Keeps what people said: user messages, assistant text (merged per message), one line per tool call,
# interrupts and rejected tool calls. Drops thinking, tool results, system reminders, meta lines.
# Trims long texts and long sessions, redacts obvious secrets and the home path.
# Usage: perl session-text.pl <session.jsonl>
use strict;
use warnings;
use JSON::PP;

my $MAX_USER = 1500;
my $MAX_ASSISTANT = 700;
my $MAX_TOOL = 160;
my $HEAD = 60;
my $TAIL = 140;

my $path = shift @ARGV // '';
if ($path eq '' || !-f $path) {
    print STDERR "Usage: perl session-text.pl <session.jsonl>\n";
    exit 2;
}

my $json = JSON::PP->new->utf8;
my (@turns, %assistant_at, %tool_name, %models);
my ($sid, $cwd, $first, $last_ts, $last_kind) = ('', '', '', '', '');

open my $fh, '<', $path or die "cannot read $path: $!\n";
while (my $line = <$fh>) {
    my $row = eval { $json->decode($line) } or next;
    next if ref $row ne 'HASH';
    $sid ||= $row->{sessionId} // '';
    $cwd ||= $row->{cwd} // '';
    if (defined $row->{timestamp}) { $first ||= $row->{timestamp}; $last_ts = $row->{timestamp}; }
    next if $row->{isSidechain};
    my $type = $row->{type} // '';
    my $content = ref $row->{message} eq 'HASH' ? $row->{message}{content} : undef;

    if ($type eq 'assistant' && ref $content eq 'ARRAY') {
        if ($row->{isApiErrorMessage}) { $last_kind = 'api-error'; next; }
        $models{$row->{message}{model}} = 1 if $row->{message}{model};
        my $id = $row->{message}{id} // $row->{uuid} // '';
        for my $b (@$content) {
            next if ref $b ne 'HASH';
            my $bt = $b->{type} // '';
            if ($bt eq 'text' && ($b->{text} // '') =~ /\S/) {
                if (!exists $assistant_at{$id}) {
                    $assistant_at{$id} = scalar @turns;
                    push @turns, { role => 'assistant', text => '', tools => [] };
                }
                my $t = $turns[$assistant_at{$id}];
                $t->{text} = $t->{text} eq '' ? $b->{text} : "$t->{text}\n$b->{text}";
            } elsif ($bt eq 'tool_use') {
                $tool_name{$b->{id} // ''} = $b->{name} // '';
                if (!exists $assistant_at{$id}) {
                    $assistant_at{$id} = scalar @turns;
                    push @turns, { role => 'assistant', text => '', tools => [] };
                }
                push @{ $turns[$assistant_at{$id}]{tools} }, tool_line($b);
            }
        }
        $last_kind = 'assistant';
        next;
    }

    next if $type ne 'user' || $row->{isMeta};
    if ($row->{isCompactSummary}) {
        push @turns, { role => 'note', text => '[conversation compacted here; summary omitted]' };
        next;
    }
    if (ref $content eq 'ARRAY') {
        for my $b (@$content) {
            next if ref $b ne 'HASH' || ($b->{type} // '') ne 'tool_result';
            my $res = ref $b->{content} eq 'ARRAY' ? join(' ', map { ref $_ eq 'HASH' ? ($_->{text} // '') : '' } @{ $b->{content} }) : ($b->{content} // '');
            if ($b->{is_error} && $res =~ /doesn't want to proceed|rejected|denied/i) {
                my $name = $tool_name{$b->{tool_use_id} // ''} // 'tool';
                push @turns, { role => 'rejected', text => "$name call rejected by the user" };
            }
        }
    }
    my $text = blocks_text($content);
    $text =~ s{<system-reminder>.*?</system-reminder>}{}gs;
    $text =~ s/^\s+|\s+$//g;
    next if $text eq '';
    next if $text =~ /^<(?:local-command-|bash-stdout|bash-stderr|task-notification)/ || $text =~ /^Base directory for this skill:/;
    if ($text =~ /^\[Request interrupted by user/) {
        push @turns, { role => 'interrupt', text => $text };
        $last_kind = 'interrupt';
        next;
    }
    if ($text =~ m{<command-name>([^<]*)</command-name>}) {
        my $name = $1;
        my ($args) = $text =~ m{<command-args>(.*?)</command-args>}s;
        push @turns, { role => 'command', text => trim("$name " . ($args // '')) };
        next;
    }
    if ($text =~ m{^<bash-input>(.*?)</bash-input>}s) {
        push @turns, { role => 'command', text => '! ' . trim($1) };
        next;
    }
    push @turns, { role => 'user', text => $text };
    $last_kind = 'user';
}
close $fh;

my $omitted = 0;
if (@turns > $HEAD + $TAIL) {
    $omitted = @turns - $HEAD - $TAIL;
    @turns = (@turns[0 .. $HEAD - 1], { role => 'note', text => "[$omitted turns omitted]" }, @turns[$#turns - $TAIL + 1 .. $#turns]);
}

binmode STDOUT, ':encoding(UTF-8)';
my $end = $last_kind eq 'assistant' ? 'completed' : $last_kind eq 'interrupt' ? 'user-abort' : $last_kind eq 'api-error' ? 'provider-error' : 'unknown';
printf "# session %s\n# project %s\n# time %s .. %s\n# models %s\n# end %s\n\n", $sid, redact($cwd), $first, $last_ts, join(', ', sort keys %models), $end;
my $n = 0;
for my $t (@turns) {
    my $r = $t->{role};
    if ($r eq 'assistant') {
        $n++;
        print "[$n] ASSISTANT: ", clip(redact($t->{text}), $MAX_ASSISTANT), "\n" if $t->{text} ne '';
        print "[$n] ASSISTANT: (tools only)\n" if $t->{text} eq '';
        print "    tool $_\n" for @{ $t->{tools} };
    } elsif ($r eq 'user') {
        $n++;
        print "[$n] USER: ", clip(redact($t->{text}), $MAX_USER), "\n";
    } elsif ($r eq 'command') {
        $n++;
        print "[$n] USER COMMAND: ", clip(redact($t->{text}), $MAX_USER), "\n";
    } elsif ($r eq 'interrupt') {
        $n++;
        print "[$n] USER INTERRUPTED\n";
    } elsif ($r eq 'rejected') {
        print "    ! $t->{text}\n";
    } else {
        print "$t->{text}\n";
    }
}

sub tool_line {
    my ($b) = @_;
    my $in = ref $b->{input} eq 'HASH' ? $b->{input} : {};
    my $arg = $in->{file_path} // $in->{path} // $in->{command} // $in->{pattern} // $in->{skill} // $in->{url} // $in->{description} // '';
    $arg =~ s/\s+/ /g;
    return ($b->{name} // '?') . ($arg ne '' ? ': ' . clip(redact($arg), $MAX_TOOL) : '');
}

sub blocks_text {
    my ($c) = @_;
    return $c if defined $c && !ref $c;
    return '' if ref $c ne 'ARRAY';
    return join "\n", map { (ref $_ eq 'HASH' && ($_->{type} // '') eq 'text') ? ($_->{text} // '') : () } @$c;
}

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s; }

sub clip {
    my ($s, $max) = @_;
    $s =~ s/\n{3,}/\n\n/g;
    return length $s > $max ? substr($s, 0, $max) . ' [...]' : $s;
}

sub redact {
    my ($s) = @_;
    my $home = $ENV{HOME} // '';
    $s =~ s/\Q$home\E/~/g if $home ne '';
    $s =~ s{(?:/Users|/home)/[^/\s"']+}{~}g;
    $s =~ s/-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?-----END [A-Z0-9 ]*PRIVATE KEY-----/[REDACTED:private-key]/gs;
    $s =~ s/\b(?:github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|sk_(?:live|test)_[A-Za-z0-9]{10,}|sk-[A-Za-z0-9_-]{20,})\b/[REDACTED:credential]/g;
    $s =~ s/\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/[REDACTED:jwt]/g;
    $s =~ s/\b(Bearer|Basic)\s+[A-Za-z0-9+\/_=.-]{8,}/$1 [REDACTED]/gi;
    $s =~ s{([a-z][a-z0-9+.-]*://)[^/\s:@]+:[^/\s@]+@}{$1\[REDACTED\]@}gi;
    $s =~ s/\b((?:api[_-]?key|access[_-]?token|refresh[_-]?token|token|password|passwd|secret|client[_-]?secret)\s*[:=]\s*)[^\s,;"']+/$1\[REDACTED\]/gi;
    return $s;
}
