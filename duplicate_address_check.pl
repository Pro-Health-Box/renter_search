#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Spreadsheet::ParseExcel;

do "tax_records.pm";

my $accounts_file = $ARGV[0];
if (not defined $accounts_file) {
    die "ERROR: You must provide an account txt file or xls on the command line.\n";
}

my %account_hash;
if ($accounts_file =~ /.txt$/) {
    parse_accounts_file($accounts_file, \%account_hash);
}
elsif ($accounts_file =~ /.xls/) {
    parse_accounts_xls($accounts_file, \%account_hash);
}
else {
    die "ERROR: Unknown file extension.\n";
}

my %address_hash;
foreach my $record (keys(%account_hash)) {
	my $address = $account_hash{$record}->{"Address"};
    if (exists $address_hash{$address}) {
    	print "INFO : Duplicate address found.\n";
    	print "     : Entry 1\n";
        print Dumper($account_hash{$record});
        print "     : Entry 2\n";
        print Dumper($account_hash{$address_hash{$address}});
    }	
    else {
    	$address_hash{$address} = $record; 
    }
}

#print Dumper(\%account_hash);

exit 0;

__END__
