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

    typedef tuple<string id, string md5, string protein> protein_sequence;

    typedef structure {
	string data_mode;	/* Defaults to "std". Valid values "rep", "std", "full" */
	float evalue_cutoff;	/* Defaults to 0.01. */
	int cached_only;	/* Only return cached data. Don't try to compute on the fly. */
    } cdd_lookup_options;	

    funcdef cdd_lookup(list<protein_sequence> prots, cdd_lookup_options options)
	returns (mapping<string id, cdd_result result> result);

    funcdef cdd_lookup_domains(list<protein_sequence> prots) returns (mapping<string id, list<string> domains>);

    funcdef cache_add(string xml_document) returns ();

    funcdef pssmid_lookup(list<string> pssmids)
	returns (mapping<string pssmid, tuple<string accession, string shortname, string description, string len>>);
							 
};
