use Data::Dumper;
use strict;
use File::Basename;
use Getopt::Long::Descriptive;
use DBI;
use IO::Compress::Bzip2 qw(bzip2);
use Bio::KBase::ConservedDomainSearch::Util;
use JSON::XS;

my $default_dbname = "cdd";
my $default_dbhost = "fir.mcs.anl.gov";
my $default_dbuser = "cdd";
my $default_dbpass = "";

my($opt, $usage) = describe_options("%c %o  data-file [data-file...",
				    ["dbname=s", "Database name", { default => $default_dbname }],
				    ["dbhost=s", "Database host", { default => $default_dbhost }],
				    ["dbuser=s", "Database username", { default => $default_dbuser }],
				    ["dbpass=s", "Database password", { default => $default_dbpass }],
				    ["help|h", "Show help message"]);
print($usage->text), exit(0) if $opt->help;
die($usage->text) if @ARGV < 1;

my $dbh = DBI->connect("dbi:mysql:" . $opt->dbname . ";host=" . $opt->dbhost, $opt->dbuser, $opt->dbpass,
		      { RaiseError => 0, AutoCommit => 0, PrintError => 0 });
$dbh or die "Cannot connect to database: " . $DBI::errstr;

#
# For our purposes here we don't need the data dir.
#
my $util = Bio::KBase::ConservedDomainSearch::Util->new('/tmp');

for my $file (@ARGV)
{
    my $fh;
    my $base = basename($file);
    if ($file =~ /gz$/)
    {
	open($fh, "-|", "gunzip", "-d", "-c", $file) or die "Cannot open unzip pipe: $!";
    }
    else
    {
	open($fh, "<", $file) or die "Cannot open $file: $!";
    }
    if ($base =~ /^(rep|std)/)
    {
	process_rep($file, $fh);
    }
    elsif ($base =~ /^raw/)
    {
	process_raw($file, $fh);
    }
    else
    {
	die "Unknown file $file\n";
    }
}

sub process_raw
{
    my($file, $fh) = @_;

    my $sth = $dbh->prepare(qq(INSERT INTO raw_output(md5, xml_text) VALUES (?, ?)));

    eval {
	$util->split_postproc_xml([IO => $fh], sub { raw_callback($sth, @_) });
    };
    if ($@)
    {
	warn "error processing $file: $@\n";
    }
    $dbh->commit();
}

sub raw_callback
{
    my($sth, $id, $data) = @_;
    my($md5) = $id =~ /gnl\|md5\|(\S+)/;
    $sth->execute($id, $data);
}

sub process_rep
{
    my($file, $fh) = @_;

    my($ret, $redundancy) = $util->parse_output($fh);
    print "Process $file ($redundancy)\n";

    my $json = JSON::XS->new->ascii->pretty(1);

    my $sth1 = $dbh->prepare(qq(INSERT INTO parsed_output(md5, redundancy, value) VALUES (?, '$redundancy', ?)));
    my $sth2 = $dbh->prepare(qq(INSERT INTO domain_coverage(md5, domains) VALUES (?, ?)));

    my $n = 0;
    while (my($id, $val) = each %$ret)
    {
	my($md5) = $id =~ /gnl\|md5\|(\S+)/;
	$md5 or die "Invalid id $id\n";
	my $out;
	my $jtext = $json->encode($val);
	# bzip2(\$jtext, \$out);
	$sth1->execute($md5, $jtext);

	if ($redundancy eq 'C')
	{
	    my $dhits = $val->{domain_hits};
	    
	    my @o;
	    for my $h (sort { $a->[2] <=> $b->[2] } @$dhits)
	    {
		if ($h->[0] eq 'Specific')
		{
		    push(@o, $h->[6]);
		}
	    }
	    my $d = join(" ", @o);
	    
	    $sth2->execute($md5, $d);
	}
	$n++;
    }
    $dbh->commit();
    print "   $n records\n";
}
				    
