package Bio::KBase::ConservedDomainSearch::Util;

use strict;
use IO::Handle;
use IPC::Run qw(run);
use File::Temp;
use Data::Dumper;
use Digest::MD5 'md5_hex';
use JSON::XS;
use XML::LibXML;

use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(db_batch_size));


sub new
{
    my($class, $impl) = @_;

    my $self = {
	impl => $impl,
	db_batch_size => 200,
	evalue => 0.01,
    };

    return bless $self, $class;
}

sub cdd_data { $_[0]->{impl}->{_cdd_data} }
sub dbh { $_[0]->{impl}->{_dbh} }
sub batch_output_dir { $_[0]->{impl}->{_batch_output_dir} }

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
	       "-db", $self->cdd_data . "/data/Cdd",
	       "-out", $out);
    return @cmd;
}

sub rpsbproc_command
{
    my($self, $in, $out, $options) = @_;

    my @cmd = ("/disks/patric-common/runtime/bin/rpsbproc",
	       "-c", $self->cdd_data . "/rpsbproc.ini");
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
	else
	{
	    push(@cmd, "-m", "rep");
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

    my $redundancy;

    while (<$fh>)
    {
	if (/^#Redundancy:\s*(\S+)/)
	{
	    $redundancy = $1;
	}
	last if /^DATA/;
    }

    my $rshort = substr($redundancy, 0, 1);

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
	elsif ($tag eq 'ENDMOTIFS')
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

    if (wantarray)
    {
	return($ret, $rshort);
    }
    else
    {
	return $ret;
    }
}

#
# Split XML into per-feature chunks. For each, invoke the given callback with the dom node.
# The code must do with the node what it needs since the node will be rewritten.
#

sub split_postproc_xml
{
    my($self, $file, $cb) = @_;

    my $dom;
    if (ref($file) eq 'ARRAY')
    {
	$dom = XML::LibXML->load_xml(@$file);
    }
    else
    {	    
	$dom = XML::LibXML->load_xml(location => $file);
    }
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

		$cb->($peg, $d2);

		$itop->removeChild($n);
	    }
	}
	else
	{
	    $r2->addChild($c->cloneNode(1));
	}
    }
}


sub query_parsed_output
{
    my($self, $data_mode, $need, $result) = @_;

    my @md5s = keys %$need;
    my $dbh = $self->dbh;
    
    while (@md5s)
    {
	my @q = splice(@md5s, 0, $self->db_batch_size);
	my $qs = join(", ", map { "?" } @q);

	my $res = $dbh->selectall_arrayref(qq(SELECT md5, value
					      FROM parsed_output
					      WHERE redundancy = ? AND md5 IN ($qs)), undef, $data_mode, @q);
	for my $ent (@$res)
	{
	    my($id, $value) = @$ent;
	    my $hits = delete $need->{$id};
	    my $v = decode_json($value);
	    for my $hit (@$hits)
	    {
		$result->{$hit->[0]} = $v;
	    }
	}
    }
}

sub query_domain_coverage
{
    my($self, $need, $result) = @_;

    my $dbh = $self->dbh;
    my @md5s = keys %$need;
    
    while (@md5s)
    {
	my @q = splice(@md5s, 0, $self->db_batch_size);
	my $qs = join(", ", map { "?" } @q);

	my $res = $dbh->selectall_arrayref(qq(SELECT md5, domains
					      FROM domain_coverage
					      WHERE md5 IN ($qs)), undef, @q);
	for my $ent (@$res)
	{
	    my($id, $value) = @$ent;
	    my $hits = delete $need->{$id};
	    for my $hit (@$hits)
	    {
		$result->{$hit->[0]} = [split(/\s+/, $value)];
	    }
	}
    }
}

sub incoming_prots_to_hash
{
    my($self, $prots) = @_;

    my $need = {};
    
    for my $ent (@$prots)
    {
	my($id, $md5, $seq) = @$ent;
	if (!$md5)
	{
	    $md5 = md5_hex(uc($seq));
	    $ent->[1] = $md5;
	}

	push(@{$need->{$md5}}, $ent);
    }
    return $need;
}

sub update_batch
{
    my($self, $need) = @_;

    #
    # Update the batch in need.
    # Create a batch ID.
    # Run rpsblast from created input.
    # Run rpsbproc postprocessing.
    # Update database.
    #


    my $dbh = $self->dbh;
    my $res = $dbh->do(qq(INSERT INTO update_batch() VALUES ()));
    my $id = $dbh->{'mysql_insertid'};

    print STDERR "Created batch $id\n";

    my $files;
    eval {

	my $tmp_in = File::Temp->new();
	for my $md5 (keys %$need)
	{
	    my $v = $need->{$md5}->[0];
	    print $tmp_in ">gnl|md5|$md5\n$v->[2]\n";
	}
	close($tmp_in);
	
	my $dir = $self->batch_output_dir;
	my $raw = sprintf("$dir/raw.%05d.gz", $id);
	$files = $raw;

	my @cmd = $self->rpsblast_command("-", "-");
	my $ok = run(\@cmd, '<', "$tmp_in", "|",
		     ["gzip"], '>', $raw);
	if (!$ok)
	{
	    die "Error creating blast with @cmd: $!\n";
	}
	for my $mode (qw(rep std))
	{
	    my $out = sprintf("$dir/$mode.%05d.gz", $id);
	    @cmd = $self->rpsbproc_command('-', '-', { data_mode => $mode });
	    my $ok = run(["gzip", "-d", "-c", $raw], '|',
			 \@cmd, '|',
			 ["gzip"], '>', $out);
	    $ok or die "error running @cmd: $!\n";
	    $self->process_parsed_data($out);
	    $files .= " $out";
	}
    };
    if ($@)
    {
	$dbh->do(qq(UPDATE update_batch
		    SET completion_date = current_timestamp, success = 0, status = ?
		    WHERE id = ?), undef, $@, $id);
	$dbh->commit();
	die $@;
    }
    else
    {
	$dbh->do(qq(UPDATE update_batch
		    SET completion_date = current_timestamp, success = 1, status = ?
		    WHERE id = ?
		   ), undef, "Wrote $files", $id);
	$dbh->commit();
    }
}

sub process_parsed_data
{
    my($self, $file) = @_;

    my $fh;
    if ($file =~ /gz$/)
    {
	open($fh, "-|", "gzip", "-d", "-c", $file) or die "Cannot gzip -d -c $file: $!";
    }
    else
    {
	open($fh, "<", $file) or die "Cannot open $file: $!";
    }

    my($ret, $redundancy) = $self->parse_output($fh);
    print STDERR "Process $file ($redundancy)\n";

    my $json = JSON::XS->new->ascii->pretty(1);

    my $dbh = $self->dbh;

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
	eval {
	    $sth1->execute($md5, $jtext);
	};
	if ($@)
	{
	    if ($@ !~ /Duplicate entry/)
	    {
		die $@;
	    }
	}
		    

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

	    eval {
		$sth2->execute($md5, $d);
	    };
	    if ($@)
	    {
		if ($@ !~ /Duplicate entry/)
		{
		    die $@;
		}
	    }
	}
	$n++;
    }
    $dbh->commit();
}


1;
