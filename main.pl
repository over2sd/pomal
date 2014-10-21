#!/usr/bin/perl

use strict;
use warnings;

$|++; # Immediate STDOUT, maybe?

use Getopt::Long;
my $version = "0.1.02prealpha";
my $conffilename = 'config.ini';
my $showhelp = 0;
my $remdb = 0; # clear the database. Use with caution!!!

GetOptions(
	'conf|c=s' => \$conffilename,
	'help|h' => \$showhelp,
	'flush|x=s' => \$remdb
);
if ($showhelp) {
	print "POMAL v$version\n";
	print "usage: main.pl -c [configfile]\n";
	print "All other options are controlled from within the GUI.\n";
	exit(0);
}

use lib "./modules/";

# print "Loading modules...";

use FIO qw( loadConf );

FIO::loadConf($conffilename);

use PomalSQL;
#use Anime;
#use Manga;

use PGUI;
#use Options;

print "\nStarting GUI...\n";
my $gui = PGUI::createMainWin($version);

if ($remdb eq "yesIamSure") { # Debugging switch -x
	unless (FIO::config('DB','type') eq "L") {
		warn "I am removing the old database!!!\n";
		my ($dbh) = PGUI::loadDBwithSplashDetail($gui);
		PomalSQL::doQuery(2,$dbh,"DROP DATABASE pomal");
		closeDB($dbh);
	}
}

my $dbh = PGUI::loadDBwithSplashDetail($gui);
####### Rebuild Marker
#PGUI::populateMainWin($dbh,$gui);
message("Rebuild is not complete. Sorry.");
$| = 0; # return to buffered STDOUT
Prima->run();
