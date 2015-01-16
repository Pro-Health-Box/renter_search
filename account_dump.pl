#!/usr/bin/perl

# This script will find all the renters with a given address file.
# The address file must have the format:
# Street Name   Starting Number   Ending Number

use strict;
use warnings;

use Data::Dumper;
use Spreadsheet::WriteExcel;
use Spreadsheet::ParseExcel;
use WWW::Mechanize;

do "tax_records.pm";

my $tax_web_address = "http://www.taxnetusa.com/texas/travis/";

my $address_file = $ARGV[0];
if (not defined $address_file) {
    die "ERROR: You must specify the address file on the command line.\n";
}

if (not -e $address_file) {
    die "ERROR: Unable to find $address_file\n";
}

my %address_hash;
open my $address_fh, "<", $address_file or die "ERROR: Unable to open $address_file for reading.\n";
while (my $line = <$address_fh>) {
    if ($line =~ /[\s]*\#/) {
        next;
    }
    elsif ($line =~ /([\w]+)[\s]+([\d]+)[\s]+([\d]+)/) {
        $address_hash{$1}{"start"} = $2;
        $address_hash{$1}{"end"} = $3;
    }
    else {
        die "ERROR: Misformatted line -- $line";
    }
}
close $address_fh;

#print Dumper(\%address_hash);

my %record_hash;
foreach my $street (sort(keys(%address_hash))) {
    # Find a list of all the houses on the street.
    my $mech = WWW::Mechanize->new();

    $mech->get( $tax_web_address );
    $mech->submit_form(
        with_fields => {
            "k.situs_street" => $street
        }, 
    );

    my $base_href = "base_href";
    my $page = $mech->content (
        base_href => $base_href
    );
    my $stream =  HTML::TokeParser->new(\$page);

    while (my $token = $stream->get_token) {
        if ($token->[0] eq "S" and $token->[1] eq "table" and 
            exists $token->[2]->{"class"} and $token->[2]->{"class"} eq "records") {
            print "INFO : Getting records for $street\n";
            create_vertical_table_hash($stream, \%record_hash);
        }
    }
}

my $first_line = 1;
open my $accounts_fh, ">", "accounts.txt" or die "ERROR: Unable to open accounts.txt for writing.\n";
foreach my $record (sort(keys(%record_hash))) {
    if ($first_line == 1) {
    	my @record_keys = sort(keys(%{$record_hash{$record}}));
        foreach my $key (@record_keys) {
            print {$accounts_fh} $key;
            if ($key ne $record_keys[-1]) {
            	print {$accounts_fh} "|";
            }
        }   
        print {$accounts_fh} "\n"; 
        $first_line = 0;
    }
    
    my @record_keys = sort(keys(%{$record_hash{$record}}));
    foreach my $key (@record_keys) {
        print {$accounts_fh} $record_hash{$record}->{$key};
        if ($key ne $record_keys[-1]) {
            print {$accounts_fh} "|";
        }
    }
    print {$accounts_fh} "\n";
}
close $accounts_fh;

my $workbook = Spreadsheet::WriteExcel->new("accounts.xls");
my $worksheet = $workbook->add_worksheet();
my $header_count = 0;
$first_line = 1;

my @records = sort(keys(%record_hash));
for (my $i = 0; $i < scalar(@records); $i++) {
    my @record_keys = sort(keys(%{$record_hash{$records[$i]}}));
    if ($first_line == 1) {
        for (my $j = 0; $j < scalar(@record_keys); $j++) {
            $worksheet->write(0, $j, $record_keys[$j]);
        }
    }

    for (my $j = 0; $j < scalar(@record_keys); $j++) {
        $worksheet->write($i + 1, $j, $record_hash{$records[$i]}->{$record_keys[$j]});
    }
}

print "INFO : Found " . keys(%record_hash) . " records.\n";

exit 0;

__END__
