#############################################################################
#script.pl v1.0
#Perl Version 5
#@author Jean-Baptiste Delon <https://github.com/JayBeeDe/riverbed-perl/issues>
#############################################################################

#!/usr/bin/perl
# Modules Declarations-------------------------------------------------------
use strict;
use POSIX; #usually installed
use Riverbed; #Riverbed Steelhead Optiwans module for RiOS
# Depends on Net::SSH::Expect, which needs to be installed !
#(http://search.cpan.org/~bnegrao/Net-SSH-Expect-1.09/lib/Net/SSH/Expect.pod)
use File; #File manager module
use Data::Dumper;

# Settings--------------------------------------------------------------------
my $input = "liste.txt";#name.ext : file which lists devices
my $output = "Rapport.csv";#name.ext : output file
my $log = "Erreurs.log";#name.ext : Error and warn log
my $dspmax = 80;#terminal length column (80=default setting putty)
our $dspCmdLog = 'true';#display all commands of each device in log if set to 'true'
my $clearLog = 'true';#clear log file before processing if set to 'true'
my $clearReport = 'true';#clear old report before processing if set to 'true'

# Main========================================================================
our @input = File::filepath($input);
our @output = File::filepath($output);
our @log = File::filepath($log);
#create global variable to be reused in this script or other module

File::clearLog() if ($clearLog eq 'true');
File::writeLog(getlogin, "_HOME_", "-----Démarrage du script...-----", "true");

#clear log file if file exists and option enabled.
my $inputFile = File->new($input[0], $input[1], "r", $input[2]);
my @list = $inputFile->read();
#read ip devices from device list file, put in an array
my $headerFlag = $clearReport;

my $i=0;
foreach (@list) {
	%Riverbed::answ = ();
	#browse each device
	progress(@list, $i);
	#display progress and status bar
    if ($_ !~ /^(# |\s*$)/ && $_!="") {
		#if device not disabled
		my $ssh = Riverbed->new ($_, 'supervision', 'Vi$ion3df');
		#connect to device
		$ssh->get("show hosts", "Hostname");
		$ssh->get("show info", "Serial", "Model", "Version");
		$ssh->get("show interfaces inpath0_0", "IP address", "Netmask");
		$ssh->get("show licenses", "Local", "Feature");
		$ssh->get("show stats traffic optimized bi-directional month", "<array1>");
		#get queries in hashed arrays. An array key is for a field.
		#See function in Riverbed module for more details.
		my $rapportFile;
		$rapportFile = File->new($output[0], $output[1], "we", $output[2]) if($clearReport eq 'true');
		$rapportFile = File->new($output[0], $output[1], "w", $output[2]) if($clearReport ne 'true');
		$clearReport = 'false';
		
		if ($headerFlag eq 'true' && $Riverbed::answ{"0"} == 1) {
			$rapportFile->writeReport($ssh,'true');
			$headerFlag = 'false';
		} else {
			$rapportFile->writeReport($ssh);
		}
	}
	$i++;
}

progress(@list, $i);
File::writeLog(getlogin, "_HOME_", "-----Fin du script-----");
print("Opération Terminée !\n");

# Other Functions-------------------------------------------------------------
sub progress {
#display progress and status bar / Return nothing
my ($max, $current) = @_;
#ARG1 => number of devices in input list !required
#ARG2 => current device position !required
system("clear");
my $percent;
if (@list > 0) {
	$percent = ceil($i/@list*100);
} else {
	$percent = 100;
}
my $dspcurrent = ceil($percent/100*$dspmax);
my $dspnotcurrent = $dspmax-$dspcurrent;
my $msg = "Exécution du script...";
my $space = $dspmax-length($msg)-5;
$space = 0 if($space<0);
print("="x$dspcurrent.">"."-"x$dspnotcurrent."\n");
print($msg." "x$space." | ".$percent."%\n");
}

