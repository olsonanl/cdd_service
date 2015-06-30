package Bio::KBase::ConservedDomainSearch::Util;

use strict;
use IO::Handle;
use IPC::Run qw(run);
use File::Temp;
use Data::Dumper;
use Digest::MD5 'md5_hex';
use XML::LibXML;

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
    my($self, $in, $out, $options) = @_;

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
    if (ref($options) eq 'HASH')
    {
	my $dm = $options->{data_mode};
	if ($dm eq 'rep' || $dm eq 'std' || $dm eq 'full')
	{
	    push(@cmd, "-m", $dm);
	}
	if ($options->{evalue_cutoff})
	{
	    push(@cmd, "-e", $options->{evalue_cutoff});
	}
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
	print $temp ">$prot->[0]\n$prot->[2]\n";
    }
    close($temp);

    my $temp_out = File::Temp->new();
    my $temp_err = File::Temp->new();

    my @blast = $self->rpsblast_command("$temp", "-");
    my $ok = run(\@blast, '>', $temp_out, '2>', $temp_err);
    close($temp_out);
    close($temp_err);

    if (!$ok)
    {
	die "Error running @blast:\n" . `cat $temp_err`;
    }

    return $temp_out;
}

sub postproc_xml
{
    my($self, $xml, $options) = @_;

    my @proc = $self->rpsbproc_command("-", "-", $options);

    my $output;
    my $err;
    my $ok = run(\@proc, '<', \$xml, '>', \$output, '2>', \$err);

    if (!$ok)
    {
	die "Error running @proc:\n$err\n";;
    }

    my $ret = $self->parse_text($output);
    return $ret;
}

sub parse_text
{
    my($self, $txt) = @_;
    my $fh;
    open($fh, "<", \$txt) or die "Cannot open string fh";
    return $self->parse_output($fh);
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
		ref($md5) ? (md5 => $md5->{$cur_fid}) : (),
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

#
# Split XML into per-feature chunks. For each, invoke the given callback with the dom node.
# The code must do with the node what it needs since the node will be rewritten.
#

sub split_postproc_xml
{
    my($self, $file, $cb) = @_;
    
    my $dom = XML::LibXML->load_xml(location => $file);
    my $root = $dom->documentElement();

    my $d2 = XML::LibXML::Document->new($dom->version, $dom->encoding);
    my $r2 = $root->cloneNode();
    $d2->setDocumentElement($r2);
    
    for my $c ($root->childNodes())
    {
	my $id = $c->nodeName();

	if ($id eq 'BlastOutput_iterations')
	{
	    my $itop = $c->cloneNode(0);
	    $r2->addChild($itop);
	    for my $i ($c->childNodes())
	    {
		next if $i->nodeName() eq '#text';
		
		my $peg = $i->find("Iteration_query-def/text()");
		$peg or die "Cannot find ID in node: $i";
		
		my $n = $i->cloneNode(1);
		$itop->addChild($n);

		$cb->("$peg", $d2);

		$itop->removeChild($n);
	    }
	}
	else
	{
	    $r2->addChild($c->cloneNode(1));
	}
    }
}



1;
