#!/usr/bin/env perl
# Replay one moment of a Claude Code session several times in a sandbox.
# Each run resumes a fork of the cut session inside the sandbox folder and sends the prompt.
# Writes run-<n>.txt (the answer) and run-<n>.tools (one line per tool call) into the out folder.
# Without --model the runs use the model the session itself used (its last assistant message), so the replay is faithful.
# Usage: perl runs.pl --dir <sandbox> --session <cut.jsonl> --prompt <file> --runs <n> --out <dir> [--model <name>] [--timeout <seconds>]
use strict;
use warnings;
use JSON::PP;
use Cwd qw(abs_path);

my %o = (runs => 5, timeout => 600);
while (@ARGV) {
    my $k = shift @ARGV;
    die "unknown argument: $k\n" if $k !~ /^--(dir|session|prompt|runs|out|model|timeout)$/;
    $o{$1} = shift @ARGV;
}
$o{model_given} = 1 if $o{model};
for my $need (qw(dir session prompt out)) {
    next if defined $o{$need};
    print STDERR "Usage: perl runs.pl --dir <sandbox> --session <cut.jsonl> --prompt <file> --runs <n> --out <dir> [--model <name>]\n";
    exit 2;
}
die "no sandbox folder $o{dir}\n" if !-d $o{dir};
die "no session file $o{session}\n" if !-f $o{session};
my $session = abs_path($o{session});
my $prompt = do { open my $h, '<:raw', $o{prompt} or die "cannot read $o{prompt}: $!\n"; local $/; <$h> };
mkdir $o{out} if !-d $o{out};
my $out = abs_path($o{out});

# The runs are new sessions; they must not think they are the session that started them.
delete $ENV{$_} for qw(CLAUDE_CODE_SESSION_ID CLAUDE_PID CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN);

binmode STDOUT, ":utf8";
my $json = JSON::PP->new->utf8;
my $turns = 0;
{
    open my $h, '<', $session or die "cannot read $session: $!\n";
    while (my $line = <$h>) {
        my $j = eval { $json->decode($line) } or next;
        my $type = $j->{type} // '';
        $turns++ if $type eq 'user' || $type eq 'assistant';
        next if $type ne 'assistant' || ref $j->{message} ne 'HASH';
        my $m = $j->{message}{model} // '';
        $o{model} = $m if !$o{model_given} && $m ne '' && $m !~ /^</;
    }
    close $h;
}
# Cut before the first message: there is no conversation to resume, so each run starts fresh.
print $turns ? "replaying after $turns earlier messages\n" : "no earlier messages: each run is a new session\n";
print 'model: ', ($o{model} // 'Claude Code default (none recorded in the session)'), "\n";
for my $i (1 .. $o{runs}) {
    my @cmd = ('claude', '-p', $prompt);
    push @cmd, '--resume', $session, '--fork-session' if $turns;
    push @cmd, '--permission-mode', 'acceptEdits', '--output-format', 'stream-json', '--verbose';
    push @cmd, '--model', $o{model} if $o{model};
    my $stream = "$out/run-$i.stream";
    my $pid = fork // die "fork failed: $!\n";
    if ($pid == 0) {
        chdir $o{dir} or die "cannot enter $o{dir}: $!\n";
        open STDIN, '<', '/dev/null';
        open STDOUT, '>', $stream or die;
        open STDERR, '>&', \*STDOUT;
        alarm $o{timeout};
        exec @cmd or die "cannot run claude: $!\n";
    }
    waitpid $pid, 0;
    my ($answer, @tools) = ('');
    if (open my $s, '<', $stream) {
        while (my $line = <$s>) {
            my $j = eval { $json->decode($line) } or next;
            $answer = $j->{result} // '' if ($j->{type} // '') eq 'result';
            next if ref $j->{message} ne 'HASH' || ref $j->{message}{content} ne 'ARRAY';
            for my $c (@{ $j->{message}{content} }) {
                next if ref $c ne 'HASH' || ($c->{type} // '') ne 'tool_use';
                my $in = $c->{input} // {};
                my $what = $in->{file_path} // $in->{command} // $in->{pattern} // $in->{path} // '';
                $what =~ s/\s+/ /g;
                push @tools, ($c->{name} // '?') . ': ' . substr($what, 0, 200);
            }
        }
        close $s;
    }
    write_file("$out/run-$i.txt", $answer);
    write_file("$out/run-$i.tools", join("\n", @tools) . (@tools ? "\n" : ''));
    my $short = $answer;
    $short =~ s/\s+/ /g;
    printf "run %d: %d tool calls; answer: %s\n", $i, scalar @tools, substr($short, 0, 160);
}
print "outputs in $out\n";

sub write_file {
    my ($f, $s) = @_;
    open my $h, '>:utf8', $f or die "cannot write $f: $!\n";
    print $h $s;
    close $h;
}
