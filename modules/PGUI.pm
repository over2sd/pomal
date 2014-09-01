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
	$window->signal_connect (destroy => \&Gtkdie );
	$window->set_default_size(($w or 640),($h or 480));

	my $vbox = Gtk2::VBox->new();
	$window->add($vbox);
#	my $mb = buildMenus($window);
	$vbox->pack_start($mb,1,0,2);

	$vbox->pack_start($button,1,0,2);
	#pack it all into the hash for main program use
	$windowset{mainWin} = $window;
	$windowset{status} = getStatus();
	$vbox->pack_end($windowset{status},1,0,2);
#	$windowset{menubar} = $mb;
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
	
	#### use Simplemenu to make this
	if($menus == 0) {
		my $mainwin = shift;
#### not done here
	}
	return $menus;
}
print ".";

print __PACKAGE__ . " OK; ";
1;
