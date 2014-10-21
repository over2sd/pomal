# Graphic User Interface module
use strict; use warnings;
package PGUI;
print __PACKAGE__;
	
use Prima qw(Application Buttons MsgBox FrameSet StdDlg Sliders Notebooks ScrollWidget Grids);
use GK;

use FIO qw( config );

sub buildMenus { #Replaces Gtk2::Menu, Gtk2::MenuBar, Gtk2::MenuItem
	my $self = shift;
	my $menus = [
		[ '~File' => [
#			['~Import', 'Ctrl-O', '^O', &\importGUI],
			['~Export', sub { message('export!') }],
#			['~Synchronize', 'Ctrl-S', '^S', sub { message('synch!') }],
#			['~Preferences', \&callOptBox],
			[],
			['Close', 'Ctrl-W', km::Ctrl | ord('W'), sub { $self->close() } ],
		]],
		[ '~Help' => [
			['~About',sub { message('About!') }], #\&aboutBox],
		]],
	];
	return $menus;
}

my %windowset;

sub createMainWin {
	my ($version,$w,$h) = @_;
	my $window = Prima::MainWindow->new(
		text => (config('Custom','program') or "PersonalOfflineManga/AnimeList") . " v.$version",
		size => [($w or 750),($h or 550)],
	);
	if (config('Main','savepos')) {
		unless ($w and $h) { $w = config('Main','width'); $h = config('Main','height'); }
		$window->size($w,$h);
		$window->move((config('Main','left') or 40),(config('Main','top') or 30));
	}
# This line does nothing apparent:
#	if (defined config('Font','body')) { applyFont($window,0); }
	$window->set( menuItems => buildMenus($window));

	#pack it all into the hash for main program use
	$windowset{mainWin} = $window;
	$windowset{status} = getStatus($window);
	return \%windowset;
}
print ".";

sub createSplash {
	my $window = shift;
	my $vb = $window->insert( VBox => name => "splashbox", pack => { anchor => "n", fill => 'x', expand => 0, relx => 0.5, rely => 0.5, padx => 5, pady => 5, }, );
	my $label = $vb->insert( Label => text => "Loading POMAL...", pack => { fill=> "x", expand => 0, side => "left", relx => 0.5, padx => 5, pady => 5,},);
	my $progress = $vb->insert( Gauge =>
		value => 0,	
		relief => gr::Raise,
		height => 35,
		pack => { fill => 'x', expand => 0, padx => 3, side => "left", },
	);
	return $progress,$vb;
}
print ".";

my $status = undef;
sub getStatus {
	my $win = shift;
	unless(defined $status) {
		unless (defined $win) { $win = getGUI(); }
		$status = StatusBar->new(owner => $win)->prepare();
	}
	return $status;
}
print ".";

sub loadDBwithSplashDetail {
	my $gui = shift;
	my ($prog,$box) = createSplash($$gui{mainWin});
	my $text = $$gui{status};
	# do stuff using this window...
	my $pulse = 0;
	my $steps = 4;
	my $step = 0;
	my $base = "";
	$text->text("Loading database config...");
	$prog->value(++$step/$steps*100);
	my $curstep = $box->insert( Label => text => "");
	unless (defined config('DB','type')) {
		$steps ++; # number of steps in type dialogue
		my $dbtype = undef;
		$text->text("Getting settings from user...");
		$prog->value(++$step/$steps*100); # 0 (matches else)
		my $result = message("Choose database type:",mb::Cancel | mb::Yes | mb::No,
			buttons => {
					mb::Yes, {
						text => "MySQL", hint => "Use if you have a MySQL database.",
					},
					mb::No, {
						text => "SQLite", hint => "Use if you can't use MySQL.",
					},
					mb::Cancel, {
						text => "Quit", hint => "Abort loading the program (until you set up your database?)",
					},
			}
		);
		if ($result == mb::Yes) {
			$dbtype = 'M';
		} elsif ($result == mb::No) {
			$dbtype = 'L';
		} else {
			print "Exiting (abort).\n";
			$$gui{mainWin}->close();
		}
		$text->text("Saving database type...");
		$prog->value(++$step/$steps*100);
		# push DB type back to config, as well as all other DB information, if applicable.
		config('DB','type',$dbtype);
		$base = $dbtype;
	} else {
		$curstep->text("Using configured database type.");
		$prog->value(++$step/$steps*100);
		$base = config('DB','type');
	}
	unless (defined config('DB','host')) {
		$steps ++; # host
		# unless type is SQLite:
		unless ($base eq 'L') {
			$steps ++; # type dialogue
			$curstep->text("Enter database login info");
			$text->text("Getting login credentials...");
			$prog->value(++$step/$steps*100); # 0
		# ask user for host
			my $host = input_box("Server Info","Server address:","127.0.0.1");
		# ask user for SQL username, if needed by server (might not be, for localhost)
			my $uname = input_box("Login Credentials","Username (if required)","");
		# ask user if username required
			my $umand = (message("Username required?",mb::YesNo) == mb::Yes ? 1 : 0);
		# ask user if password required
			my $pmand = (message("Password required?",mb::YesNo) == mb::Yes ? 1 : 0);
			$curstep->text("---");
			# save data from entry boxes...
			$text->text("Saving server info...");
			$prog->value(++$step/$steps*100); # 1
			$uname = ($umand ? $uname : undef);
			config('DB','host',$host); config('DB','user',$uname); config('DB','password',$pmand);
		} else {
			$text->text("Using file as database...");
			config('DB','host','localfile'); # to prevent going through this branch every time
			$prog->value(++$step/$steps*100); # 0a
		}
		FIO::saveConf();
	}
	my ($uname,$host,$pw) = (config('DB','user',undef),config('DB','host',undef),config('DB','password',0));
	# ask for password, if needed.
	my $passwd = ($pw ? undef : input_box("Login Credentials","Enter password for $uname\@$host:"));
	$curstep->text("Establish database connection.");
	$text->text("Connecting to database...");
	$prog->value(++$step/$steps*100);
	my ($dbh,$error) = PomalSQL::getDB($base,$host,'pomal',$passwd,$uname);
	if ($error =~ m/Unknown database/) { # rudimentary detection of first run
		$steps++;
		$curstep->text("Database not found. Attempting to initialize...");
		$text->text("Attempting to initialize database...");
		$prog->value(++$step/$steps*100);
		($dbh,$error) = PomalSQL::makeDB($base,$host,'pomal',$passwd,$uname);
	}
	unless (defined $dbh) { # error handling
		message("ERROR: $error");
		print "Exiting (no DB).\n";
		$$gui{mainWin}->close();
	} else {
		$curstep->text("---");
		$text->text("Connected.");
	}
	unless (PomalSQL::table_exists($dbh,'tags')) {
		$steps++;
		$prog->value(++$step/$steps*100);
		$text->text("Attempting to initialize database tables...");
		PomalSQL::makeTables($dbh);
	}
	$text->text("Done loading database.");
	$prog->value(++$step/$steps*100);
	if (0) { print "Splash screen steps: $step/$steps\n"; }
	$box->close();
	return $dbh;
}
print ".";

print " OK; ";
1;
