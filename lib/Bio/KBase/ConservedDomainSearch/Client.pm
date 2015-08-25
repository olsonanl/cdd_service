package Bio::KBase::ConservedDomainSearch::Client;

use JSON::RPC::Client;
use POSIX;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;
my $get_time = sub { time, 0 };
eval {
    require Time::HiRes;
    $get_time = sub { Time::HiRes::gettimeofday() };
};


# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

=head1 NAME

Bio::KBase::ConservedDomainSearch::Client

=head1 DESCRIPTION





=cut

sub new
{
    my($class, $url, @args) = @_;
    
    if (!defined($url))
    {
	$url = 'http://localhost/7056';
    }

    my $self = {
	client => Bio::KBase::ConservedDomainSearch::Client::RpcClient->new,
	url => $url,
	headers => [],
    };

    chomp($self->{hostname} = `hostname`);
    $self->{hostname} ||= 'unknown-host';

    #
    # Set up for propagating KBRPC_TAG and KBRPC_METADATA environment variables through
    # to invoked services. If these values are not set, we create a new tag
    # and a metadata field with basic information about the invoking script.
    #
    if ($ENV{KBRPC_TAG})
    {
	$self->{kbrpc_tag} = $ENV{KBRPC_TAG};
    }
    else
    {
	my ($t, $us) = &$get_time();
	$us = sprintf("%06d", $us);
	my $ts = strftime("%Y-%m-%dT%H:%M:%S.${us}Z", gmtime $t);
	$self->{kbrpc_tag} = "C:$0:$self->{hostname}:$$:$ts";
    }
    push(@{$self->{headers}}, 'Kbrpc-Tag', $self->{kbrpc_tag});

    if ($ENV{KBRPC_METADATA})
    {
	$self->{kbrpc_metadata} = $ENV{KBRPC_METADATA};
	push(@{$self->{headers}}, 'Kbrpc-Metadata', $self->{kbrpc_metadata});
    }

    if ($ENV{KBRPC_ERROR_DEST})
    {
	$self->{kbrpc_error_dest} = $ENV{KBRPC_ERROR_DEST};
	push(@{$self->{headers}}, 'Kbrpc-Errordest', $self->{kbrpc_error_dest});
    }


    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 2)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function cdd_lookup (received $n, expecting 2)");
    }
    {
	my($prots, $options) = @args;

	my @_bad_arguments;
        (ref($prots) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"prots\" (value was \"$prots\")");
        (ref($options) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 2 \"options\" (value was \"$options\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to cdd_lookup:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'cdd_lookup');
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ConservedDomainSearch.cdd_lookup",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'cdd_lookup',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method cdd_lookup",
					    status_line => $self->{client}->status_line,
					    method_name => 'cdd_lookup',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function cdd_lookup_domains (received $n, expecting 1)");
    }
    {
	my($prots) = @args;

	my @_bad_arguments;
        (ref($prots) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"prots\" (value was \"$prots\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to cdd_lookup_domains:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'cdd_lookup_domains');
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ConservedDomainSearch.cdd_lookup_domains",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'cdd_lookup_domains',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method cdd_lookup_domains",
					    status_line => $self->{client}->status_line,
					    method_name => 'cdd_lookup_domains',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function cache_add (received $n, expecting 1)");
    }
    {
	my($xml_document) = @args;

	my @_bad_arguments;
        (!ref($xml_document)) or push(@_bad_arguments, "Invalid type for argument 1 \"xml_document\" (value was \"$xml_document\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to cache_add:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'cache_add');
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ConservedDomainSearch.cache_add",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'cache_add',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return;
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method cache_add",
					    status_line => $self->{client}->status_line,
					    method_name => 'cache_add',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: none

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function pssmid_lookup (received $n, expecting 1)");
    }
    {
	my($pssmids) = @args;

	my @_bad_arguments;
        (ref($pssmids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument 1 \"pssmids\" (value was \"$pssmids\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to pssmid_lookup:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'pssmid_lookup');
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ConservedDomainSearch.pssmid_lookup",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'pssmid_lookup',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method pssmid_lookup",
					    status_line => $self->{client}->status_line,
					    method_name => 'pssmid_lookup',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "ConservedDomainSearch.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'pssmid_lookup',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method pssmid_lookup",
            status_line => $self->{client}->status_line,
            method_name => 'pssmid_lookup',
        );
    }
}

sub _validate_version {
    my ($self) = @_;
    my $svr_version = $self->version();
    my $client_version = $VERSION;
    my ($cMajor, $cMinor) = split(/\./, $client_version);
    my ($sMajor, $sMinor) = split(/\./, $svr_version);
    if ($sMajor != $cMajor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Major version numbers differ.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor < $cMinor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Client minor version greater than Server minor version.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor > $cMinor) {
        warn "New client version available for Bio::KBase::ConservedDomainSearch::Client\n";
    }
    if ($sMajor == 0) {
        warn "Bio::KBase::ConservedDomainSearch::Client version is $svr_version. API subject to change.\n";
    }
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

package Bio::KBase::ConservedDomainSearch::Client::RpcClient;
use base 'JSON::RPC::Client';
use POSIX;
use strict;

#
# Override JSON::RPC::Client::call because it doesn't handle error returns properly.
#

sub call {
    my ($self, $uri, $headers, $obj) = @_;
    my $result;


    {
	if ($uri =~ /\?/) {
	    $result = $self->_get($uri);
	}
	else {
	    Carp::croak "not hashref." unless (ref $obj eq 'HASH');
	    $result = $self->_post($uri, $headers, $obj);
	}

    }

    my $service = $obj->{method} =~ /^system\./ if ( $obj );

    $self->status_line($result->status_line);

    if ($result->is_success) {

        return unless($result->content); # notification?

        if ($service) {
            return JSON::RPC::ServiceObject->new($result, $self->json);
        }

        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    elsif ($result->content_type eq 'application/json')
    {
        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    else {
        return;
    }
}


sub _post {
    my ($self, $uri, $headers, $obj) = @_;
    my $json = $self->json;

    $obj->{version} ||= $self->{version} || '1.1';

    if ($obj->{version} eq '1.0') {
        delete $obj->{version};
        if (exists $obj->{id}) {
            $self->id($obj->{id}) if ($obj->{id}); # if undef, it is notification.
        }
        else {
            $obj->{id} = $self->id || ($self->id('JSON::RPC::Client'));
        }
    }
    else {
        # $obj->{id} = $self->id if (defined $self->id);
	# Assign a random number to the id if one hasn't been set
	$obj->{id} = (defined $self->id) ? $self->id : substr(rand(),2);
    }

    my $content = $json->encode($obj);

    $self->ua->post(
        $uri,
        Content_Type   => $self->{content_type},
        Content        => $content,
        Accept         => 'application/json',
	@$headers,
	($self->{token} ? (Authorization => $self->{token}) : ()),
    );
}



1;
