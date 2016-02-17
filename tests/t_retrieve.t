use strict;
use Test::More;
use File::Temp;
use gjoseqlib;
use Data::Dumper;

use_ok('Bio::KBase::ConservedDomainSearch::ConservedDomainSearchImpl');

my $data = "/scratch/olson/cdd";
my $default_dbname = "cdd";
my $default_dbhost = "fir.mcs.anl.gov";
my $default_dbuser = "cdd";
my $default_dbpass = "";
my $batch = "/scratch/olson/cdd-batch";

my $cfile = File::Temp->new();
print $cfile <<END;
[ConservedDomainSearch]
batch-output-dir = $batch
db-name = $default_dbname
db-host = $default_dbhost
db-user = $default_dbuser
db-password = $default_dbpass
cdd-data = $data
END

close($cfile);

$ENV{KB_DEPLOYMENT_CONFIG} = "$cfile";

my $impl = new_ok('Bio::KBase::ConservedDomainSearch::ConservedDomainSearchImpl');

my $n = 10;
my @prots;
while (my($id, $def, $seq) = read_next_fasta_seq("/vol/core-seed/FIGdisk/FIG/Data/Organisms/83333.1/Features/peg/fasta"))
{
    push(@prots, [$id, undef, $seq]);
#    last if @prots >= $n;
}

my $res = $impl->cdd_lookup_domains(\@prots);
print Dumper($res);

my $res = $impl->cdd_lookup(\@prots, { data_mode => 'rep' });

my $nprots = @prots;
my $nfound = scalar keys %$res;
print "Found $nfound of $nprots\n";
#print Dumper($res);

done_testing;
