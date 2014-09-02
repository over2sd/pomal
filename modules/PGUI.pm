# Graphic User Interface module
package PGUI;

use Gtk2 -init; # requires GTK perl bindings
sub Gtkdie {
	print "I am slain.\n";
	Gtk2->main_quit;
}
print ".";

sub createMainWin {
	my ($w,$h) = @_;
	my %windowset;
	my $confref = {};
	$$confref{size} = (($w or 640),($h or 480));
	$windowset{config} = $confref;
	my $window = Gtk2::Window->new();
	$window->set_title("PersonalOfflineManga/AnimeList");

	my $button = Gtk2::Button->new('Quit');
	$button->signal_connect(clicked=> \&Gtkdie );

	$window->signal_connect (destroy => \&Gtkdie ); # not saving position/size
	$window->set_default_size(($w or 640),($h or 480));

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

my $status = 0;
sub getStatus {
	if($status == 0) {
		$status = Gtk2::Statusbar->new();
	}
	return $status;
}
print ".";

my $menus = 0;
sub buildMenus {
	### ItemFactory (and therefore SimpleMenu) is deprecated, so back to the drawing board...
	if($menus == 0) {
		my ($mainwin,$ag) = @_;

		$menus = Gtk2::MenuBar->new();
#		File >
		my ($itemF,$f) = itemize("_File",$menus,$ag);
#		File > Import
		my $itemFI = itemize("_Import",$f);
#		File > Export
		my $itemFE = itemize("_Export",$f);
#		File > Synchronize
		my $itemFS = itemize("_Synchronize",$f);
#		File > Preferences
		my $itemFP = itemize("_Preferences",$f);
#		File > Quit
		my $itemFQ = itemize("_Quit",$f);
#		my ($k,$m);
#		Gtk2::accelerator_parse("<Control>Q",$k,$m); # can't find docs on how to call this properly.
#		$itemFQ->add_accelerator("activate",$ag,$k,$m,'ACCEL_VISIBLE');
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
	print "itemize(@_)\n";
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

sub storeWindowExit {
	my ($caller,$window) = @_;
	# store window size/pos here
	print $window->get_size();
	print " Haven't written the window storage code yet. Not saving.\n";
	Gtkdie();
}

print __PACKAGE__ . " OK; ";
1;
