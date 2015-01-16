#!/usr/bin/perl

use warnings;
use strict;

sub parse_accounts_xls($$) {
	my $accounts_xls = shift;
	my $r_account_hash = shift;
    my $parser = Spreadsheet::ParseExcel->new();
    my $workbook = $parser->parse($ARGV[0]);

    if (not defined $workbook) {
        die $parser->error(), ".\n";
    }

    for my $worksheet ($workbook->worksheets()) {
        my ($row_min, $row_max) = $worksheet->row_range();
        my ($col_min, $col_max) = $worksheet->col_range();

        my @header_names;
        my $account_number_col;
        for my $row ($row_min .. $row_max) {

            my @row_data;
            for my $col ($col_min .. $col_max) {
                my $cell = $worksheet->get_cell($row, $col);
                next unless $cell;            
                push(@row_data, $cell->value);
            }
            if ($row == 0) {
                for (my $i = 0; $i < scalar(@row_data); $i++) {
                    if ($row_data[$i] eq "Account Number") {
                        $account_number_col = $i;
                    }
                    push(@header_names, $row_data[$i]);
                }
            }
            else {
                for (my $i = 0; $i < scalar(@row_data); $i++) {
                    $r_account_hash->{$row_data[$account_number_col]}->{$header_names[$i]} = $row_data[$i];
                }
            }
        }
    }
}

sub parse_accounts_file($$) {
	my $accounts_file = shift;
	my $r_account_hash = shift;
	
	if (not -e $accounts_file) {
        die "ERROR: Unable to find $accounts_file\n";
    }
	
	open my $accounts_fh, "<", $accounts_file or die "ERROR: Unable to open $accounts_file for reading.\n";
	
	my $first_line_flag = 1;
	my @column_names;

	while (my $line = <$accounts_fh>) {
	    $line =~ s/[\s]+$//;
	    if ($line =~ /^#/) {
	        next;
	    }   
	    if ($first_line_flag == 1) {
	        @column_names = split(/\|/, $line);
	        $first_line_flag = 0;
	        #print Dumper(\@column_names);
	    }
	    else {
	        my @account_info = split(/\|/, $line);
	        for (my $i = 0; $i < scalar(@column_names); $i++) {
	           $r_account_hash->{$account_info[0]}->{$column_names[$i]} = $account_info[$i];
	        }
	    }
	        
	}
	
	close $accounts_fh;
	
	print "INFO : Found " . scalar(keys(%{$r_account_hash})) . " records.\n";
}

sub remove_low_price_accounts($$$) {
    my $value_string = shift;
    my $price = shift;
    my $r_account_hash = shift;	
	
	foreach my $account (sort(keys(%{$r_account_hash}))) {
		my $value = ($r_account_hash->{$account}->{$value_string});
		$value =~ s/\,//g;
		if ($value < $price) {
			print "INFO : Removing account at " . $r_account_hash->{$account}->{"Address"} . " with value of " . $r_account_hash->{$account}->{$value_string} . "\n";
			delete $r_account_hash->{$account};
		}
	}	
}

sub create_vertical_table_hash($$) {
    my $r_stream = shift;
    my $r_table_hash = shift;
    
    my @header_array;
    my $header_count = 0;
    my $first_cell;
    my $first_row_flag = 1;
    
    while (my $token = $r_stream->get_token) {
        if ($token->[0] eq "E" and $token->[1] eq "table") {
            last;
        }  
        elsif ($token->[0] eq "E" and $token->[1] eq "tr") {
            if ($first_row_flag == 1) {
                $first_row_flag = 0;
            }
            $header_count = 0;
        }
        elsif ($token->[0] eq "S" and $token->[1] eq "td") {
                       
            my $cell_token = $r_stream->get_token;
            my $cell_text = $cell_token->[1];           
            
            if ($cell_token->[0] eq "S" and $cell_token->[1] eq "a") {              
                $cell_token = $r_stream->get_token;
                $cell_text = $cell_token->[1];
            }
            
            if ($cell_token->[0] ne "T") {
               $r_stream->unget_token(($cell_token));
               $r_table_hash->{$first_cell}->{$header_array[$header_count]} = "NULL";                            
            }
            else {              
                $cell_text =~ s/^[\s]+//;
                if ($first_row_flag == 1) {
                    #print "INFO : Found header $cell_text\n";
                    $header_array[$header_count] = $cell_text;
                }
                else {
                    #print "INFO : " . $header_array[$header_count] . " == $cell_text\n";
                    if ($header_count == 0) {                   
                        $first_cell = $cell_text;                   
                    }
                    if ($first_row_flag == 0) {
                        $r_table_hash->{$first_cell}->{$header_array[$header_count]} = $cell_text;
                    }
                }
            }
            $header_count++;
        }
    }
}

sub create_horizontal_table_hash($$) {
	my $r_stream = shift;
    my $r_table_hash = shift;
    
    my $first_column_flag = 0;
    my $row_name;
    
    while (my $token = $r_stream->get_token) {
        if ($token->[0] eq "E" and $token->[1] eq "table") {
            last;
        }  
        elsif ($token->[0] eq "S" and $token->[1] eq "tr") {
            $first_column_flag = 1;
        }
        elsif ($token->[0] eq "S" and $token->[1] eq "td") {
        	my $cell_token = $r_stream->get_token;
            my $cell_text = $cell_token->[1];
            
            if ($first_column_flag == 1) {
                $row_name = $cell_text;                
            }
            else {
                $r_table_hash->{$row_name} = $cell_text;
            }      	
        }
        elsif ($token->[0] eq "E" and $token->[1] eq "td") {
        	if ($first_column_flag == 1) {             
                $first_column_flag = 0; 
            }
        }
        elsif ($token->[0] eq "S" and $token->[1] eq "br") {
            my $cell_token = $r_stream->get_token;
            my $cell_text = $cell_token->[1];            
            if ($first_column_flag == 1) {
                $row_name .= " " . $cell_text;                
            }
            else {
                $r_table_hash->{$row_name} .= " " . $cell_text;
            }	
        } 
    }	
}

__END__
