package Bio::KBase::ConservedDomainSearch::Util;

use strict;
use IO::Handle;
use IPC::Run qw(run);
use File::Temp;
use Data::Dumper;
use Digest::MD5 'md5_hex';

sub new
{
    my($class, $cdd_data) = @_;

    my $self = {
	cdd_data => $cdd_data,
	evalue => 0.01,
    };

    return bless $self, $class;
}

sub rpsblast_command
{
    my($self, $in, $out) = @_;

    if (!defined($in))
    {
	$in = "-";
    }

    if (!defined($out))
    {
	$out = "-";
    }
    

    my @cmd = ("rpsblast",
	       "-query", $in,
	       "-evalue", $self->{evalue},
	       "-seg", "no",
	       "-outfmt", 5,
	       "-db", "$self->{cdd_data}/data/Cdd",
	       "-out", $out);
    return @cmd;
}

sub rpsbproc_command
{
    my($self, $in, $out) = @_;

    my @cmd = ("rpsbproc",
	       "-m", "std",
	       "-c", "$self->{cdd_data}/rpsbproc.ini");
    if ($in && $in ne '-')
    {
	push(@cmd, "-i", $in);
    }
    if ($out && $out ne '-')
    {
	push(@cmd, "-o", $out);
    }
    return @cmd;
}

sub process_protein_tuples
{
    my($self, $prots) = @_;

    my %md5;

    my $temp = File::Temp->new();
    for my $prot (@$prots)
    {
	print $temp ">$prot->[0]\n$prot->[1]\n";
	$md5{$prot->[0]} = md5_hex(uc($prot->[1]));
    }
    close($temp);

    my $temp_out = File::Temp->new();
    my $temp_err = File::Temp->new();

    my @blast = $self->rpsblast_command("$temp", "-");
    my @proc = $self->rpsbproc_command("-", "-");
    my $ok = run(\@blast, '|', \@proc, '>', $temp_out, '2>', $temp_err);
    close($temp_out);
    close($temp_err);

    if (!$ok)
    {
	die "Error running @blast | @proc:\n" . `cat $temp_err`;
    }

    my $fh;

    open($fh, "<", $temp_out) or die "Cannot open $temp_out: $!";

    my $ret = $self->parse_output($fh, \%md5);
    return $ret;

}

sub parse_output
{
    my($self, $fh, $md5) = @_;

    while (<$fh>)
    {
	last if /^DATA/;
    }

    my $cur_session;
    my $cur_query;
    my $cur_fid;
    my $cur_block;
    my $cur_data;

    my $ret = {};
    while (<$fh>)
    {
	chomp;
	my @fields = split(/\t/);
	my $tag = $fields[0];

	if ($tag eq 'ENDDATA')
	{
	    last;
	}
	elsif ($tag eq 'SESSION')
	{
	    $cur_session = $fields[1];
	}
	elsif ($tag eq 'ENDSESSION')
	{
	    undef $cur_session;
	}
	elsif ($tag eq 'QUERY')
	{
	    $cur_query = $fields[1];
	    my $len = $fields[3];
	    $cur_fid = $fields[4];
	    $cur_data = {
		md5 => $md5->{$cur_fid},
		len => $len, domain_hits => [],
		site_annotations => [],
		structural_motifs => [],
	    };
	}
	elsif ($tag eq 'ENDQUERY')
	{
	    # print "Finished $cur_fid: " . Dumper($cur_data);
	    $ret->{$cur_fid} = $cur_data;
	    undef $cur_fid;
	    undef $cur_data;
	}
	elsif ($tag eq 'DOMAINS')
	{
	    $cur_block = 'domain_hits';
	}
	elsif ($tag eq 'ENDDOMAINS')
	{
	    undef $cur_block;
	}
	elsif ($tag eq 'SITES')
	{
	    $cur_block = 'site_annotations';
	}
	elsif ($tag eq 'ENDSITES')
	{
	    undef $cur_block;
	}
	elsif ($tag eq 'MOTIFS')
	{
	    $cur_block = 'structural_motifs';
	}
	elsif ($tag eq 'ENDSITES')
	{
	    undef $cur_block;
	}
	else
	{
	    my($s, $q, @rest) = @fields;
	    if ($s ne $cur_session || $q ne $cur_query)
	    {
		die "Invalid input at line $.: $_\n";
	    }
	    push(@{$cur_data->{$cur_block}}, [ @rest ]);
	}
    }
    close($fh);

    return $ret;
}
1;
