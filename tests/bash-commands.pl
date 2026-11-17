# Prints every Bash command from a claude -p stream-json file, one per line.
use JSON::PP;
while (<>) {
    my $j = eval { decode_json($_) } or next;
    next unless ref $j->{message} eq 'HASH' && ref $j->{message}{content} eq 'ARRAY';
    for my $c (@{ $j->{message}{content} }) {
        next unless ref $c eq 'HASH' && ($c->{type} // '') eq 'tool_use';
        my $cmd = ($c->{name} // '') eq 'Bash' ? ($c->{input}{command} // '') : '';
        $cmd =~ s/\n/ /g;
        print "$c->{name}: $cmd\n";
    }
}
