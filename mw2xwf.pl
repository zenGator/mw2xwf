#!/usr/bin/perl
# https://github.com/zenGator/mw2xwf
# zG:20190321

use strict;
use warnings;
use Getopt::Std;
use File::Copy;
use constant XWFLIM => 100000;
sub usage;
sub capOutput;

# switches followed by a : expect an argument
my %opt=();
getopts('hi:l:o:', \%opt) or usage();
#our($opt_i, $opt_h);
usage () if ( $opt{h} or (scalar keys %opt) == 0 ) ;


my $infile=$opt{i};
open(my $fh, '<:encoding(UTF-8)', $infile)
  or die "Could not open file '$infile' $!";

#my $outfile=STDOUT;
my $outfile=*STDOUT;

if ($opt{o}) {
#    $opt{o}="/dev/stdout";
#    }
#    my $outfile=$opt{o};
    open($outfile, '>:encoding(UTF-8)', $opt{o}) 
        or die "Could not open file '$opt{o}': $!\n";
    }
    else {
        $opt{o} = "/dev/stdout";
    }
    
my $x=0;
my $chars=0;  #XWF has 100,000-char limit on search string block (see XWFLIM constant)
my $outFiCount=0;

while (my $row = <$fh>) {  
    #get a line
    $x++;
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
    #this pattern shouldn't exist, but in mwscan version c. 2019.03.25, there is one example:
    # var ....={..:function\(x,y\){return x!==y;}
    $row =~ s/([^\\])(\{[^#])/$1\\$2/g;  #NB:  use "#" here as the 0-9 replacement is made above
    $row =~ s/([^#])\}/$1\\\}/g;
  

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
    if ( $chars + length($row) > XWFLIM - 1 ) {
        #save off current outfile, copy, & reopen fresh
        capOutput($outFiCount++,length($row));
        $chars=0;
        }
        
    $chars+=length($row)+1;
    printf $outfile "%s\n", $row;
}

sub usage() {
    print "like this: \n\t\'\${0##*/}\' -i [infile] -o [outfile] [-l [logfile]]\n";
    exit 1;
    }

sub capOutput {
    # XWF can only ingest XWFLIM chars for simul-search
    my $count=shift;
    my $len=shift;
    printf STDERR "XWF limit reached, saving outfile segment as: %s\n",$opt{o}."_".$count;
    close $outfile;
    move($opt{o},$opt{o}."_".$count) or die "Couldn't rename '$opt{o}': $!\n";
    open($outfile, '>:encoding(UTF-8)', $opt{o}) or die "Could not open file '$opt{o}' $!";
    }
