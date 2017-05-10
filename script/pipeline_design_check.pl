#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;

my $usage = <<"END_USAGE";
Usage: $0 --input=<user input file> --template=<template.fa> [Options]
Required Parameters:
    --input             a tab-delimited text file listing primer choosing regions, one per line: 
                        [template_ID] [target_start] [target_length] [product_size_min] [product_size_max]
    --template          a FASTA file (recommend indexed with Samtools) of your template genome/transcriptome

Optional Parameters:
    --samtools          Your Samtools path: /path/to/samtools   
                        Default: [samtools] (Assume in your system PATH)
    --primer3bin        Your primer3_core path: /path/to/primer3_core
                        Default: [primer3_core] (Assume in your system PATH)
    --primer3setting    A Primer3 setting file. Default: [ ] (Using all the default parameters in Primer3)
    --pypy              Your pypy(OR python) path: /path/to/pypy
                        Default: [pypy] (Assume in your system PATH)
    --MFEprimer         Your MFEprimer.py path: /path/to/MFEprimer.py
                        Default: [MFEprimer.py] (Assume in your system PATH)
    --num_cpu           The number of CPUs used to run multiple MFEprimer instances simultaneously.
                        Default: 1
    --checkingdb        one or multiple FASTA file (indexed by MFEPrimer) of your background genome/transcriptome.
                        Default: the same as --template
    --checking_size_start
                        Parameters from MFEprimer: Lower limit of the checking amplicon size range 
                        in bp. Default: [50]
    --checking_size_stop
                        Parameters from MFEprimer: Upper limit of the checking amplicon size range 
                        in bp. Default: [5000]
    --outputdir         The output directory. Default: [./PrimerServerOutput]
    --output_detail     [0/1] Whether to produce HTML(1) or TEXT(0) file. If you run this pipeline in command-line, 
                        you should not change this parameter. Default: [0]
    --primer_num_retain
                        The max number of primers for each site to return. It must be used together with 
                        --primer3setting and should not be larger than PRIMER_NUM_RETURN in the setting
                        file. Default: [10]
    --help              Print this help and exit
END_USAGE

my $help;
my $input;
my $samtools = "samtools";
my $primer3bin = "primer3_core";
my $primer3setting = "";
my $template;
my $dir = "PrimerServerOutput";
my $checkingdb;
my $size_start = 50;
my $size_stop = 5000;
my $pypy = "pypy";
my $MFEPrimer = "MFEprimer.py";
my $detail = 0;
my $retain = 10;
my $cpu = 1;
GetOptions(
    'help'          =>  \$help,
    'input=s'       =>  \$input,
    'template=s'    =>  \$template,
    'samtools=s'    =>  \$samtools,
    'primer3bin=s'  =>  \$primer3bin,
    'primer3setting=s'=>\$primer3setting,
    'pypy=s'        =>  \$pypy,
    'MFEprimer=s'   =>  \$MFEPrimer,
    'checkingdb=s'    =>  \$checkingdb,
    'checking_size_start=i' => \$size_start,
    'checking_size_stop=i' => \$size_stop,
    'num_cpu=i'     =>  \$cpu,
    'output_detail=i' => \$detail,
    'primer_num_retain=i' => \$retain,
    'outputdir=s'   =>  \$dir,
);
if (!$checkingdb) {
    $checkingdb = $template;
}


if ($help or !$input or !$template) {
    print "$usage";
    exit(0);
}


####### Check Tool Path #########
if (system("which $samtools >/dev/null 2>&1")!=0 && system("$samtools >/dev/null 2>&1")!=0) {   # Samtools path is error
    die "Can not find Samtools\n";
}
if (system("which $primer3bin >/dev/null 2>&1")!=0 && system("$primer3bin >/dev/null 2>&1")!=0) {   # Primer3 path is error
    die "Can not find Primer3\n";
}
if (system("which $pypy >/dev/null 2>&1")!=0 && system("$pypy >/dev/null 2>&1")!=0) {   # Pypy path is error
    die "Can not find pypy OR python\n";
}
if (system("which $MFEPrimer >/dev/null 2>&1")!=0 && system("$MFEPrimer >/dev/null 2>&1")!=0) {   # MFEPrimer path is error
    die "Can not find MFEprimer\n";
}

####### Check query and db #########
if (!-e($input)) {
    die "Can not find file $input\n";
}
if (!-e($template)) {
    die "Can not find file $template\n";
}

####### Run primer3, generate [primer3output.txt] and [primer3output.simple.table.txt] #########
my $cmd = "perl _run_primer3.pl --input=$input --db=$template "
            ."--primer3bin=$primer3bin --samtools=$samtools --outputdir=$dir ";
if ($primer3setting) {
    $cmd .= "--primer3setting=$primer3setting";
}
system $cmd;

####### Run MFEPrimer, generate [specificity.check.result.txt] ##########
$cmd = "perl _run_specificity_check.pl --input=$dir/primer3output.simple.table.txt --MFEPrimer=$MFEPrimer --num_cpu=$cpu "
            ."--db='$checkingdb' --pypy=$pypy --outputdir=$dir --size_start=$size_start --size_stop=$size_stop";
system $cmd;

####### Retrieve Results, generate [primer.final.result.txt] ##########
$cmd = "perl _run_final_selection.pl --primer3result=$dir/primer3output.txt "
              ."--specificity=$dir/specificity.check.result.txt --retain=$retain "
              ."--outputdir=$dir";
if ($detail) {
    $cmd .= " --detail=1";
}
system $cmd;

