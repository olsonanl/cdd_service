#
# Run-script for SGE. 
# 
# Runs a cdd batch.
#
# Our inputs are $SGE_TASK_ID .. $SGE_TASK_STEPSIZE-1
#
# Cmdline is input-dir output-dir error-dir input-file-format
#
# input-file-format is a sprintf string that given the input id 
# derives the filename.
#

use strict;
use Time::HiRes 'gettimeofday';

my $start_id = $ENV{SGE_TASK_ID};
defined($start_id) or die "No sge SGE_TASK_ID found";
defined($ENV{SGE_TASK_STEPSIZE}) or die "no sge SGE_TASK_STEPSIZE found";

my $end_id = $start_id + $ENV{SGE_TASK_STEPSIZE} - 1;

@ARGV == 4 or die "Usage: $0 input-dir output-dir error-dir input-file-format \n";

my $input_dir = shift;
my $output_dir = shift;
my $error_dir = shift;
my $fmt = shift;

-d $input_dir or die "input dir $input_dir does not exist";
-d $output_dir or die "output dir $output_dir does not exist";
-d $error_dir or die "error dir $error_dir does not exist";

my @files;
for my $id ($start_id .. $end_id)
{
    my $file = sprintf $fmt, $id;
    if (-f "$input_dir/$file")
    {
	push(@files, $file);
    }
}
if (!@files)
{
    die "No input files found for @ARGV start=$start_id end=$end_id\n";
}

my @cmd = ("cdd-run-batches", $input_dir, $output_dir, $error_dir, @files);
my $host = `hostname`;
chomp $host;
my $date = `date`;
chomp $date;
print STDERR "Start on $host at $date: @cmd\n";
my $start = gettimeofday;
my $rc = system(@cmd);
my $end = gettimeofday;
my $elap = $end - $start;
print STDERR "$elap\t$start\t$end\n";
$rc == 0 or die "cmd failed with rc=$rc: @cmd\n";
