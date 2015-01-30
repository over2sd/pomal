package Common;
print __PACKAGE__;
my @obj = qw( nudity violence language sex brutality blasphemy horror nihilism theology occult superpowers rape fanservice drugs hentai gambling war discrimination );
my %objindex;
@objindex{@obj} = (0..$#obj);
# used by contentMask and by contentList
sub contentMask {
	my ($key,$mask) = @_;
	# get position, or position just outside the array
	# (won't bother getBit, but beware using this return value elsewhere!)
	my $pos = get(\$objindex,$key,scalar @obj);
	unless (defined $mask) { return $pos; }
	return getBit($pos,$mask); # if passed a mask, return true/false that that key's bit is set in the mask.
}
print ".";

# contentList can be used by option setter to choose which types of content to allow to be noted/flitered
sub contentList { return @obj; }
print ".";

sub getBit { # returns bool
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	return ($mask & $pos) == $pos ? 1 : 0;
}
print ".";

sub setBit { # returns mask
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	return $mask | $pos;
}

sub unsetBit { # returns mask
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	return $mask ^ $pos;
}
print ".";

sub toggleBit { # returns mask
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	$pos = $mask & $pos ? $pos : $pos * -1;
	return $mask + $pos;
}
print ".";

sub get {
	my ($hr,$key,$dv) = @_;
	if ((not defined $hr) or (not defined $key) or (not defined $dv)) {
		warn "Safe getter called without required parameter(s)! ($hr,$key,$dv)";
		return undef;
	}
	if (exists $hr->{$key}) {
		return $hr->{$key};
	} else {
		return $dv;
	}
}
print ".";

# I've pulled these three functions into so many projects, I ought to release them as part of a library.
sub getColorsbyName {
	my $name = shift;
	my @colnames = qw( base red green yellow blue purple cyan ltred ltgreen ltyellow ltblue pink ltcyan white bluong blkrev gray );
	my $ccode = -1;
	++$ccode until $ccode > $#colnames or $colnames[$ccode] eq $name;
	$ccode = ($ccode > $#colnames) ? 0 : $ccode;
	return getColors($ccode);
}
print ".";

sub getColors{
	if (0) { # TODO: check for terminal color compatibility
		return "";
	}
	my @colors = ("\033[0;37;40m","\033[0;31;40m","\033[0;32;40m","\033[0;33;40m","\033[0;34;40m","\033[0;35;40m","\033[0;36;40m","\033[1;31;40m","\033[1;32;40m","\033[1;33;40m","\033[1;34;40m","\033[1;35;40m","\033[1;36;40m","\033[1;37;40m","\033[0;34;47m","\033[7;37;40m","\033[1;30;40m");
	my $index = shift;
	if ($index >= scalar @colors) {
		$index = $index % scalar @colors;
	}
	if (defined($index)) {
		return $colors[int($index)];
	} else {
		return @colors;
	}
}
print ".";

sub findIn {
	my ($v,@a) = @_;
	if ($debug > 0) {
		use Data::Dumper;
		print ">>".Dumper @a;
		print "($v)<<";
	}
	unless (defined $a[$#a] and defined $v) {
		use Carp qw( croak );
		my @loc = caller(0);
		my $line = $loc[2];
		@loc = caller(1);
		my $file = $loc[1];
		my $func = $loc[3];
		croak("FATAL: findIn was not sent a \$SCALAR and an \@ARRAY as required from line $line of $func in $file. Caught");
		return -1;
	}
	my $i = 0;
	while ($i < scalar @a) {
		print ":$i:" if $debug > 0;
		if ("$a[$i]" eq "$v") { return $i; }
		$i++;
	}
	return -1;
}
print ".";

sub nround {
	my ($prec,$value) = @_;
	use Math::Round qw( nearest );
	my $target = 1;
	while ($prec > 0) { $target /= 10; $prec--; }
	while ($prec < 0) { $target *= 10; $prec++; } # negative precision gives 10s, 100s, etc.
	if ($debug) { print "Value $value rounded to $target: " . nearest($target,$value) . ".\n"; }
	return nearest($target,$value);
}
print ".";

# Perhaps this should be loaded from an external file, so the user can modify it without diving into code?
my %ambiguous = (
	tag => ["tag_(context1)","tag_(context2)"],
	othertag => ["othertag_(context1)","othertag_(context2)"]
);
sub disambig {
	# if given a gui reference, display an askbox to select from options for disambiguation
	# if tag is key in hash, return first value; otherwise, return tag
}
print ".";

sub revGet { # works best on a 1:1 hash
	my ($target,$default,%hash) = @_;
	foreach (keys %hash) {
		return $_ if ($target eq $hash{$_});
	}
	return $default;
}
print ".";

# Status hashes
sub getStatHash { my $typ = shift; return (wat=>($typ eq 'man' ? "Read" : "Watch") . "ing",onh=>"On-hold",ptw=>"Plan to " . ($typ eq 'man' ? "Read" : "Watch"),com=>"Completed",drp=>"Dropped"); } # could be given i18n
sub getStatOrder { return qw( wat onh ptw com drp ); }
sub getStatIndex { return ( ptw => 0, wat => 1, onh => 2, rew => 3, com => 4, drp => 5 ); }
print ".";

=item indexOrder()
	Expects a reference to a hash that contains hashes of data as from fetchall_hashref.
	This function will return an array of keys ordered by whichever internal hash key you provide.
	@array from indexOrder($hashref,$]second-level key by which to sort first-level keys[)
=cut
sub indexOrder {
	my ($hr,$orderkey) = @_;
	my %hok;
	foreach (keys %$hr) {
		my $val = $_;
		my $key = qq( $$hr{$_}{$orderkey} );
		$hok{$key} = [] unless exists $hok{$key};
		push(@{ $hok{$key} },$val); # handles identical values without overwriting key
	}
	my @keys;
	foreach (sort keys %hok){
		push(@keys,@{ $hok{$_} });
	}
	return @keys;
}
print ".";

sub shorten {
	my ($text,$len,$endlen) = @_;
	return $text unless (defined $text and length($text) > $len); # don't do anything unless text is too long.
	my $part2length = ($endlen or 7); # how many characters after the ellipsis?
	my $part1length = $len - ($part2length + 3); # how many characters before the ellipsis?
	if ($part1length < $part2length) { # if string would be lopsided (end part longer than beginning)
		$part2length = 0; # end with ellipsis instead of string ending
		$part1length = $len - 3;
	}
	if ($part1length < 7 or $part1length + 3 > $len - $part2length) { # resulting string is too short, or doesn't chop off enough for ellipsis to make sense.
		warn "Shortening string of length " . length($text) . " ($text) to $len does not make sense. Skipping.\n";
		return $text;
	}
	my $part1 = substr($text,0,$part1length); # part before ...
	my $part2 = substr($text,-$part2length); # part after ...
	$text = "$part1...$part2"; # strung together with ...
	return $text;
}
print ".";

print " OK; ";
1;
