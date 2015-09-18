package FIO;

use Config::IniFiles;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( config saveConf loadConf );
print __PACKAGE__;

my $cfg = Config::IniFiles->new();
my $cfgread = 0;
my $emptywarned = 0;

Common::registerErrors('FIO::config',"\n[W] Using empty configuration!");
=item config SECTION KEY VALUE

Given an Ini SECTION and a KEY, returns the value of that key, if it is
in the Ini, or undef. Given a VALUE also, sets the KEY in the SECTION
to that VALUE.

=cut
sub config {
	my ($section,$key,$value) = @_;
	unless (defined $value) {
		unless ($cfgread or $emptywarned) {
			$emptywarned++;
			Common::errorOut('FIO::config',1,fatal => 0,trace => 0, depth => 1 ); }
		if (defined $cfg->val($section,$key,undef)) {
			return $cfg->val($section,$key);
		} else {
			return undef;
		}
	} else {
		if (defined $cfg->val($section,$key,undef)) {
			return $cfg->setval($section,$key,$value);
		} else {
			return $cfg->newval($section,$key,$value);
		}
	}
}
print ".";

sub validateConfig { # sets config values for missing required defaults
	my %defaults = (
		"width" => 480,
		"height" => 480,
		"savepos" => 0
		);
	foreach (keys %defaults) {
		unless (config('Main',$_)) {
			config('Main',$_,$defaults{$_});
		}
	}
	unless (config('Font','bighead')) {
		config('Font','bighead',"Arial 24");
	}
}
print ".";

sub saveConf {
	my $debug = $cfg->val('Debug','v',undef); # store the value of debug verbosity level
	$cfg->setval('Debug','v',undef); # don't output the command-line option for verbosity
	$cfg->RewriteConfig();
	$cfg->setval('Debug','v',$debug); # put the option back, in case program is still running
	$cfgread = 1; # If we're writing, I'll assume we have some values to use
}
print ".";

sub loadConf {
	my $configfilename = shift || "config.ini";
	$cfg->SetFileName($configfilename);
	Common::errorOut('inline',0,color => 1, fatal => 0, string => "\n[I] Seeking configuration file...");
	if ( -s $configfilename ) {
		print "found. Loading...";
		$cfg->ReadConfig();
		$cfgread = 1;
	}
	validateConfig();
}
print ".";

sub gz_decom {
	my ($ifn,$ofn,$guiref) = @_;
	my $window = $$guiref{mainWin};
	use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
	sub gzfail { 
		PGUI::sayBox(@_);
		return 0;
		}
#TODO: Make sure the failure return value passes through.
	gunzip($ifn => $ofn, Autoclose => 1)
		or gzfail($window,$GunzipError);
	return 1;
}
# TODO: Check this function more thoroughly to see if it does what is expected.
print ".";

sub getFileName {
	my ($caller,$parent,$guir,$title,$action,$oktext,$filter) = @_;
	unless (defined $parent) { $parent = $$guir{mainWin}; }
	$$guir{status}->push("Choosing file...");
	my $filebox = ($action eq 'open' ? Prima::OpenDialog->new(
		filter => $filter,
		fileMustExist => 1
	) : Prima::SaveDialog->new(
		filter => $filter,
		multiSelect => 0,
		noReadOnly => 1,
	));
	my $filename = undef;
	if ($filebox->execute()) {
		$filename = $filebox->fileName;
	} else {
		$$guir{status}->text("$oktext cancelled.");
	}
	$filebox->destroy();
	return $filename;
}
print ".";

print " OK; ";
1;
