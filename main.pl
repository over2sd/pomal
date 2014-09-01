#!/usr/bin/perl

use strict;
use warnings;

use lib "./modules/";

# print "Loading modules...";

use PomalSQL;
use Anime;
use Manga;

# perhaps load these on-the-fly when they are needed?
use External;
use Import;
use Export;

use PGUI;

print "\nStarting GUI...\n";
my $mainwin = PGUI::createWindow();



Gtk2->main();
print "Oops... not finished coding this. Exiting normally.\n";
