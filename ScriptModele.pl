#!/usr/bin/perl

use Net::SSH::Expect;
use threads;
use threads::shared;
use Getopt::Std;

my $num_threads : shared = 0;
my $max_thread = 3;
my $rapport_erreurs = 'erreurs.log';
my $rapport = 'rapport.csv';

my $liste;

# Gestion des options
my %opt=();
getopts("Hhf:e:",\%opt);
if(defined $opt{h}) { help(); }
if(defined $opt{f}) { $liste = $opt{f}; } else { help(); }
if(defined $opt{e}) { $rapport_erreurs = $opt{e}; }



open (ERREURS, ">$rapport_erreurs") or die "Impossible d'ouvrir le fichier $rapport_erreurs";
open (RAPPORT, ">$rapport") or die "Impossible d'ouvrir le fichier $rapport";
print "IP/Hostname\t\t\t\t\n";
print RAPPORT "IP;Hostname;\n";
#select ERREURS;
#$|=1;

get_liste($liste);

close RAPPORT;
close ERREURS;


sub get_liste
{
  my $show_image;
  my ($liste) = @_;
  open (LISTE, $liste) or die "Impossible d'ouvrir le fichier $liste\n";
  while (<LISTE>)
  {
    if ($_ !~ /^(#|\s*$)/)
    {
      while ($num_threads >= $max_thread)
      { 
        print "$num_threads thread(s) actifs: nombre de threads maximal autorise atteint\n";
        sleep 2;
      }

#print ">$num_threads<\n";                                
      chomp($_);
      my ($ip, $hostname) = (split(/;/, $_))[0, 1];
      $num_threads++;
#      my $thr = threads->new('connexion',$ip,$hostname);
#      $thr->detach();
       connexion($ip,$hostname);
#      image($ip,$hostname,$show_image);
    }
  }
  close LISTE;
  # Attendre la fin de tous les threads
  while ($num_threads)
  {
    print "Fin du script, il reste $num_threads threads en cours\n";
    sleep 2;
  }              
}

# Connexion au SH en Ssh via Expect - A ameliorer, tres lent
sub connexion
{
  my $ssh;
  my $login_output;
  my $show_imgage;
  my ($ip,$hostname) = @_;
  
  $ssh = Net::SSH::Expect->new ( host => $ip, password=> 'password', user => 'admin', raw_pty => 1, timeout => 6, ssh_option => " -x -o ConnectTimeout=5", log_file=> "log");
#  $ssh = Net::SSH::Expect->new ( host => $ip, password=> '', user => 'admin', raw_pty => 1, timeout => 7, ssh_option => " -x -o ConnectTimeout=5", log_file=> "log");

#print ">$ssh\n";
  #print "> Connexion au Steelhead\n";
  eval { $login_output = $ssh->login(); };
#  print ">$login_output-$@<\n";
  
  if ($@ =~ /SSHConnectionAborted/) { print "$ip/$hostname\t\tInjoignable\n"; $ssh->close(); $num_threads--; return; }
  if ($@ =~ /SSHProcessError/) { print "$ip/$hostname\t\tProcess Error\n"; $ssh->close(); $num_threads--; return; }
  if ($@ =~ /SSHAuthenticationError Login timed out/) { print "$ip/$hostname\t\tErreur Tiemout\n"; $ssh->close(); $num_threads--; return; }
  
  if ($login_output =~ /Permission denied/) { print "$ip/$hostname\tProbleme d'identification\n"; $ssh->close(); $num_threads--; return; }
  if ($login_output !~ /Last login/) { print "Login has failed. Login output was >$login_output<"; $ssh->close(); $num_threads--; return; }
  
  #print "> Recherche du prompt\n";
  ($ssh->read_all(2) =~ /.*/) or die "where's the remote prompt?";
  
  #my $val = $ssh->read_line(4);
  #print "TEST5>".$val."<\n";
  ##$ssh->exec("stty raw -echo");

  #print "> Lancement de la commande show images\n";
  $ssh->exec("terminal length 0",5);
  $show_image = $ssh->exec("show images",5);

  #print "> Fin de la commande show images\n";

  #print "> Cloture de la session\n";
  $ssh->close();
  imagechk($ip,$hostname,$show_image);
  print "\n";
  print RAPPORT "\n";
  $num_threads--;
#  return ($show_image);
}


# Fonction permettant d'interpreter le show images
sub imagechk
{
  my ($ip,$hostname,$show_image) = @_;
  my $img1;
  my $img2;
  my $stractive;
  my $arch;
#  print ">$show_image<\n";
  open (CONF, ">logcheck.txt") or die "Impossible d'ouvrir le fichier logcheck.txt $!";
  print CONF $show_image;
  close CONF; 
  print "$ip/$hostname";
  print RAPPORT "$ip;$hostname;";

    if ($show_image =~ /image_rbt_sh_8_5_3c/) { print "\tImage image_rbt_sh_8_5_3c PRESENTE"; }
    else { print "\tImage image_rbt_sh_8_5_3c NON presente"; }
}


sub help
{
  print "\nMessage d'aide\n"."-"x14;
  print "\n";
  print "-h\t message d'aide\n";
  print "-f\t fichier liste des routeurs en argument sous la forme \@ip;hostname;modele;version;statut;\n";
  print "\n";
  exit 0;
}

            
