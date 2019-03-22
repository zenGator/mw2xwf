#!/usr/bin/perl
# https://github.com/zenGator/mw2xwf
# zG:20190321

use strict;
use warnings;
use Getopt::Std;
sub usage();

# switches followed by a : expect an argument
my %opt=();
getopts('hfi:o:', \%opt) or usage();
#our($opt_i, $opt_h);
usage () if ( $opt{h} or (scalar keys %opt) == 0 ) ;


my $infile=$opt{i};
open(my $fh, '<:encoding(UTF-8)', $infile)
  or die "Could not open file '$infile' $!";
my $x=0;
while (my $row = <$fh>) {  
#get a line
  $x++;
#  printf "$x: ";
  chomp $row;
  my $orig_row=$row;
#  printf ("%-60s => \n", $row);
  
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
  $row =~ s/\{(,[^}]*\})/\{0$1/g;

  
  if ($row =~ /##/ ) {
    warn "repetitive repetition of ## on line $x:  recommend manual review\n";
    warn "\t$orig_row\n\t$row\n";
  }
  if ($row =~ /[^\\]\]\[/ ) {
    warn "sequential char sets on line $x:  recommend manual review\n";
    warn "\t$orig_row\n\t$row\n";
  }
#show results
#  printf ("   %-60s \n\n", $row);
  printf ("%s\n", $row);
# brevity
#  if ($x > 10) {die;}
}

sub usage() 
    {
    print "like this: \n\t\'\${0##*/}\' -i [infile] -o [outfile] [-f (fix)]\n";
    exit 1;
    }
