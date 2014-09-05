################################ Episode Object ################################
package Episode;

sub new {
	my ($class,$i,$e,$n,$r) = @_;
	my $self = {
		ser_id => $i,
		epi_id => $e,
		epi_name => ($n  or ""),
		score => $r,
		obj_content => 0, # bitwise mask; described in Common.pm
		min_age => 0
	};
	bless $self,$class;
	return $self;
}
print ".";

# name
# score
# content
# rating

################################ Series Object #################################
package Series;

sub new {
	my ($class,$i,$n,%d) = @_;
	my $self = {
		dbid => $i,
		name => $n,
		episodes => 0,
		watched_episode => 0,
		started_date => "",
		finished_date => "", # also valid for drop date
		metadata => {}, # not currently stored anywhere
		title_score => 0,
		obj_content => 0, # bitwise mask; described in Common.pm
		min_age => 0,
		tstat => 0, # 0 - Plan-to-watch, 1 - Watching, 2 - On-hold, 3 - Rewatching, 4 - Completed, 5 - Dropped
		rewatched_episode => 0,
		rewatched_times => 0
	};
	bless $self,$class;
	if (%d) {
		# TODO: process other details here
#		foreach (keys %d) {
# total_eps
# watched_ep
# score
# status
# content
# rating
# metaData
#		}
	}
	return $self;
}
print ".";

# id
sub id {
	my ($self,$value) = @_;
	$self->{dbid} = $value if defined($value);
	return $self->{dbid};
}
print ".";

# title
sub title {
	my ($self,$value) = @_;
	$self->{name} = $value if defined($value);
	return $self->{name};
}
print ".";

sub total_eps {
	my ($self,$value) = @_;
	$self->{episodes} = $value if defined($value);
	return $self->{episodes};
}
print ".";

sub watched_ep {
	my ($self,$value) = @_;
	# check if value == max episodes, and pass back a second return value, because this may be called during import.
	my $max = ($value >= $max) ? 1 : 0;
	if ($self->{tstat} eq "RW") {
		$self->{rewatched_episode} = $value if defined($value);
		return $self->{rewatched_episode},$max,0;		
	} else {
		$self->{watched_episode} = $value if defined($value);
		# check for not status Watching and pass back an indicator to the caller that it needs to be set to complete.
		my $notwatch = ($self->{tstat} ne "WA") ? 1 : 0;
		return $self->{watched_episode},$max,$notwatch;
	}
}
print ".";

sub began {} # TODO: write date handlers

sub ended {} # TODO: write date handlers

sub metaData {
	my ($self,$key,$value) = @_;
	unless (defined $key) { return undef; }
	unless (defined $value) { return $self->{metadata}{$key}; }
#	print "Setting metadata $key to $value.\n";
	($self->{metadata}{$key} = $value) or return undef;
	return $value;
}
print ".";

sub score {
	my ($self,$value) = @_;
	$self->{title_score} = $value if defined($value);
	return $self->{title_score};
}
print ".";

sub status {
	my ($self,$value) = @_;
	$self->{tstat} = $value if defined($value);
	return $self->{tstat};
}
print ".";

sub rewatch_ended {} # TODO: write date handlers

sub content {
	# Takes a bitwise mask for $value! Do all processing of mask in calling function!
	my ($self,$value) = @_;
	$self->{obj_content} = $value if defined($value);
	return $self->{obj_content};
}
print ".";

sub rating {
	my ($self,$value) = @_;
	$self->{min_age} = $value if defined($value);
	return $self->{min_age};
}
print ".";


##############################  General Functions ##############################
package Anime;
print ".";

print __PACKAGE__ . " OK; ";
1;
