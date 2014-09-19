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

print " OK; ";
1;
