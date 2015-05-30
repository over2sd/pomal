#!/usr/bin/perl

use strict;
use warnings;
#use diagnostics;
use utf8;

my $count = shift || 1;
sub getCount { return $count; }

$|++; # Immediate STDOUT, maybe?

use Getopt::Long;
my $version = "0.1.09prealpha";
my $conffilename = 'config.ini';
my $showhelp = 0;
my $remdb = 0; # clear the database. Use with caution!!!
my $debug = 0; # verblevel
sub howVerbose { return $debug; }

GetOptions(
	'conf|c=s' => \$conffilename,
	'help|h' => \$showhelp,
	'flush|x=s' => \$remdb,
	'verbose|v=i' => \$debug,
);
if ($showhelp) {
	print "POMAL v$version\n";
	print "usage: main.pl -c [configfile]\n";
	print " -v #: set information verbosity level";
	print "All other options are controlled from within the GUI.\n";
	exit(0);
}

use lib "./modules/";

# print "Loading modules...";

require Sui; # POMAL Data stores
require Common;
require FIO;

FIO::loadConf($conffilename);
FIO::config('Debug','v',$debug);

require FlexSQL;
#require Anime;
#require Manga;

require PGUI;
require Options;

print "\n[I] Starting GUI...\n";
my $gui = PGK::createMainWin("PersonalOfflineManga/AnimeList",$version);
if ($remdb eq "yesIamSure") { # Debugging switch -x
	unless (FIO::config('DB','type') eq "L") {
		warn "I am removing the old database!!!\n";
		my ($dbh) = PGUI::loadDBwithSplashDetail($gui);
		PomalSQL::doQuery(2,$dbh,"DROP DATABASE pomal");
		closeDB($dbh);
	}
	warn "Because the database was removed, I am now exiting.\n";
	exit(0);
}

PGK::startwithDB($gui,'Pomal');
####### Rebuild Marker
#PGUI::sayBox($$gui{mainWin},"Rebuild is not complete. Sorry.");
print "GUI contains: " . join(", ",keys %$gui) . "\n";
$| = 0; # return to buffered STDOUT
Prima->run();
