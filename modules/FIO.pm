package FIO;

use Config::IniFiles;
use Exporter;
@EXPORT = qw( config saveConf );
print __PACKAGE__;

my $cfg = Config::IniFiles->new();
my $configfilename = "config.ini";
$cfg->SetFileName($configfilename);

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
			print "o";
			return $cfg->setval($section,$key,$value);
		} else {
			return $cfg->newval($section,$key,$value);
		}
	}
}
print ".";

sub validateConfig { # sets config values for missing required defaults
	my %defaults = (
		"width" => 640,
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

print " is seeking configuration file...";
if ( -s $configfilename ) {
	print "found. Loading...";
	$cfg->ReadConfig();
}
validateConfig();

1;
