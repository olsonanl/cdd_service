#
# Build genome-update batches.
#
# We construct batches of around 500K amino acid sequences (extrapolating
# linearly from a single K12 run this should give us batches that take
# around 30 minutes to compute).
#
# We use as a starting point the proteins in the bacterial genomes. We need
# to keep track of the protein ids that we have already seen so that we
# don't duplicate any computations.
# 

use strict;
use Data::Dumper;
use Bio::KBase::CDMI::Client;

my %seen;

my $cs = Bio::KBase::CDMI::Client->new();

my $ret = $cs->query_entity_Genome([['domain', '=', 'Bacteria']], ['scientific_name']);

my @genomes = values %$ret;
my $max_size = 500_000;
my $cur_size = 0;
my $batch_dir = "batches";
my $cur_batch = 0;

-d $batch_dir || mkdir($batch_dir) || die "cannot mkdir $batch_dir: $!";
my $batch_fh;

my $batch_file = sprintf("$batch_dir/batch.%06d", $cur_batch++);
print "Opening $batch_file\n";
open($batch_fh, ">", $batch_file) or die "cannot write $batch_file: $!";

for my $g (@genomes)
{
    my($genome_id, $genome_name) = @$g{'id', 'scientific_name'};

    print "$genome_id\t$genome_name\n";

    my $fids = $cs->genomes_to_fids([$genome_id], ['peg', 'CDS']);
    $fids = $fids->{$genome_id};
    my $prots = $cs->fids_to_proteins($fids);
    my @need;
    for my $fid (@$fids)
    {
	my $prot = $prots->{$fid};
	next if $seen{$prot};
	push(@need, $prot);
	$seen{$prot} = 1;
    }
    next unless (@need);

    my $seqs = $cs->get_entity_ProteinSequence(\@need, ['sequence']);

    for my $prot (@need)
    {
	print $batch_fh "$prot\n";
	$cur_size += length($seqs->{$prot}->{sequence});
	if ($cur_size > $max_size)
	{
	    close($batch_fh);
	    print "Wrote $batch_file size=$cur_size\n";
	    $cur_size = 0;
	    $batch_file = sprintf("$batch_dir/batch.%06d", $cur_batch++);
	    print "Opening $batch_file\n";
	    open($batch_fh, ">", $batch_file) or die "cannot write $batch_file: $!";
	}
    }
}
close($batch_fh);
