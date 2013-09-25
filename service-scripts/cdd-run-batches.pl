#
# Run the given set of batches in parallel.
#
# Usage: cdd-run-batches input-dir output-dir input-file [...]
#

use strict;
use Data::Dumper;
use IPC::Run qw(start finish);

@ARGV >= 4 or die "Usage: cdd-run-batches input-dir output-dir error-dir input-file [...]\n";

my $input_dir = shift;
my $output_dir = shift;
my $error_dir = shift;

my @input_files = @ARGV;

my @input_paths;

#my $exe = "$ENV{KB_TOP}/services/conserved_domain_search/bin/cdd-compute-domains";
#-x $exe or die "Executable $exe not found";

# find it in PATH
my $exe = 'cdd-compute-domains';

-d $output_dir or die "Output directory $output_dir not found";
-d $error_dir or die "Error directory $error_dir not found";

my @handles;
for my $f (@input_files)
{
    my $input_path = "$input_dir/$f";
    -f $input_path or die "Input path $input_path not found";
}

my @cmds;
for my $f (@input_files)
{
    my $in = "$input_dir/$f";
    my $out = "$output_dir/$f";
    my $err = "$error_dir/$f";
    my @cmd = ([$exe], '<', $in, '>', $out, '2>', $err);
    push(@cmds, [@cmd]);
    my $h = start @cmd;
    $h or die "Failed $! starting " . Dumper(\@cmd);
    push(@handles, $h);
}

for my $i (0..$#handles)
{
    print STDERR "Waiting for $input_files[$i] to complete\n";
    my $h = $handles[$i];
    $h->finish or die "Command for $input_files[$i] failed with $?" . Dumper($cmds[$i]);
}

