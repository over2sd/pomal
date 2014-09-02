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
		my $itemF = Gtk2::MenuItem->new("_File");
		$itemF->show();
		$menus->append($itemF);
		my $f = Gtk2::Menu->new();
		$f->set_accel_group($ag);
		$f->show();
		$itemF->set_submenu($f);
#		File > Import
#		File > Export
#		File > Synchronize
#		File > Preferences
#		File > Quit
		my $itemFQ = Gtk2::MenuItem->new("_Quit");
		$itemFQ->show();
#		my ($k,$m);
#		Gtk2::accelerator_parse("<Control>Q",$k,$m); # can't find docs on how to call this properly.
#		$itemFQ->add_accelerator("activate",$ag,$k,$m,'ACCEL_VISIBLE');
		$f->append($itemFQ);
		$itemFQ->signal_connect("activate",\&storeWindowExit,$mainwin);

#		Help >
#		Help > About

	}
	return $menus;
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
