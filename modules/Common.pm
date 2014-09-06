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

print " OK; ";
1;
