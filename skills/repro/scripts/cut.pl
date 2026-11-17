#!/usr/bin/env perl
# Copy a Claude Code session (JSONL) up to, not including, a given user message.
# Optionally replace a text everywhere in the copy (old instruction -> fixed instruction).
# The original file is never changed.
# Usage: perl cut.pl <session.jsonl> <out.jsonl> --before "<start of user message>" [--replace <old file> <new file>]
use strict;
use warnings;
use JSON::PP;

my ($in, $out, $before, $old_file, $new_file);
my @args = @ARGV;
$in = shift @args;
$out = shift @args;
while (@args) {
    my $a = shift @args;
    if ($a eq '--before') { $before = shift @args; }
    elsif ($a eq '--replace') { $old_file = shift @args; $new_file = shift @args; }
    else { die "unknown argument: $a\n"; }
}
if (!defined $in || !defined $out || !-f $in || !defined $before || $before eq '') {
    print STDERR "Usage: perl cut.pl <session.jsonl> <out.jsonl> --before \"<start of user message>\" [--replace <old file> <new file>]\n";
    exit 2;
}
my ($old, $new);
if (defined $old_file) {
    $old = slurp($old_file);
    $new = slurp($new_file);
    $old =~ s/\s+\z//;
    $new =~ s/\s+\z//;
    die "old text is empty\n" if $old eq '';
}

my $json = JSON::PP->new->utf8->canonical(0);
my $want = norm($before);
open my $fh, '<', $in or die "cannot read $in: $!\n";
my (@keep, $found, $replaced);
while (my $line = <$fh>) {
    my $row = eval { $json->decode($line) };
    if ($row && ref $row eq 'HASH' && is_user_prompt($row)) {
        my $text = norm(user_text($row));
        if (index($text, $want) >= 0) { $found = 1; last; }
    }
    if (defined $old && $row && ref $row eq 'HASH') {
        my $n = 0;
        $row = walk($row, \$n);
        if ($n) { $replaced += $n; $line = $json->encode($row) . "\n"; }
    }
    push @keep, $line;
}
close $fh;
if (!$found) {
    print STDERR "No user message starts with that text. Nothing written.\n";
    exit 1;
}
open my $oh, '>', $out or die "cannot write $out: $!\n";
print $oh @keep;
close $oh;
printf "kept %d lines before the message", scalar @keep;
printf "; replaced the text %d times", $replaced // 0 if defined $old;
print "\n";
print STDERR "Warning: the old text was not found in the kept part.\n" if defined $old && !$replaced;

sub is_user_prompt {
    my ($r) = @_;
    return 0 if ($r->{type} // '') ne 'user' || $r->{isMeta} || $r->{isSidechain};
    my $t = user_text($r);
    return 0 if $t eq '' || $t =~ /^\s*<(command-|local-command|system-reminder)/;
    return 1;
}

sub user_text {
    my ($r) = @_;
    my $c = ref $r->{message} eq 'HASH' ? $r->{message}{content} : undef;
    return $c if defined $c && !ref $c;
    return '' if ref $c ne 'ARRAY';
    return join "\n", map { $_->{text} // '' } grep { ref $_ eq 'HASH' && ($_->{type} // '') eq 'text' } @$c;
}

sub norm {
    my ($s) = @_;
    $s =~ s/\s+/ /g;
    $s =~ s/^ | $//g;
    return $s;
}

sub walk {
    my ($v, $n) = @_;
    if (ref $v eq 'HASH') { $v->{$_} = walk($v->{$_}, $n) for keys %$v; return $v; }
    if (ref $v eq 'ARRAY') { $_ = walk($_, $n) for @$v; return $v; }
    if (defined $v && !ref $v && index($v, $old) >= 0) {
        my $count = () = $v =~ /\Q$old\E/g;
        $$n += $count;
        $v =~ s/\Q$old\E/$new/g;
    }
    return $v;
}

sub slurp {
    my ($f) = @_;
    open my $h, '<:raw', $f or die "cannot read $f: $!\n";
    local $/;
    my $s = <$h>;
    close $h;
    utf8::decode($s);
    return $s;
}
