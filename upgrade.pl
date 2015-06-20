#!/usr/bin/perl

use strict;
use warnings;
use utf8;

$|++; # Immediate STDOUT, maybe?

use Getopt::Long;
my $conffilename = 'config.ini';
my $showhelp = 0;
sub howVerbose { return 0; }

GetOptions(
	'conf|c=s' => \$conffilename,
	'help|h' => \$showhelp,
);
if ($showhelp) {
	print "POMAL database upgrader\n";
	print "Used for repairing database when changes are made to table structure";
	exit(0);
}
use lib "./modules/";

require Sui; # POMAL Data stores
require Common;
require FIO;

FIO::loadConf($conffilename);
# other defaults:
foreach (Sui::getDefaults()) {
	FIO::config(@$_) unless defined FIO::config($$_[0],$$_[1]);
}

require FlexSQL;
my $nodb = "Cannot upgrade nonexistent or unconfigured database.\nRun main.pl to configure database before upgrading.\n";
die "$nodb" unless (
	defined FIO::config('DB','type')
	and defined FIO::config('DB','host')
	);
my ($base,$uname,$host,$pw) = (FIO::config('DB','type',undef),FIO::config('DB','user',undef),FIO::config('DB','host',undef),FIO::config('DB','password',undef));
sub input {
	my ($a,$b) = @_;
	my $val;
	use Prima qw( Application Buttons MsgBox );
	$::wantUnicodeInput = 1;
	my $window = Prima::MainWindow->new(
		text => $a,
		size => [300,100],
	);
	my $box = $window->insert( Widget => name => 'box', pack => {fill => 'both'} );
	$box->insert( Label => text => $b, pack => { fill => 'x', expand => 0 } );
	my $ans = $box->insert( InputLine => text => '', writeOnly => 1, pack => { fill => 'x', expand => 0 } );
	$box->insert( Button => text => "Connect", onClick => sub { $val = $ans->text; $window->destroy; }, pack => { fill => 'x', expand => 0 } );
	Prima->run();
	return $val;
}
my $passwd = ($pw =~ /[Yy1]/ ? input("Login Credentials","Enter password for $uname\@$host:") : '');

print "Connecting to database...";
my $dbname = Sui::passData('dbname');
my ($dbh,$error,$errstr) = FlexSQL::getDB($base,$host,$dbname,$passwd,$uname);
unless (defined $dbh) {
	die "$nodb";
} else {
	print "Connected.\n";
}
print "Updating tables...";
open(TABDEF, "<${dbname}_up.msq"); # open table definition file
my @cmds = <TABDEF>;
my $tot = scalar @cmds;
print "\n[I] Importing $tot lines.";
foreach my $i (0 .. $#cmds) {
	my $st = $cmds[$i];
	if ('SQLite' eq $dbh->{Driver}->{Name}) {
		next if ($st =~ m/^USE/); # SQLite doesn't (properly) support USE? WTH
		$st =~ s/ UNSIGNED//g; # ...or unsigned?
		$st =~ s/INT\(\d+\) PRIMARY KEY/INTEGER PRIMARY KEY/; #...or short integer keys?
		$st =~ s/ AUTO_INCREMENT/ AUTOINCREMENT/g; #...or auto_increment?
	}
	my $error = FlexSQL::doQuery(2,$dbh,$st);
	print ".";
	if($error) { warn $error; }
}

print ".";

FlexSQL::closeDB($dbh);
print "\nDone.\n";
