#############################################################################
#File.pm class module v1.0
#Perl Version 5
#@author Jean-Baptiste Delon <https://github.com/JayBeeDe/riverbed-perl/issues>
#@license http://www.gnu.org/licenses/gpl.txt GNU GENERAL PUBLIC LICENSE
#############################################################################

# Package Declarations-------------------------------------------------------
package File;
use strict;
use Cwd; #usually installed
use Data::Dumper;
use File::Basename; #just used once in filepath function

my $ddelimiter = ";";
my $dsubDelimiter = ",";

# Constructor================================================================
sub new {
	my($class, $name, $path, $mode, $ext) = @_;
	$class = ref($class) || $class;
	my $this = {};
	bless($this, $class);#!important
	
	#ARG1 => class itself {native}
	#ARG2 => file name !required
	#ARG3 => path <optional> [set to current if undef]
	#ARG4 => mode (reading or writing) [r/w] <optional> [set to reading mode if empty]
	#ARG5 => extension <optional> [set to csv if writing mode and empty extension |OR| 								set to empty if writing mode and empty extension]
	
	#object structure example------------------------------------------------
	#object( {
    #             	NAME => "myfile",
    #             	PATH => "/home/user",
	#				MODE => "w",
	#				EXT => "txt",
	#				FILE => *FILE, (reference on file)
	#				DELIMITER => ",",
	#				SUBDELIMITER => "-",
    #           }, File );
	#------------------------------------------------------------------------
	
	$this->{NAME} = $name;
	$this->{PATH} = $path;
	$mode = "r" unless(defined($mode));
	if($mode eq "w") {
		$this->{MODE} = ">>";
	}elsif($mode eq "we") {
		$this->{MODE} = ">";
	}else{
		$this->{MODE} = "<";
	}
	$ext = lc($ext);
	$this->{EXT} = lc($ext);
	
	$this->{MODE} = "<" unless(defined($mode));
	unless(defined($ext)) {
		$this->{EXT} = "" unless($this->{MODE} eq ">>");
		$this->{EXT} = "csv" if($this->{MODE} eq ">>");
	}
	
	$this->{DELIMITER} = $ddelimiter;	
	$this->{DELIMITER} = "\t" if($this->{EXT} eq "txt");
	$this->{DELIMITER} = ";" if($this->{EXT} eq "csv");
	
	$this->{SUBDELIMITER} = $dsubDelimiter;
	$this->{SUBDELIMITER} = "|" if($this->{SUBDELIMITER} eq $this->{DELIMITER});
	
	$this->{PATH} = getcwd if(!defined($path) || $path eq "");
	
	my $file = $this->{PATH}."/".$this->{NAME}.".".$this->{EXT};
	
	my $msg = "Impossible ";
	if($this->{MODE} eq ">>") {
		$msg.= "d'écrire";
	}else{
		$msg.= "de lire";
	}
	
	if(defined($this->{NAME})) {
		open (FILE, $this->{MODE}.$file) or (writeLog(getlogin, "_HOME_", $msg." ".$file) && exit(1));
	}#open file (reading or writing) and on error, write into log and clean exit
	$this->{FILE} = *FILE;#put file descriptor in a variable
	return $this;#!important
}

# Other Functions============================================================
sub write {
#write content into file / return nothing
#ARG0 => File object
#ARG1 => string content
	my ($this, $content) = @_;
	$this->{FILE}->print($content."\n");
}

sub read {
#read line by line content from file / Return array, a cell by line
#ARG0 => File object

#calling example => returning serial, model and revision from the $ssh object session
#my %answ = $ssh->get("show info", "Serial", "Model", "Revision");

#will return a simple array
#my @s = ("line1", "line2", ..., "lineN");

	my ($this) = @_;
	my @content = ();
	#my $line = "\n".readline($this->{FILE});
	my $i = 0;
	while (readline($this->{FILE})) {
		$content[$i] = $_;
		#$content[$i] =~ s/(\r|\n|\t|\f|\e)//g;#remove all carriage return, tab, etc.from file
		$content[$i] =~ s/[[:space:]]//g;#remove all carriage return, tab, etc.
		$i++;
	}
	return @content;
}

sub writeLog {
#write log into file / return nothing
	my ($user, $ip, $content, $enable) = @_;
	$content = "[".gmtime."] [".$user."\@".$ip."] ".$content;
	$enable = 'false' unless(defined($enable));
	print $content."\n" if($enable eq 'true');
	my $logFile = File->new($::log[0], $::log[1], "w", $::log[2]);
	$logFile->write($content);
}

sub writeReport {
	my ($this, $ssh, $header) = @_;
	my $delimiter = $this->{DELIMITER};
	my $subDelimiter = $this->{SUBDELIMITER};
	
	if ($Riverbed::answ{"0"} == 1) {
		my @keys = sort { $a cmp $b } keys(%Riverbed::answ);
		@keys = grep {$_ ne "0"} @keys;
			
		if ($header eq 'true') {
			my @keysHeader = @keys;
			s/(\n|\r)/$subDelimiter/gs for @keysHeader;
			s/$delimiter/$subDelimiter/gs for @keysHeader;
			$this->write("IP".$delimiter.join($delimiter, @keysHeader));
		}
		
		my @vals = @Riverbed::answ{@keys};
		s/\n/$subDelimiter/gs for @vals;
		s/$delimiter/$subDelimiter/gs for @vals;
		$this->write($ssh->{ADDRESS}.$delimiter.join($delimiter, @vals));
	}
}

sub clearLog{
	my $samFile = File->new($::log[0], $::log[1], "we", $::log[2]);
	$samFile->write("");
}

sub filepath {
#convert "my/path/filename.extension" to an (filename, my/path, extension) array
#ARG 1 => string
	my ($content) = @_;
	my @content = fileparse($content, qr/\.[^.]*/); #convert fullname string to array
	$content[2] =~ s/\.//g; #remove "." from extension
	$content[1] =~ s/(\/)$//g; #remove last "/" from path
	return @content;
}

# Destructor=================================================================
sub DESTROY {
	my ($this) = @_;
	return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
	$this->{SSH}->close;
}
1;#! REALLY IMPORTANT