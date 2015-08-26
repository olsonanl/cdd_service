use strict;
use Test::More;
use Digest::MD5 'md5_hex';
use File::Temp;
use gjoseqlib;
use Data::Dumper;

use_ok('Bio::KBase::ConservedDomainSearch::ConservedDomainSearchImpl');

my $data = "/scratch/olson/cdd";
my $batch = "/scratch/olson/cdd-batch";
my $default_dbname = "cdd";
my $default_dbhost = "fir.mcs.anl.gov";
my $default_dbuser = "cdd";
my $default_dbpass = "";

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
my %need;
my $c = 0;
while (my($id, $def, $seq) = read_next_fasta_seq("/vol/core-seed/FIGdisk/FIG/Data/Organisms/83333.1/Features/peg/fasta"))
{
    my $md5 = md5_hex(uc($seq));
    push(@{$need{$md5}}, [$id, $md5, $seq]);
    last if $c++ > $n;
}

$impl->{util}->update_batch(\%need);

done_testing;
