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

my $accounts_file = $ARGV[0];
if (not defined $accounts_file) {
    die "ERROR: You must provide an account txt file or xls file on the command line.\n";
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

#remove_low_price_accounts("2012 Value", 5000, \%account_hash);
print "INFO : Checking " . scalar(keys(%account_hash)) . " records.\n";

my $mismatch_count = 0;
my $workbook = Spreadsheet::WriteExcel->new("accounts_with_renters.xls");
my $worksheet = $workbook->add_worksheet();
my $header_count = 0;
my $first_line = 1;
my $format = $workbook->add_format();
$format->set_color('red');

my @accounts = sort(keys(%account_hash));
for (my $i = 0; $i < scalar(@accounts); $i++) {
    my $account = $accounts[$i];
    my @account_keys = sort(keys(%{$account_hash{$account}}));
    if ($first_line == 1) {
        for (my $j = 0; $j < scalar(@account_keys); $j++) {
            $worksheet->write(0, $j, $account_keys[$j]);
        }
        $worksheet->write(0, scalar(@account_keys), "Mailing Address");
    }

	my $property_info_web_address = "http://www.taxnetusa.com/texas/travis/detail.php?i_search_form_basket=&whereclause=&i_county_code=227&theKey=XXXXX";
	$property_info_web_address =~ s/XXXXX/$account/;
	
	my $mech = WWW::Mechanize->new();
	$mech->get( $property_info_web_address );

    my $base_href = "base_href";
    my $page = $mech->content (
        base_href => $base_href
    );
    my $stream =  HTML::TokeParser->new(\$page);

    my %record_hash;    
    while (my $token = $stream->get_token) {
        if ($token->[0] eq "S" and $token->[1] eq "table" and 
            exists $token->[2]->{"class"} and $token->[2]->{"class"} eq "records") {
            print "INFO : Getting records for " . $account_hash{$account}->{"Address"} . "\n";
            create_horizontal_table_hash($stream, \%record_hash);
        }        
    }
  
    #print Dumper(\%record_hash);
    
    my $mailing_address = $record_hash{"Mailing Address"};
    my $address = $account_hash{$account}->{"Address"};
    
    # Remove newlines.
    $mailing_address =~ s/\ /\*/g;
    $mailing_address =~ s/[\s]+//g;
    $mailing_address =~ s/\*/\ /g;

    if ($mailing_address !~ /$address/) {
    	print "INFO : " . $account_hash{$account}->{"Address"} . " doesn't match mailing address.\n";
    	$mismatch_count++;
        for (my $j = 0; $j < scalar(@account_keys); $j++) {
            $worksheet->write($i + 1, $j, $account_hash{$account}->{$account_keys[$j]}, $format);
        }
        $worksheet->write($i + 1, scalar(@account_keys), $mailing_address, $format);
    }
    else {
        for (my $j = 0; $j < scalar(@account_keys); $j++) {
            $worksheet->write($i + 1, $j, $account_hash{$account}->{$account_keys[$j]});
        }
        $worksheet->write($i + 1, scalar(@account_keys), $mailing_address);
    }
}

print "INFO : There were $mismatch_count mismatches.\n";

exit 0;

__END__
