#
# Submit the batches in the input directory to sge.
#
# This mostly involves counting to get the correct number of tasks 
# and constructing the qsub properly.
#

@ARGV == 5 or die "Usage: $0 input-dir output-dir error-dir input-file-printf-fmt queue-name";

my $input_dir = shift;
my $output_dir = shift;
my $error_dir = shift;
my $fmt = shift;
my $queue = shift;

-d $input_dir or die "input dir $input_dir does not exist";
-d $output_dir or die "output dir $output_dir does not exist";
-d $error_dir or die "error dir $error_dir does not exist";

my $i = 0;

while (1)
{
    my $f = sprintf $fmt, $i;
    last if (! -f "$input_dir/$f");
    $i++;
}

my $step = 4;			# Magellan.
my $start = 0;
my $end = int($i / $step) * $step;

my @cmd =  ("qsub",
	    "-t", "$start-$end:$step", 
	    "-b", "yes",
	    "-e", $error_dir, 
	    "-N", "cdd",
	    "-o", $error_dir,
	    "-q", $queue,
	    "-r", "yes",
	    "-V",
	    "cdd-sge-run-script",
	    $input_dir, $output_dir, $error_dir, $fmt);

print "Submit: @cmd\n";
my $rc = system(@cmd);
$rc == 0 or die "Error rc=$rc running @cmd\n";

