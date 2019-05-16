#!/usr/bin/perl
# https://github.com/zenGator/mw2xwf
# zG:20190321

# Get current signatures:  with curl -LO mwscan.s3.amazonaws.com/mwscan.txt


use strict;
use warnings;
use Getopt::Std;
use File::Copy;
use constant XWFLIM => 100000;
sub usage;
sub capOutput;

# switches followed by a : expect an argument
my $commandname=$0=~ s/^.*\///r;
my %opt=();
getopts('hi:l:o:s', \%opt) or usage();
#our($opt_i, $opt_h);
my $refile=$opt{o}.".RE" if $opt{s};
my $reFH;

#ToDo:  allow saving RE lines alone (i.e., don't transform from grep form)

usage () if ( $opt{h} or (scalar keys %opt) == 0 ) ;
if ( $opt{s} and ! $opt{o}) {
    print "ERROR ($commandname):  -o required when using -s.\n\n";
    usage();
    }

my $infile=$opt{i};
open(my $fh, '<:encoding(UTF-8)', $infile)
  or die "Could not open file '$infile' $!";

my $outFH=*STDOUT;
if ($opt{o}) {
    open($outFH, '>:encoding(UTF-8)', $opt{o}) 
        or die "Could not open file '$opt{o}': $!\n";
    }

my $logfile=*STDERR;
if ($opt{l}) {
    open($logfile, '>:encoding(UTF-8)', $opt{l}) 
        or die "Could not open file '$opt{l}': $!\n";
    }
*STDERR=$logfile;

if ($opt{s}) {
    open ($reFH, '>:encoding(UTF-8)', $refile) 
        or die "Could not open file '$refile': $!\n";
    }

    
my $x=0;
my $chars=0;  #XWF has 100,000-char limit on search string block (see XWFLIM constant)
my $rechars=0;
my $outFiCount=0;
my $reFiCount=0;
my $regEx;

while (my $row = <$fh>) {  
    #get a line
    $x++;
    $regEx=0;
    chomp $row;
    my $orig_row=$row;

    # transforms
    $row =~ s/([^\\]\[[^]]*)\\d([^]]*\])/$1#$2/g;
    $row =~ s/\\d/#/g;
    $row =~ s/([^\\]\[[^]]*)\\w([^]]*\])/$1_a-z#$2/g;
    $row =~ s/\\w/[_a-z#]/g;

    if ( $row =~ /[^\\]\[[^]]*\\b[^\]]*\]/ ) {
    warn "word boundary inside braces (could be problematic):  ## on line $x\n";
    }
    #  $row =~ s/(\[[^]]*)\\b([^]]*\])/$1_a-z#$2/g;
    $row =~ s/\\b/[^_a-z#]/g;
    $row =~ s/([^\\]\[[^]]*)\\W([^\]]*\])/$1\\x21-\\x2F\\x3A-\\x40\\x5B-\\x60\\x7B-\\x7E$2/g;
    $row =~ s/\\W/[\\x21-\\x2F\\x3A-\\x40\\x5B-\\x60\\x7B-\\x7E]/g;
    $row =~ s/([^\\]\[[^]]*)\\s([^\]]*\])/$1 \\x09-\\x0D$2/g;
    $row =~ s/\\s/[ \\x09-\\x0D]/g;
    $row =~ s/([^\\]\[[^]]*)0-9([^\]]*\])/$1#$2/g;
    $row =~ s/([^\\]\{)(,[^}]*\})/${1}0$2/g;
    $row =~ s/,\}/,9\}/g;
    #the next patterns:
        # {[not number]
        # [not number]}
    #   shouldn't exist, but in mwscan version c. 2019.03.25, there is one example:
    # var ....={..:function\(x,y\){return x!==y;}
    $row =~ s/([^\\])(\{[^0-9])/$1\\$2/g;
    $row =~ s/([^\\0-9])\}/$1\\}/g;
    #if ($row =~ /\\\{/ ) {
     #   warn "curly brace on line $x: recommend manual review\n";
      #  warn "\toriginal:\t$orig_row\n\tfixed (so far):\t\t$row\n";
       # }
    # let's flag this possibility:
    #next works, 2019.04.02 1620
    if ($row =~ /[^\\]\{[^}]*[^},0-9]+[^}]*\}/ ) {
        warn "possible bad usage of curly braces for RegEx on line $x: recommend manual review\n";
        warn "\toriginal:\t$orig_row\n\tfixed (so far):\t\t$row\n";
        }
  

#  fix double-digits inside brackets
  $row =~ s/([^\\]\[[^\]]*)##([^\\\]]*\])/$1#$2/g;
  
  if ($row =~ /##/ ) {
    warn "repetitive repetition of ## on line $x:  recommend manual review\n";
    warn "\toriginal:\t$orig_row\n\tfixed:\t\t$row\n";
  }
  if ($row =~ /[^\\]\]\[/ ) {
    warn "sequential char sets on line $x:  recommend manual review\n";
    warn "\t$orig_row\n\t$row\n";
  }
#show results
    if ( $opt{s} && $row =~ /[^\\][]\{\}\(.*?+[]/){
        $regEx=1;
        if ( $rechars + length($row) > (XWFLIM -  1 ) )) {
        #save off current outfile, copy, & reopen fresh
            capOutput($reFiCount++,length($row),$refile, $reFH);
            $chars=0;
            }
        $rechars+=length($row)+2; # the 2 is for the \r\n
        printf $reFH "%s\r\n", $row;
        }
    else {
        #add'l transform to make a pure-string search term
        if ( $opt{s}) {
            $row =~ s/\\\\/\x1A/g;
            $row =~ s/\\//g;
            $row =~ s/\x1A/\\/g;
            }
        if ( $chars + length($row) > XWFLIM - 1 and $opt{o}) {
        #save off current outfile, copy, & reopen fresh
            capOutput($outFiCount++,length($row),$opt{o}, $outFH);
            $chars=0;
            }
        $chars+=length($row)+2; # the 2 is for the \r\n
        printf $outFH "%s\r\n", $row;
        }
    
}

sub usage() {
    print "like this: \n\t".$commandname." -i [infile] -o [outfile] [-l [logfile]] [-s]\n";
    print "\nThis adjusts RegEx (as used in mwscan, possibly POSIX-compliant) into XWF-compatible RegEx/grep strings.  Because XWF has a limit of ".XWFLIM." characters for any set of simultaneous-search strings, if the output file reaches that limit, multiple output files are created by appending a digit (zero-indexed, of course) to the output file name.  Each will need to be run as a separate simultaneous search.\n";
    print "\nThe -s switch will [s]plit the output into two [sets of] files:  one that works as simple string search terms and another that contains RegEx terms (requiring the 'GREP syntax' option be selected).  You must identify an output file if using -s.\n";
    exit 1;
    }

sub capOutput {
    # XWF can only ingest XWFLIM chars for simul-search
    my $count=shift;
    my $len=shift;
    my $file=shift;
    my $FH=shift;
    printf STDERR "XWF limit reached, saving output file segment as: %s\n",$file."_".$count;
    close $FH;
    move($file,$file."_".$count) or die "Couldn't rename '$file': $!\n";
    if ($regEx){
        open($FH, '>:encoding(UTF-8)', $file) or die "Could not open file '$file' $!";
        }
    else {
        open($FH, '>:encoding(UTF-8)', $file) or die "Could not open file '$file' $!";
        }
    }
