# Graphic User Interface module
package PGUI;

use Gtk2 -init; # requires GTK perl bindings
sub Gtkdie {
	print "I am slain.\n";
	Gtk2->main_quit;
}

sub createWindow {
	my $window = Gtk2::Window->new();
	$window->set_title("PersonalOfflineManga/AnimeList");
	my $button = Gtk2::Button->new('Quit');
	$button->signal_connect(clicked=> \&Gtkdie );
	$window->signal_connect (destroy => \&Gtkdie );
	$window->set_default_size(640,480);
	$window->add($button);
	$window->show_all();
	return $window;
}

print __PACKAGE__ . " OK; ";
1;
