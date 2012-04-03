#!/usr/bin/perl 

use strict;
use warnings;

use English qw( -no_match_vars );
use JSON;


my $text = "";

for (1) {
    local $RS;
    $text = <>
}

my @queries = map {
    $ARG =~ s/\s+/ /g;
    $ARG =~ s/^\s+//g;
    $ARG =~ s/\s+$//g;
    $ARG;
} split('\s*;\s*', $text);

my @names = qw|
    get_address
    get_customer
    get_invoice
    get_lineitems
    list_customers
    list_invoices
    get_customer_invoices
    add_address
    add_customer
    add_product
    add_invoice
    add_lineitem
|;

my %struct;

for my $i (0 .. $#names) {
    $struct{ $names[$i] } = $queries[$i];
}

print encode_json( \%struct );


