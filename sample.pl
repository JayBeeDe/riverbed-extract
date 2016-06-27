#!/usr/bin/perl
# Modules Declarations-------------------------------------------------------
use strict;
use Riverbed; #Riverbed Steelhead Optiwans module for RiOS
# Depends on Net::SSH::Expect, which needs to be installed !
#(http://search.cpan.org/~bnegrao/Net-SSH-Expect-1.09/lib/Net/SSH/Expect.pod)
use File; #File manager module
use Data::Dumper;

# Settings--------------------------------------------------------------------
my $output = "Rapporttemp.csv";
my $log = "Erreurs.log";

# Main========================================================================
our @output = File::filepath($output);
our @log = File::filepath($log);

my $ssh = Riverbed->new ('x.x.x.x', 'login', 'password');
$ssh->_statsTraffic();
$ssh->_inpath();
$ssh->_version();