#!/usr/bin/perl

use strict;
use warnings;

$|++; # Immediate STDOUT, maybe?

use Getopt::Long;
my $version = "0.1.918a";
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

use PomalSQL;
use Anime;
use Manga;
use FIO qw( loadConf );

FIO::loadConf($conffilename);

# perhaps load these on-the-fly when they are needed?
use External;
use Import;
use Export;

use PGUI;

if ($remdb eq "yesIamSure") { # Debugging switch -x
	unless (FIO::config('DB','type') eq "L") {
		warn "I am removing the old database!!!\n";
		my ($dbh) = PGUI::loadDBwithSplashDetail();
		PomalSQL::doQuery(2,$dbh,"DROP DATABASE pomal");
		closeDB($dbh);
	}
}

my $dbh = PGUI::loadDBwithSplashDetail();
print "\nStarting GUI...\n";
my $gui = PGUI::createMainWin($version);
PGUI::populateMainWin($dbh,$gui);
$| = 0; # return to buffered STDOUT
Gtk2->main();
print "Oops... not finished coding this. Exiting normally.\n";
