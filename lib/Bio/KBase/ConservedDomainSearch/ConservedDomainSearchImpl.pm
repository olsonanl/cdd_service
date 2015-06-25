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
#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 cdd_lookup

  $result = $obj->cdd_lookup($prots)

=over 4

=item Parameter and return types

=begin html

<pre>
$prots is a reference to a list where each element is a protein_sequence
$result is a reference to a hash where the key is a string and the value is a cdd_result
protein_sequence is a reference to a list containing 2 items:
	0: (id) a string
	1: (protein) a string
cdd_result is a reference to a hash where the following keys are defined:
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
$result is a reference to a hash where the key is a string and the value is a cdd_result
protein_sequence is a reference to a list containing 2 items:
	0: (id) a string
	1: (protein) a string
cdd_result is a reference to a hash where the following keys are defined:
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
    my($prots) = @_;

    my @_bad_arguments;
    (ref($prots) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"prots\" (value was \"$prots\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to cdd_lookup:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'cdd_lookup');
    }

    my $ctx = $Bio::KBase::ConservedDomainSearch::Service::CallContext;
    my($result);
    #BEGIN cdd_lookup
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
domain_hits has a value which is a reference to a list where each element is a domain_hit
site_annotations has a value which is a reference to a list where each element is a site_annotation
structural_motifs has a value which is a reference to a list where each element is a structural_motif

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
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
a reference to a list containing 2 items:
0: (id) a string
1: (protein) a string

</pre>

=end html

=begin text

a reference to a list containing 2 items:
0: (id) a string
1: (protein) a string


=end text

=back



=cut

1;
