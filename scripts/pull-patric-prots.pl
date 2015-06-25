#
# Build the data directory for a family computation based on the list
# of genera pulled using the PATRIC data api.
#

use strict;
use File::Path 'make_path';
use File::Slurp;
use LWP::UserAgent;
use Getopt::Long::Descriptive;
use Data::Dumper;
use URI;
use JSON::XS;
use DBI;
use Proc::ParallelLoop;
use gjoseqlib;

my($opt, $usage) = describe_options("%c %o data-dir",
				    ["solr-url|d=s", "Solr API url", { default => 'https://www.patricbrc.org/api' }],
				    ["help|h", "Show this help message"],
				   );

print($usage->text), exit if $opt->help;
die($usage->text) if @ARGV != 1;

my $dir = shift;

my $batch_size = 500_000;

get_proteins($opt, $dir, $batch_size);

sub get_proteins
{
    my($opt, $dir, $batch_size) = @_;

    my $idx = 1;
    
    my $ua = LWP::UserAgent->new;

    my %seen;
    
    my $lg;
    my $cur;

    my $fh;
    my $fn = sprintf("$dir/query.%05d.fa", $idx++);
    
    open($fh, ">", $fn) or die "cannot open $fn: $!";

    my $block = 100;
    my $mark = "*";
    my $sum = 0;

    while (1)
    {
	my $q = make_query(q => 'feature_type:CDS',
			   fl => 'feature_id,aa_sequence_md5,aa_sequence',
			   rows => $block,
			   start => 0,
			   sort => 'feature_id asc',
			   cursorMark => $mark
			  );
	my $url = $opt->solr_url . "/genome_feature/?$q";
	
	print STDERR "$url\n";
	my $res = $ua->get($url,
			   'Content-type' => 'application/solrquery+x-www-form-urlencoded',
			   'Accept' => 'application/solr+json',
			  );
	if (!$res->is_success)
	{
	    die "Failed: " . $res->status_line;
	}

	my $r = $res->content;
	my $data = decode_json($r);

	if (ref($data) ne 'HASH')
	{
	    die "Invalid response text: '$r'\n";
	}
	my $next = $data->{nextCursorMark};
	$mark = $next;
	if (!$next)
	{
	    warn "request failed (no nextCursorMark)";
	    last;
	}
	my $n = @{$data->{response}->{docs}};
	print "Got $n - nextCursorMark='$mark'\n";
	if ($n == 0)
	{
	    last;
	}
	    
	for my $ent (@{$data->{response}->{docs}})
	{
	    my $md5 = $ent->{aa_sequence_md5};
	    if (!$seen{$md5}++)
	    {
		my $seq = $ent->{aa_sequence};
		print_alignment_as_fasta($fh, ["gnl|md5|$md5", '', $seq]);
		$sum += length($seq);
		if ($sum > $batch_size)
		{
		    close($fh);
		    $fn = sprintf("$dir/query.%05d.fa", $idx++);
		    open($fh, ">", $fn) or die "cannot open $fn: $!";
		    $sum = 0;
		}
	    }
	}
    }
    close($fh);
}

sub make_query
{
    my(@list) = @_;

    my @q;
    while (@list)
    {
	my($k, $v) = splice(@list, 0, 2);
	push(@q, "$k=$v");
    }
    return join("&", @q);
}
