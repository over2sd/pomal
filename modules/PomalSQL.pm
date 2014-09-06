# Module for MySQL database interactions (other DBs may be added later)
package PomalSQL;
print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(getDB closeDB);

# DB wrappers that call SQL(ite) functions, depending on which the user has chosen to use for a backend.
sub getDB {
	my ($dbtype) = shift;
	use DBI;
	my $dbh;
	if ($dbtype eq "L") { # for people without access to a SQL server
		$dbh = DBI->connect( "dbi:SQLite:pomal.dbl" ) || return undef,"Cannot connect: $DBI::errstr";
	} elsif ($dbtype eq "M") {
		my $host = shift || 'localhost';
		my $base = shift || 'pomal';
		my $password = shift || '';
		my $username = shift || $ENV{LOGNAME} || $ENV{USER} || getpwuid($<); # try to get username by various means if not passed it.
		# connect to the database
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username, $password) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		} else {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		}
	} else { #bad/no DB type
		return undef,"Bad/no DB type passed to getDB! (" . ($dbtype or "undef") . ")";
	}
	return $dbh,"";
}
print ".";

sub closeDB {
	my $dbh = shift;
	$dbh->disconnect;
	print "Database closed.";
}
print ".";

# functions for creating database
sub makeTables { # used for first run
	print "TODO: write a function to make tables.\n"; exit(-1);
}
print ".";

# functions for accessing database
sub doQuery {
	my ($qtype,$dbh,$statement,@parms) = @_;
	my $realq;
	my $safeq = $dbh->prepare($statement);
	if($qtype == 0){ # expect a scalar
		$realq = $safeq->execute(@parms);
		unless ("$realq" eq "1") {
#			print " result: $realq - ".$dbh->errstr;
			return "";
		}
		$realq = $safeq->fetchrow_arrayref();
		$realq = @{ $realq }[0];
	} elsif ($qtype == 1){
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_arrayref({ Slice => {} });
	} elsif ($qtype == 2) {
		$realq = $safeq->execute(@parms); # just execute and return the result or the error
		if($realq =~ m/^[0-9]+$/) {
			return $realq; 
		} else {
			return $dbh->errstr;
		}
	} elsif ($qtype == 3){
		unless (@parms) {
			print "Required field not supplied for doQuery(4). Give field name to act as hash keys.\n";
			return ();
		}
		my $key = pop(@parms);
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_hashref($key);
	} elsif ($qtype == 4){
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_arrayref();
	} elsif ($qtype == 5){
		$safeq->execute(@parms);
		$realq = $safeq->fetchrow_arrayref();
	} else {
		print "Invalid query type";
	}
	return $realq;
}
print ".";

sub table_exists {
	my ($dbh,$table) = @_;
	my $result = doQuery(0,$dbh,qq(SHOW TABLES LIKE ?;),$table);
	return (length($result) == 0) ? 0 : 1;
}
print ".";

print " OK; ";
1;
