package FIO;

use Config::IniFiles;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( config saveConf loadConf );
print __PACKAGE__;

my $cfg = Config::IniFiles->new();
my $cfgread = 0;

sub config {
	my ($section,$key,$value) = @_;
#	print "config(@_)\n";
	unless (defined $value) {
		unless ($cfgread) { warn "Using empty configuration!"; }
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
		"width" => 375,
		"height" => 480,
		"savepos" => 0
		);
	foreach (keys %defaults) {
		unless (config('Main',$_)) {
			config('Main',$_,$defaults{$_});
		}
	}
}
print ".";

sub saveConf {
	$cfg->RewriteConfig();
	$cfgread = 1; # If we're writing, I'll assume we have some values to use
}
print ".";

sub loadConf {
	my $configfilename = shift || "config.ini";
	$cfg->SetFileName($configfilename);
	print "Seeking configuration file...";
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
		PGUI::sayBox($window,$_);
		return 0;
		}
	gunzip($ifn => $ofn, Autoclose => 1)
		or gzfail($GunzipError);
	return 1;
}
print ".";

sub getFileName {
	my ($caller,$parent,$guir,$title,$action,$oktext,$pattern) = @_;
	unless (defined $parent) { $parent = $$gui{mainWin}; }
	$$guir{status}->push(0,"Choosing file...");
	my $filebox = Gtk2::FileChooserDialog->new($title,$parent,$action,'Cancel','cancel',$oktext,'accept');
	my $filter = Gtk2::FileFilter->new();
	$filter->add_pattern($pattern or "*");
	$filebox->set_filter($filter);
	my $filename = undef;
	if ('accept' eq $filebox->run()) {
		$filename = $filebox->get_filename();
	} else {
		$$guir{status}->push(0,"Import cancelled.");
	}
	$filebox->destroy();
	return $filename;
}
print ".";

print " OK; ";
1;
