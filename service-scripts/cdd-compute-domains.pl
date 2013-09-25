use strict;
use Data::Dumper;
use Bio::KBase::DeploymentConfig;
use Bio::KBase::CDMI::Client;
use File::Basename;
use URI;
use IPC::Run 'run';

#
# Compute domains given protein sequence ids on stdin. Write
# records suitable for linkage to the ConservedDomainModel entity
# on stdout.

my $cfg = Bio::KBase::DeploymentConfig->new('Cdd');

my $cdd_data = $cfg->setting('cdd-data');
$cdd_data or die "$0: configuration variable cdd-data was not set";
if (! -f "$cdd_data/Cdd.pn")
{
    die "Cdd data not found in $cdd_data";
}

my $cs = Bio::KBase::CDMI::Client->new();

my @prots = <>;
chomp @prots;

while (@prots)
{
    my @protbatch = splice(@prots, 0, 2000);

    my $seqs = $cs->get_entity_ProteinSequence(\@protbatch, ['sequence']);
    
    my $input;
    for my $prot_id (@protbatch)
    {
	my $seq = $seqs->{$prot_id};
	next unless ref($seq) && $seq->{sequence};
	$input .= ">$prot_id\n" . $seq->{sequence} . "\n";
    }

    my @cmd = ('rpsblast', "-d", "$cdd_data/Cdd", "-F", "T", "-e", "0.01", "-m", "9");
    my $output;
    run \@cmd, '<', \$input, '>', \$output;
    
    for my $l (split(/\n/, $output))
    {
	next if $l =~ /^#/;
	my($qry, $subj, @x) = split(/\t/, $l);
	$subj =~ s/^gnl\|CDD\|//;
	print join("\t", $subj, $qry, @x), "\n";
    }
}
