package Bio::KBase::ConservedDomainSearch::ConservedDomainSearchImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

ConservedDomainSearch

=head1 DESCRIPTION



=cut

#BEGIN_HEADER
use Bio::KBase::ConservedDomainSearch::Util;
use Bio::KBase::DeploymentConfig;
use DBI;
use Digest::MD5 'md5_hex';
use Data::Dumper;
use JSON::XS;

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR

    my $cfg = Bio::KBase::DeploymentConfig->new($ENV{KB_SERVICE_NAME} || "ConservedDomainSearch");

    my $cdd_data = $self->{_cdd_data} = $cfg->setting("cdd-data");
    $cdd_data or die "ConservedDomainSearch: cdd-data must be set";
    -d $cdd_data or die  "ConservedDomainSearch: cdd-data setting $cdd_data is not a directory";

    my $util = Bio::KBase::ConservedDomainSearch::Util->new($self, $cdd_data);
    $self->{util} = $util;

    $self->{_batch_output_dir} = $cfg->setting('batch-output-dir');

    my $dbname = $self->{_dbname} = $cfg->setting('db-name');
    my $dbhost = $self->{_dbhost} = $cfg->setting('db-host');
    my $dbuser = $self->{_dbuser} = $cfg->setting('db-user');
    my $dbpass = $self->{_dbpass} = $cfg->setting('db-password');

    my $dbh = DBI->connect("dbi:mysql:$dbname;host=$dbhost", $dbuser, $dbpass,
		       { RaiseError => 1, AutoCommit => 0, PrintError => 1 });
    $dbh or die "Cannot connect to database: " . $DBI::errstr;

    $self->{_dbh} = $dbh;

    #
    # Read the cddid.tblfile
    #
    if (open(my $fh, "<", "$cdd_data/data/cddid.tbl"))
    {
	while (<$fh>)
	{
	    chomp;
	    my($id, $acc, $short, $desc, $len) = split(/\t/);
	    $self->{cddid}->{$id} = [$acc, $short, $desc, $len];
	}
	close($fh);
    }
    else
    {
	warn "Cannot open $cdd_data/cddid.tbl: $!";
    }
    
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 cdd_lookup

  $result = $obj->cdd_lookup($prots, $options)

=over 4

=item Parameter and return types

=begin html

<pre>
$prots is a reference to a list where each element is a protein_sequence
$options is a cdd_lookup_options
$result is a reference to a hash where the key is a string and the value is a cdd_result
protein_sequence is a reference to a list containing 3 items:
	0: (id) a string
	1: (md5) a string
	2: (protein) a string
cdd_lookup_options is a reference to a hash where the following keys are defined:
	data_mode has a value which is a string
	evalue_cutoff has a value which is a float
	cached_only has a value which is an int
cdd_result is a reference to a hash where the following keys are defined:
	md5sum has a value which is a string
	len has a value which is an int
	domain_hits has a value which is a reference to a list where each element is a domain_hit
	site_annotations has a value which is a reference to a list where each element is a site_annotation
	structural_motifs has a value which is a reference to a list where each element is a structural_motif
domain_hit is a reference to a list containing 10 items:
	0: (hit_type) a string
	1: (pssmid) a string
	2: (start) an int
	3: (end) an int
	4: (e_value) a float
	5: (bit_score) a float
	6: (accession) a string
	7: (short_name) a string
	8: (incomplete) a string
	9: (superfamily_pssmid) a string
site_annotation is a reference to a list containing 6 items:
	0: (annot_type) a string
	1: (title) a string
	2: (residue) a string
	3: (complete_size) a string
	4: (mapped_size) a string
	5: (source_domain_pssmid) a string
structural_motif is a reference to a list containing 4 items:
	0: (title) a string
	1: (from) an int
	2: (to) an int
	3: (source_domain_pssmid) a string

</pre>

=end html

=begin text

$prots is a reference to a list where each element is a protein_sequence
$options is a cdd_lookup_options
$result is a reference to a hash where the key is a string and the value is a cdd_result
protein_sequence is a reference to a list containing 3 items:
	0: (id) a string
	1: (md5) a string
	2: (protein) a string
cdd_lookup_options is a reference to a hash where the following keys are defined:
	data_mode has a value which is a string
	evalue_cutoff has a value which is a float
	cached_only has a value which is an int
cdd_result is a reference to a hash where the following keys are defined:
	md5sum has a value which is a string
	len has a value which is an int
	domain_hits has a value which is a reference to a list where each element is a domain_hit
	site_annotations has a value which is a reference to a list where each element is a site_annotation
	structural_motifs has a value which is a reference to a list where each element is a structural_motif
domain_hit is a reference to a list containing 10 items:
	0: (hit_type) a string
	1: (pssmid) a string
	2: (start) an int
	3: (end) an int
	4: (e_value) a float
	5: (bit_score) a float
	6: (accession) a string
	7: (short_name) a string
	8: (incomplete) a string
	9: (superfamily_pssmid) a string
site_annotation is a reference to a list containing 6 items:
	0: (annot_type) a string
	1: (title) a string
	2: (residue) a string
	3: (complete_size) a string
	4: (mapped_size) a string
	5: (source_domain_pssmid) a string
structural_motif is a reference to a list containing 4 items:
	0: (title) a string
	1: (from) an int
	2: (to) an int
	3: (source_domain_pssmid) a string


=end text



=item Description



=back

=cut

sub cdd_lookup
{
    my $self = shift;
    my($prots, $options) = @_;

    my @_bad_arguments;
    (ref($prots) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"prots\" (value was \"$prots\")");
    (ref($options) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"options\" (value was \"$options\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to cdd_lookup:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'cdd_lookup');
    }

    my $ctx = $Bio::KBase::ConservedDomainSearch::Service::CallContext;
    my($result);
    #BEGIN cdd_lookup

    #
    # Begin by computing md5 for each protein and determining if the value is in the
    # cache. If an md5 is provided, trust it.
    #
    # We also cache the parsed output, at least those retrieved with
    # a default (non-specified) evalue cutoff.
    #

    my @to_compute;
    my %md5_to_id;

    $options->{data_mode} ||= 'rep';
    my $data_mode = $options->{data_mode};

    my %map = ( rep => 'C', std => 'S', full => 'F' );
    $data_mode = $map{$data_mode};

    $result = {};

    my $dbh = $self->{_dbh};
    $dbh->ping();

    my $need = $self->{util}->incoming_prots_to_hash($prots);

    $self->{util}->query_parsed_output($data_mode, $need, $result);
    
    if (%$need)
    {
	$self->{util}->update_batch($need);
	$self->{util}->query_parsed_output($data_mode, $need, $result);
    }

    if (%$need)
    {
	print STDERR "AFTER update still need " . Dumper($need);
    }

    # #
    # # Now compute the ones that need computing. XML is returned in a File::Temp tempfile;
    # #

    # if (@to_compute && !$options->{cached_only})
    # {
    # 	my $temp_out = $self->{util}->process_protein_tuples(\@to_compute);
	
    # 	#
    # 	# Split and cache.
    # 	#
	
    # 	$self->{util}->split_postproc_xml($temp_out, sub {
    # 	    my($md5, $node) = @_;
    # 	    my $txt = $node->toString();
    # 	    my $r1 = $self->{util}->postproc_xml($txt, $options);

    # 	    if ($cache)
    # 	    {
    # 		my $dmkey = "$md5-$data_mode";
    # 		# print "Cache $md5\n";
    # 		$cache->set($md5, $txt);
    # 		$cache->set($dmkey, $r1->{$md5});
    # 	    }
    # 	    for my $id (@{$md5_to_id{$md5}})
    # 	    {
    # 		$result->{$id} = $r1->{$md5};
    # 	    }
    # 	});
    # }
    
    #END cdd_lookup
    my @_bad_returns;
    (ref($result) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"result\" (value was \"$result\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to cdd_lookup:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'cdd_lookup');
    }
    return($result);
}




=head2 cdd_lookup_domains

  $return = $obj->cdd_lookup_domains($prots)

=over 4

=item Parameter and return types

=begin html

<pre>
$prots is a reference to a list where each element is a protein_sequence
$return is a reference to a hash where the key is a string and the value is a reference to a list where each element is a string
protein_sequence is a reference to a list containing 3 items:
	0: (id) a string
	1: (md5) a string
	2: (protein) a string

</pre>

=end html

=begin text

$prots is a reference to a list where each element is a protein_sequence
$return is a reference to a hash where the key is a string and the value is a reference to a list where each element is a string
protein_sequence is a reference to a list containing 3 items:
	0: (id) a string
	1: (md5) a string
	2: (protein) a string


=end text



=item Description



=back

=cut

sub cdd_lookup_domains
{
    my $self = shift;
    my($prots) = @_;

    my @_bad_arguments;
    (ref($prots) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"prots\" (value was \"$prots\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to cdd_lookup_domains:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'cdd_lookup_domains');
    }

    my $ctx = $Bio::KBase::ConservedDomainSearch::Service::CallContext;
    my($return);
    #BEGIN cdd_lookup_domains

    $return = {};

    my $dbh = $self->{_dbh};
    $dbh->ping();

    my $need = $self->{util}->incoming_prots_to_hash($prots);

    $self->{util}->query_domain_coverage($need, $return);

    if (%$need)
    {
	$self->{util}->update_batch($need);
	$self->{util}->query_domain_coverage($need, $return);
    }

    if (%$need)
    {
	print STDERR "AFTER update still need " . Dumper($need);
    }
    
    #END cdd_lookup_domains
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to cdd_lookup_domains:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'cdd_lookup_domains');
    }
    return($return);
}




=head2 cache_add

  $obj->cache_add($xml_document)

=over 4

=item Parameter and return types

=begin html

<pre>
$xml_document is a string

</pre>

=end html

=begin text

$xml_document is a string


=end text



=item Description



=back

=cut

sub cache_add
{
    my $self = shift;
    my($xml_document) = @_;

    my @_bad_arguments;
    (!ref($xml_document)) or push(@_bad_arguments, "Invalid type for argument \"xml_document\" (value was \"$xml_document\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to cache_add:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'cache_add');
    }

    my $ctx = $Bio::KBase::ConservedDomainSearch::Service::CallContext;
    #BEGIN cache_add
    #END cache_add
    return();
}




=head2 pssmid_lookup

  $return = $obj->pssmid_lookup($pssmids)

=over 4

=item Parameter and return types

=begin html

<pre>
$pssmids is a reference to a list where each element is a string
$return is a reference to a hash where the key is a string and the value is a reference to a list containing 4 items:
	0: (accession) a string
	1: (shortname) a string
	2: (description) a string
	3: (len) a string

</pre>

=end html

=begin text

$pssmids is a reference to a list where each element is a string
$return is a reference to a hash where the key is a string and the value is a reference to a list containing 4 items:
	0: (accession) a string
	1: (shortname) a string
	2: (description) a string
	3: (len) a string


=end text



=item Description



=back

=cut

sub pssmid_lookup
{
    my $self = shift;
    my($pssmids) = @_;

    my @_bad_arguments;
    (ref($pssmids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"pssmids\" (value was \"$pssmids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to pssmid_lookup:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'pssmid_lookup');
    }

    my $ctx = $Bio::KBase::ConservedDomainSearch::Service::CallContext;
    my($return);
    #BEGIN pssmid_lookup

    $return = {};
    for my $id (@$pssmids)
    {
	my $val = $self->{cddid}->{$id};
	if ($val)
	{
	    $return->{$id} = $val;
	}
    }
	 
    #END pssmid_lookup
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to pssmid_lookup:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'pssmid_lookup');
    }
    return($return);
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 domain_hit

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 10 items:
0: (hit_type) a string
1: (pssmid) a string
2: (start) an int
3: (end) an int
4: (e_value) a float
5: (bit_score) a float
6: (accession) a string
7: (short_name) a string
8: (incomplete) a string
9: (superfamily_pssmid) a string

</pre>

=end html

=begin text

a reference to a list containing 10 items:
0: (hit_type) a string
1: (pssmid) a string
2: (start) an int
3: (end) an int
4: (e_value) a float
5: (bit_score) a float
6: (accession) a string
7: (short_name) a string
8: (incomplete) a string
9: (superfamily_pssmid) a string


=end text

=back



=head2 site_annotation

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 6 items:
0: (annot_type) a string
1: (title) a string
2: (residue) a string
3: (complete_size) a string
4: (mapped_size) a string
5: (source_domain_pssmid) a string

</pre>

=end html

=begin text

a reference to a list containing 6 items:
0: (annot_type) a string
1: (title) a string
2: (residue) a string
3: (complete_size) a string
4: (mapped_size) a string
5: (source_domain_pssmid) a string


=end text

=back



=head2 structural_motif

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 4 items:
0: (title) a string
1: (from) an int
2: (to) an int
3: (source_domain_pssmid) a string

</pre>

=end html

=begin text

a reference to a list containing 4 items:
0: (title) a string
1: (from) an int
2: (to) an int
3: (source_domain_pssmid) a string


=end text

=back



=head2 cdd_result

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
md5sum has a value which is a string
len has a value which is an int
domain_hits has a value which is a reference to a list where each element is a domain_hit
site_annotations has a value which is a reference to a list where each element is a site_annotation
structural_motifs has a value which is a reference to a list where each element is a structural_motif

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
md5sum has a value which is a string
len has a value which is an int
domain_hits has a value which is a reference to a list where each element is a domain_hit
site_annotations has a value which is a reference to a list where each element is a site_annotation
structural_motifs has a value which is a reference to a list where each element is a structural_motif


=end text

=back



=head2 protein_sequence

=over 4



=item Definition

=begin html

<pre>
a reference to a list containing 3 items:
0: (id) a string
1: (md5) a string
2: (protein) a string

</pre>

=end html

=begin text

a reference to a list containing 3 items:
0: (id) a string
1: (md5) a string
2: (protein) a string


=end text

=back



=head2 cdd_lookup_options

=over 4



=item Description

Only return cached data. Don't try to compute on the fly.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
data_mode has a value which is a string
evalue_cutoff has a value which is a float
cached_only has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
data_mode has a value which is a string
evalue_cutoff has a value which is a float
cached_only has a value which is an int


=end text

=back



=cut

1;
