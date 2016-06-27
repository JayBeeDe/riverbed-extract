#############################################################################
#Riverbed.pm class module v1.0												#
#Perl Version 5																#
#@author Jean-Baptiste Delon <https://github.com/JayBeeDe/riverbed-perl/issues>#
#@license http://www.gnu.org/licenses/gpl.txt GNU GENERAL PUBLIC LICENSE	#
#############################################################################

# Package Declarations-------------------------------------------------------
package Riverbed;
use strict;
use Net::SSH::Expect;
use Data::Dumper;
use POSIX; #usually installed
# Net::SSH::Expect needs to be installed !
#(http://search.cpan.org/~bnegrao/Net-SSH-Expect-1.09/lib/Net/SSH/Expect.pod)

my $connectTimeout = 6;#timeout for new ssh connection
my $DcmdTimeout = 5;#default timeout for each ssh exec (only if not precised)
my $Dpty = 1;#default pty for new ssh connection (only if not precised)
our %answ = ();

# Constructor================================================================
sub new {
	my($class, $ip, $login, $password, $timeout, $pty) = @_;
	$class = ref($class) || $class;
	my $this = {};
	#ARG1 => class itself {native}
	#ARG2 => IP Optiwan !required
	#ARG3 => user name <optional> [set to admin if empty]
	#ARG4 => password <optional> [set to password if empty]
	#ARG5 => timeout <optional> [set to 6 if empty]
	#ARG6 => pty <optional> [set to 1 if empty]
	
	#object structure example------------------------------------------------
	#object( {
    #             	ADDRESS => "xxx.xxx.xxx.xxx",
    #             	LOGIN => "admin",
	#				PASSWORD => "password",
	#				TIMEOUT => 6,
	#				PTY => 1,
    #           }, Riverbed );
	#------------------------------------------------------------------------
	
	$this->{ADDRESS} = $ip;
	$this->{LOGIN} = $login;
	$this->{PASSWORD} = $password;
	$this->{TIMEOUT0} = $connectTimeout;
	$this->{TIMEOUT} = $timeout;
	$this->{PTY} = $pty;
	
	$this->{PTY} = $Dpty unless(defined($pty));
	$this->{TIMEOUT} = $DcmdTimeout unless(defined($timeout));
	$this->{PASSWORD} = 'password' unless(defined($password));
	$this->{LOGIN} = 'admin' unless(defined($login));
	
	$this->{ERROR} = 0;
	
	my $log;
	my $logWrite;
	if(defined($ip)) {
		$this->{SSH} = Net::SSH::Expect->new ( host => $this->{ADDRESS}, password=> $this->{PASSWORD}, user => $this->{LOGIN}, raw_pty => $this->{PTY}, timeout => $this->{TIMEOUT0}, ssh_option => " -x -o ConnectTimeout=".$this->{TIMEOUT0});
		eval { $log = $this->{SSH}->login(); };

		#>>>>>>>Error issues
		$logWrite = "Connexion Optiwan - ";

		if ($log =~ /SSHConnectionAborted/) {
			File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $logWrite."Optiwan Injoignable.", "true");
			$this->{ERROR} = 1;
		}elsif ($log =~ /SSHProcessError/) {
			File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $logWrite."Erreur de Processus.", "true");
			$this->{ERROR} = 1;
		}elsif ($log =~ /SSHAuthenticationError Login timed out/) {
			File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $logWrite."Timeout Optiwan Dépassé.", "true");
			$this->{ERROR} = 1;
		}elsif ($log =~ /Permission denied/) {
			File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $logWrite."Permission non accordée.", "true");
			$this->{ERROR} = 1;
		}elsif ($log !~ /Last login/) {
			File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $logWrite."Echec de l'authentification.", "true");
			$this->{ERROR} = 1;
		}
		#>>>>>>>End Error issues
		
		if($this->{ERROR} == 0) {
			File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $logWrite."OK", "true");
			$this->{SSH}->exec("enable",0);#!important
			$this->{SSH}->exec("terminal length 0",$this->{TIMEOUT});#!important
		}
	}
	bless($this, $class);#!important
	return $this;#!important
}

# Other Functions============================================================
sub get {
#generic function which queries from device / return hashed array
#ARG0 => Riverbed object
#ARG1 => RiOS command
#ARG2...ARGN => fields wanted.

#calling example => returning serial, model and revision from the $ssh object session
#my %answ = $ssh->get("show info", "Serial", "Model", "Revision");

#will return an hashed array ("0" can be 0/1 : error no / error)
#my %h = ( 	"0"		=>  1
#			"Serial"     => "J47NJ00089BF1",
#          	"Model" => "550 (550H)",
#          	"Revision"   => "A" );

	my ($this, $cmd, @lbl) = @_;
	#cmd
	my $val1;
	my $str;
	my $response;
	my %response = ();
	if ($this->{ERROR} == 0) {
		$response = $this->{SSH}->exec($cmd, $this->{TIMEOUT});
		unless ($response =~ /\% Unrecognized command/ || $response =~ /"Insufficient permissions"/ || $response eq "") {
		
			foreach (@lbl) {
				$val1 = $_;
				my @str = ();
					if($response =~ m/\Q$val1\E/ || ($response =~ m/\Q$cmd\E/ && ($val1 eq "*" || $val1 =~ m/^(?:(?!Q<array).)*$/g))) {
						$str = $response."\n";
						if($val1 ne "*" && $val1 =~m/^(?:(?!Q<array).)*$/g) {
							$str =~s/\Q$val1\E:\s*/$val1:/gs;#remove tabs after ":" string
							@str = ($str =~ m/$val1:(.*)\n/g);
							$response{$val1} = join("\n", @str);
						} else {
							$str =~s/(\r|\n)\s*(\r|\n).*//g;#remove empty lines
							$str =~s/^(?:.*(\r|\n)){1}//g;#remove first line
							if($val1 eq "<array1>") {
								$str =~s/^(?:.*(\r|\n)){1,3}//g;#remove first lines
								$str =~s/%.*(\r|\n)/%\n/g;#keep only two first cols
								$str =~s/\)\s*/\) /g;#remove useless spaces and tabs
							}
							chop($str) if(index($str, "\n") == length($str)-1);
							$response{$val1} = $str;
						}
						if ($::dspCmdLog eq 'true') {
							File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $cmd." {".join (',', @lbl )."} - Champ ".$val1." OK.");
						}
					} else {
						if ($::dspCmdLog eq 'true') {
							File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $cmd." {".join (',', @lbl )."} - Le champ ".$val1." est introuvable.");
						}
					}
			}
			$response{"0"} = 1;
		} else {
			if ($::dspCmdLog eq 'true') {
				if ($response =~ /\% Unrecognized command/) {
					File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $cmd." - Commande innexistante.");
				} elsif($response =~ /"Insufficient permissions"/) {
					File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $cmd." - Droits non accordées avec l'utilisateur ".$this->{LOGIN}.".");
				} else {
					File::writeLog($this->{LOGIN}, $this->{ADDRESS}, $cmd." - Timeout dépassé.");
				}
			}
			$response{"0"} = 0;
		}
	} else {
		$response{"0"} = 0;
	}
	%answ = (%response, %answ);#hashed array with
}


sub getToReport {
	my ($this, $cmd, @fields) = @_;
	$this->get($cmd, @fields);
	my $rapportFile = File->new($::output[0], $::output[1], "w", $::output[2]);
	$rapportFile->writeReport($this);
	our %answ = ();
}


sub _host {
	my ($this) = @_;
	$this->getToReport("show hosts", "Hostname");
}
sub _serial {
	my ($this) = @_;
	$this->getToReport("show info", "Serial");
}
sub _model {
	my ($this) = @_;
	$this->get("show info", "Model");
	my $rapportFile = File->new($::output[0], $::output[1], "w", $::output[2]);
	s/\s(.*)//gs for %answ;
	$rapportFile->writeReport($this);
	our %answ = ();
}
sub _version {
	my ($this) = @_;
	$this->getToReport("show info", "Version");
}
sub _licenseNumber {
	my ($this) = @_;
	$this->getToReport("show licenses", "Local");
}
sub _licenseType {
	my ($this) = @_;
	$this->getToReport("show licenses", "Feature");
}
sub _inpath {
	my ($this, $number) = @_;
	$number = 0 unless(defined($number));
	$number = 0 unless($number==1);
	$this->getToReport("show interfaces inpath0_".$number, "IP address", "Netmask");
	}
sub _statsTraffic {
	my ($this) = @_;
	$this->getToReport("show stats traffic optimized bi-directional month", "<array1>");
}

# Destructor=================================================================
sub DESTROY {
	my ($this) = @_;
	return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
	$this->close();
	$this = {};#reset password !VERY IMPORTANT (security issues)
}
sub close {
	my ($this) = @_;
	$this->{SSH}->close();
}
1;#! REALLY IMPORTANT