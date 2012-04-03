
use strict;

use JSON;
use YAML;

my $x = YAML::LoadFile($ARGV[0]);

for my $k (keys %$x) {
    $x->{$k} =~ s/\n//g;
}

my $y = JSON::encode_json( $x );

print $y;

