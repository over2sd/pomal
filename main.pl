#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
my $version = "0.01a";
my $conffilename = 'config.ini';
my $showhelp = 0;

GetOptions(
	'conf|c=s' => \$conffilename,
	'help|h' => \$showhelp
);
if ($showhelp) {
	print "POMAL v$version\n";
	print "usage: main.pl [configfile]\n";
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

my ($dbh) = PGUI::loadDBwithSplashDetail();
print "\nStarting GUI...\n";
my %gui = PGUI::createMainWin($dbh);
Gtk2->main();
print "Oops... not finished coding this. Exiting normally.\n";
