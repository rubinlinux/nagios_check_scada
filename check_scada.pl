#!/usr/bin/perl
#
# A Nagios plugin to check SCADA 3000 boxes reports
# 
# Zebrafish International Resource Center (ZIRC)
# Oct 2013

use strict;
use warnings;
use WWW::Mechanize;
use HTML::TokeParser;
use Data::Dumper;
use Getopt::Long;

my %options;
GetOptions( \%options, 'help', 'address:s', 'description:s','value:s', 'warning:s','critical:s', 'url:s', 'verbose' );

if( $options{'help'} 
    || (!$options{'url'} )
    || (!$options{'description'} && !$options{'address'})
    || ( !$options{'value'} 
          && (!$options{'warning'} || !$options{'critical'}) 
       )
    ) {
    print "Usage: check_scada.pl --url=<url> <--address=<scada_address>|--description=<description>> --critical=<min>:<max> --warn=<min>:<max>\n";
    exit 10;
}
if(defined $options{'critical'} && $options{'critical'} !~ /^\d+(\.\d+)?\:\d+(\.\d+)?$/) {
    print "Critical value not in required format: 'lower:upper'\n";
    exit 1;
}
if(defined $options{'warning'} && $options{'warning'} !~ /^\d+(\.\d+)?\:\d+(\.\d+)?$/) {
    print "Warning value not in required format: 'lower:upper'\n";
    exit 1;
}
  
sub readin {
    my $url = shift;
    my $agent = WWW::Mechanize->new( autocheck => 0);

    #Read the URL, with error handling to try a few times in case we catch it in the middle of an update
    #cycle (which happens frequently with SCADA)
    my $try = 0;
    while( $try < 5 ) {
        my $result = $agent->get("$url");
        if($result->is_error()) {
            warn("error with result: ". $result->code. "... Trying again in a few moments...\n");
            sleep(5);
            $try++;
        }
        else {
            $try = 10;
        }
    }

    #Find the table with values in it...
    my $stream = HTML::TokeParser->new(\$agent->{content});
    $stream->get_tag("table");
    $stream->get_tag("table");
    my @return_array;
    #parse out each row
    while($stream->get_tag("tr")) {
        $stream->get_tag("td");
        my $address = $stream->get_trimmed_text("/td");
        $stream->get_tag("td");
        my $description = $stream->get_trimmed_text("/td");
        $stream->get_tag("td");
        my $value_and_unit = $stream->get_trimmed_text("/td");
        chop $address;
        chop $description;
        chop $value_and_unit;
        next if($address eq 'UAF'); #skip header

        $value_and_unit =~ /^([0-9.-]+|\w+)(?| ?(.+))?/;
        my $value = $1;
        my $unit = $2;
        #$unit = $value, $value = 1 if($value =~ /^(running|on|closed)/i);
        #$unit = $value, $value = 0 if($value =~ /^(stopped|off|open)/i);
        push @return_array, {address => $address, description => $description, value => $value, unit => $unit};
    }
    return @return_array;
}

sub process_box {
    my $url = shift;
    my $searchdesc = $options{'description'};
    my ($warn_min, $warn_max, $crit_min, $crit_max);
    if(defined $options{'warning'}) {
        ($warn_min, $warn_max) = split(':', $options{'warning'});
    }
    if(defined $options{'critical'}) {
        ($crit_min, $crit_max) = split(':', $options{'critical'});
    }
    foreach my $row (readin($url)) {
       print Dumper($row);
       if( (defined $options{'address'} && $options{'address'} eq $row->{'address'})
          || (defined $searchdesc && $row->{'description'} =~ /$searchdesc/i)
       ) {
            print "DEBUG: Found matching address/description. Now looking for state:\n"; if $options{'verbose'};
            #Critical 
            if(   ( defined $options{'value'} && $options{'value'} ne $row->{'value'} )
               || ( defined $crit_min && $row->{'value'} < $crit_min )
               || ( defined $crit_max && $row->{'value'} > $crit_max) ) {
                print "CRITICAL - ". $row->{value}. "\n";
            }
            #Warning
            elsif(  ( defined $warn_min && $row->{'value'} < $warn_min  )
                ||  ( defined $warn_max && $row->{'value'} > $warn_max ) ) {
                print "WARNING - $row->{value}\n";
            }
            else {
                print "OK - $row->{value}\n";
            }
            exit;
       }
    }
    print "UNKNOWN - No matching rows found\n"; #search Not found...
    exit;
}

process_box($options{'url'});

