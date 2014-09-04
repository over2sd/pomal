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
	my ($class,$i,$n,@d) = @_;
	my $self = {
		dbid => $i,
		name => $n,
		episodes => 0,
		watched_episode => 0,
		started_date => "",
		finished_date => "", # also valid for drop date
		meta_data => {},
		score => 0,
		obj_content => 0, # bitwise mask; described in Common.pm
		min_age => 0
		status => 0, # 0 - Plan-to-watch, 1 - Watching, 2 - On-hold, 3 - Rewatching, 4 - Completed, 5 - Dropped
		rewatched_episode => 0,
		rewatched_times => 0
	};
	bless $self,$class;
	return $self;
}
print ".";

# id
# title
# total_eps
# watched_ep
# began
# ended
# metaData
# score
# status
# rewatch_ended
# content
# rating

##############################  General Functions ##############################
package Anime;
print ".";

print __PACKAGE__ . " OK; ";
1;
