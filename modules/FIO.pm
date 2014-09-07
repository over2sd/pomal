package FIO;

use Config::IniFiles;
use Exporter;
@EXPORT = qw( config saveConf );
print __PACKAGE__;

my $cfg = Config::IniFiles->new();

sub config {
	my ($section,$key,$value) = @_;
#	print "config(@_)\n";
	unless (defined $value) {
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
}
print ".";

sub loadConf {
	my $configfilename = shift || "config.ini";
	$cfg->SetFileName($configfilename);
	print "Seeking configuration file...";
	if ( -s $configfilename ) {
		print "found. Loading...";
		$cfg->ReadConfig();
	}
	validateConfig();
}
print ".";

print " OK; ";
1;
