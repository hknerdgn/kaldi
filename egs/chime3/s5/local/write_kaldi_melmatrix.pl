#!/usr/bin/perl

use strict;
use POSIX;

my $bin = "../../../src/featbin/compute-fbank-feats";

if (! -x $bin) {
  die("$bin does not exist. Quitting!");
}

my $mel_bins = 40;
if ($ARGV[0] > 0) {
    $mel_bins = $ARGV[0] + 0;
}
my $frlen = 25; # in milliseconds
if ($ARGV[1] > 0) {
    $frlen = $ARGV[1] + 0;
}
my $sample_rate = 16000;
if ($ARGV[2] > 0) {
    $sample_rate = $ARGV[2] + 0;
}
my $numrep = 1; # number of repetitions
if ($ARGV[3] > 0) {
    $numrep = $ARGV[3] + 0;
}

my $frames=$numrep; # write this many frames concatenated
my @melmatrix;
my $maxhfft=2049; # change this to be larger if you expect a larger half-fft+1 size

my $opt = "--num-mel-bins=$mel_bins --debug-mel=true --frame-length=$frlen --sample-frequency=$sample_rate";

# generate some short signal for testing.
# it does not matter what signal it is!
my $tmp_wav = "/tmp/tmp$$.wav";
my $gcmd = "sox -n -r $sample_rate -b 16 -c 1 $tmp_wav synth pinknoise trim 0 0.1 vol 0.1";
my $rv = system($gcmd);
exit $rv if ($rv);

my $fcmd = "echo tmp $tmp_wav | $bin $opt scp:- ark:/dev/null";
print STDERR "Running: $fcmd\n";
my @lines = `$fcmd 2>&1`;
my $numlines = 0;
my $numfft = 0;
#print STDERR @lines;
for my $line (@lines) {
# LOG (compute-fbank-feats:MelBanks():mel-computations.cc:129) bin 32, offset = 139, vec =  [ 0.0298337 0.131464 0.232471 0.332862 0.432642 0.531817 0.630404 0.728403 0.825824 0.922664 0.981059 0.885338 0.790177 0.695561 0.601483 0.507943 0.414931 0.322439 0.230472 0.13901 0.0480547 ]
    chomp($line);
    if ($line =~ /^LOG.+vec/) {
        my ($bin, $offset, $vec) = $line =~ /bin\s+(\d+),\s+offset\s+=\s+(\d+),\s+vec\s+=\s+\[\s+(.+)\s+\]/;
        #$bin--;
        for (my $i = 0; $i < $offset; ++$i) {
            #print "0,";
 	    $melmatrix[$numlines][$i]=0.0;
        }
        my @v = split(/\s+/, $vec);
        for (my $i = 0; $i < @v; ++$i) {
            #print "0,";
 	    $melmatrix[$numlines][$offset+$i]=$v[$i];
        }

        #@{$mel[$bin]} = @v;
        #print join(',', @v), "\n";
	$numfft = @v+$offset;
        for (my $i = 0; $i < $maxhfft-$numfft; ++$i) {
            #print "0,";
 	    $melmatrix[$numlines][$numfft+$i]=0.0;
        }
	#print STDERR "Number of fft bins( for current line ) = ", $numfft, "\n";
	$numlines++;
    }
}

my $numwritefft=$numfft+1; # kaldi does cut_nyquist but we don't, kaldi starts from zero

     for (my $k = 0; $k < $frames*$numlines; ++$k) {
        for (my $i = 0; $i < $frames*$numwritefft; ++$i) {
	    my $row = floor($k/$numlines);
	    my $col = floor($i/$numwritefft);
	    if ($row == $col) {
 	      print $melmatrix[$k % $numlines][$i % $numwritefft], " ";
            } else {
 	      print "0 ";
            }
        }
	print "\n";
     }
     
 
print STDERR "Number of lines (filter banks) = ", $numlines, "\n";
print STDERR "Number of actual fft bins( for last line ) = ", 2 * $numfft, "\n";
print STDERR "Number of nonnegative frequency fft bins( for last line ) = ", $numfft, "\n";
print STDERR "Number of written fft bins ( for each line, includes DC and Nyquist freqs ) = ", $numwritefft, "\n";
print STDERR "Frame length in samples = ", $frlen/1000 * $sample_rate, "\n";

unlink($tmp_wav);
