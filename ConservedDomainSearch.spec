module ConservedDomainSearch
{
    typedef tuple<string hit_type, string pssmid, int start, int end, float e_value,
	float bit_score, string accession, string short_name, string incomplete,
	string superfamily_pssmid> domain_hit;

    typedef tuple<string annot_type, string title, string residue,
	string complete_size, string mapped_size, string source_domain_pssmid> site_annotation;

    typedef tuple<string title, int from, int to, string source_domain_pssmid> structural_motif;

    typedef structure {
	string md5sum;
	int len;
	list<domain_hit> domain_hits;
	list<site_annotation> site_annotations;
	list<structural_motif> structural_motifs;
    } cdd_result;

    typedef tuple<string id, string protein> protein_sequence;

    funcdef cdd_lookup(list<protein_sequence> prots) returns (mapping<string id, cdd_result result> result);
};
