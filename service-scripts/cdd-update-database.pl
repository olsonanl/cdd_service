use strict;
use Data::Dumper;
use Bio::KBase::DeploymentConfig;
use File::Basename;
use URI;

my $cdd_url = 'ftp://ftp.ncbi.nih.gov/pub/mmdb/cdd/cdd.tar.gz';
my $cddid_url = 'ftp://ftp.ncbi.nih.gov/pub/mmdb/cdd/cddid.tbl.gz';

my $cdd_file = basename($cdd_url);
my $cddid_file = basename($cddid_url);

my @format_cmds = (
'makeprofiledb -title Pfam.v.26.0 -in Pfam.pn -out Pfam -threshold 9.82 -scale 100.0 -dbtype rps -index true',
'makeprofiledb -title COG.v.1.0 -in Cog.pn -out Cog -threshold 9.82 -scale 100.0 -dbtype rps -index true',
'makeprofiledb -title KOG.v.1.0 -in Kog.pn -out Kog -threshold 9.82 -scale 100.0 -dbtype rps -index true',
'makeprofiledb -title CDD.v.3.10 -in Cdd.pn -out Cdd -threshold 9.82 -scale 100.0 -dbtype rps -index true',
'makeprofiledb -title PRK.v.6.00 -in Prk.pn -out Prk -threshold 9.82 -scale 100.0 -dbtype rps -index true',
);
die Dumper(\@format_cmds);
my $cfg = Bio::KBase::DeploymentConfig->new('Cdd');

my $cdd_data = $cfg->setting('cdd-data');
$cdd_data or die "$0: configuration variable cdd-data was not set";
if (! -d $cdd_data)
{
    mkdir $cdd_data || die "$0: cannot mkdir $cdd_data: $!";
}

my $cdd_tmp = "$cdd_data/tmp";
if (! -d $cdd_tmp)
{
    mkdir $cdd_tmp || die "$0: cannot mkdir $cdd_tmp: $!";
}

download_to_tmp($cdd_url, $cdd_file);
download_to_tmp($cddid_url, $cddid_file);

chdir($cdd_data) or die "cannot chdir $cdd_data: $!";
if (! -f "Cdd.pn")
{
    die;
    run("tar", "-z", "-x", "-f", "$cdd_tmp/$cdd_file");
}

run("gunzip < $cdd_tmp/$cddid_file > cddid.tbl");

run("formatrpsdb", "-t", "Cdd", "-i", "Cdd.pn", "-o", "T", "-f", "9.82", "-n", "Cdd", "-S", "100.0");

sub download_to_tmp
{
    my($url, $file) = @_;
    print "DL '$url'\n";

    my $rc;
    if (! -s "$cdd_tmp/$file")
    {
	$rc = system("curl", "-L", "-o", "$cdd_tmp/$file", $url);
	$rc == 0 or die "Error downloading $url to $cdd_tmp/$file";
    }
}

sub run
{
    my(@cmd) = @_;
    print "@cmd\n";
    my $rc = system(@cmd);
    $rc == 0 or die "Cmd failed with rc=$rc: @cmd";
}
