# Graphic User Interface module
package PGUI;

use Gtk2 -init; # requires GTK perl bindings

use FIO;

sub config { return FIO::config(@_); }

sub Gtkdie {
	print "I am slain.\n";
	Gtk2->main_quit;
}
print ".";

sub createSplash {
	my $window = Gtk2::Window->new();
	$window->set_default_size(300,100);
	$window->move(int((Gtk2::Gdk->screen_width()/2) - 150),int((Gtk2::Gdk->screen_height()/2) - 50));
	$window->set_decorated(0);
	my $title = Gtk2::Label->new("POMAL");
	my $vb = Gtk2::VBox->new();
	my $progress = Gtk2::ProgressBar->new();
	my $splashdetail = Gtk2::Statusbar->new();
	$window->add($vb);
	$vb->pack_start($title,1,1,2);
	$vb->pack_end($splashdetail,0,0,2);
	$vb->pack_end($progress,0,0,2);
	# look at config and try to connect to the database.
	# if the database doesn't exist, try to create it.
	# or if user has chosen to use flatfile, import the XML.
	$window->show_all();
	return $window,$splashdetail,$progress,$vb;
}

sub createMainWin {
	my ($dbh,$w,$h) = @_;
	my %windowset;
	my $window = Gtk2::Window->new();
	$window->set_title("PersonalOfflineManga/AnimeList");

	my $button = Gtk2::Button->new('Quit');
	$button->signal_connect(clicked=> \&storeWindowExit );

	$window->signal_connect (destroy => \&Gtkdie ); # not saving position/size
	if (config('Main','savepos')) {
		unless ($w and $h) { $w = config('Main','width'); $h = config('Main','height'); }
		$window->set_default_size($w,$h);
		$window->move(config('Main','left') or 40,config('Main','top') or 30);
	}
	my $vbox = Gtk2::VBox->new();
	$window->add($vbox);
	my $ag = Gtk2::AccelGroup->new(); # create the hotkey group
	my $mb = buildMenus($window,$ag); # build the menus
	$windowset{accel} = $ag; # store the hotkey group
	$vbox->pack_start($mb,1,0,2);

	$vbox->pack_start($button,1,0,2);
	#pack it all into the hash for main program use
	$windowset{mainWin} = $window;
	$windowset{status} = getStatus();
	$vbox->pack_end($windowset{status},1,0,2);
	$windowset{menubar} = $mb;
	$windowset{vbox} = $vbox;

	$window->show_all();
	return %windowset;
}
print ".";

my $status = undef;
sub getStatus {
	unless(defined $status) {
		$status = Gtk2::Statusbar->new();
	}
	return $status;
}
print ".";

my $menus = undef;
sub buildMenus {
	unless(defined $menus) {
		my ($mainwin,$ag) = @_;

		$menus = Gtk2::MenuBar->new();
#		File >
		my ($itemF,$f) = itemize("_File",$menus,$ag);
#		File > Save (Only active if user chooses Flatfile DB)
		my $itemFS = itemize("_Save",$f);
#		accelerate($itemFS,"<Control>S",$ag);
#		$itemFS->signal_connect("activate",\&FIO::saveData);
#		File > Import
		my $itemFI = itemize("_Import",$f);
#		File > Export
		my $itemFE = itemize("_Export",$f);
#		File > Synchronize
		my $itemFO = itemize("Synchr_onize",$f);
#		File > Preferences
		my $itemFP = itemize("_Preferences",$f);
#		File > Quit
		my $itemFQ = itemize("_Quit",$f);
#		accelerate($itemFQ,"<Control>Q",$ag);
		$itemFQ->signal_connect("activate",\&storeWindowExit,$mainwin);
#		Help >
		my ($itemH,$h) = itemize("_Help",$menus,$ag);
#		Help > About
		my $itemHA = itemize("_About",$h);

	}
	return $menus;
}
print ".";

sub itemize { # menu item, that is...
	my ($label,$parent,$group) = @_;
	if (0) { print "itemize(@_)\n"; }
	my $a = Gtk2::MenuItem->new($label);
	my $b = undef;
	$a->show();
	$parent->append($a);
	if (defined $group) {
		$b = Gtk2::Menu->new();
		$b->set_accel_group($group);
		$b->show();
		$a->set_submenu($b);
		return $a,$b;
	}
	return $a;
}
print ".";

### Still haven't found how to properly do this. Followed the instructions I found, but nothing works.
sub accelerate {
	if (0) { print "accelerate(@_)\n"; }
	my ($a,$hotkey,$group) = @_;
	my ($k,$m) = Gtk2::Accelerator->parse($hotkey);
#	print "Accel $hotkey: $k,$m\n";
	$a->add_accelerator("activate",$group,$k,$m,[qw/visible/]);
}
print ".";

sub storeWindowExit {
	my ($caller,$window) = @_;
	my $s = 'Main';
	if (config($s,'savepos')) {
		my ($w,$h) = $window->get_size();
		my ($x,$y) = $window->get_position();
		config($s,'width',$w);
		config($s,'height',$h);
		config($s,'top',$y);
		config($s,'left',$x);
		FIO::saveConf();
	} else {
		print "Not storing window position.";
	}
	Gtkdie();
}
print ".";

sub loadDBwithSplashDetail {
	my ($splash,$text,$prog,$box) = createSplash();
	my $steps = 10;
	my $step = 0;
	my $base = "";
	$splash->present();
	$text->push(0,"Loading database config...");
	$prog->set_fraction(++$step/$steps);
	unless (defined config('DB','type')) {
		$text->push(0,"Getting settings from user...");
		$prog->set_fraction(++$step/$steps);
		# ask user for database type
		# unless type is SQLite:
		# ask user for host
		# ask user for SQL username, if needed by server (might not be, for localhost)
		# ask user if password required
		# push DB type back to config, as well as all other DB information, if applicable.
	} else {
		$base = config('DB','type');
	}
	my ($uname,$host,$pw) = (config('DB','user',undef),config('DB','host',undef),config('DB','password',0));
	# ask for password, if needed.
	my $passwd = ($pw ? askPass($splash) : undef);
	$text->push(0,"Connecting to database...");
	$prog->set_fraction(++$step/$steps);
	my ($dbh,$error) = PomalSQL::getDB($base,$host,'pomal',$passwd,$uname);
	unless (defined $dbh) { # error handling
		dieWithErrorbox($splash,$error);
	}
	# do stuff using this window...
	#$splash->destroy();
	return $dbh;
}
print ".";

sub askPass {
	my $caller = shift;
	# ask user for password, pass result back to caller
print "TODO: code askPass\n";
#$caller->destroy();
#exit(-1);
}
print ".";

sub dieWithErrorbox {
	my ($caller,$text) = @_;
	# display an error box. When user has pressed OK, kill caller and exit.
	# for now...
print "I am slain: $text\n";
	exit(0);
}
print ".";

print __PACKAGE__ . " OK; ";
1;
