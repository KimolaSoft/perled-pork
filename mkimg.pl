#!/usr/bin/perl
# TODO: add support for FileDir
# Program to create jpg image files and set exif modify date within the files
package mkimg;
use strict;
use warnings;
use Getopt::Long;
use Time::HiRes;
use File::Path qw(make_path);
# Variable definitions
my %optHelp = (
	"-n"		=> "Number of random files to generate (Required option)",
	"-f"		=> "Base filename, e.g. '-f file' yields a filename like file0.jpg",
	"-allowroot"	=> "Permit use as root (potentially unsafe)",
	"-fy"		=> "First year for new files (range: 1990 - 2050) default 2010",
	"-ly"		=> "Last year for new files (range: 1990 - 2050) default 2015",
	"-o"		=> "Output directory for created files (created if non-existant)",
	"-q"		=> "Quiet",
	"-h or -?" 	=> "This Menu");
my %options = ( 
	FileNum		=> 0,
	FileBaseName	=> "file",
	FileDir		=> "./",
	NoRootCheck	=> 0,
	Quiet		=> 0,
	YearStart	=> 2010,
	YearEnd		=> 2015);
my $doHelp = 0;
# Main begins
  if (!$ARGV[0]) { usage(); }
  GetOptions ( 
	'n=i'  => \$options{FileNum},
	'f:s'  => \$options{FileBaseName},
	'o:s'  => \$options{FileDir},
	'allowroot' => \$options{NoRootCheck},
	'q'    => \$options{Quiet},
	'fy:i' => \$options{YearStart},
	'ly:i' => \$options{YearEnd},
	'h|?'  => \$doHelp), or usage();
  if ($ARGV[0] || $doHelp) { usage(); }
  if (!$options{NoRootCheck} && !$<) { print("Please do not run me as root.\n"); exit;}
  optCheck();
  makePictures();
# Main ends

# subroutines
# usage: Explains how to use this program
sub usage {
  print("USAGE: $0 [options]\n");
  foreach my $key (sort keys %optHelp)
  { printf("  %-12s %s\n",$key,$optHelp{$key}); }
  exit;
}

# optCheck: Verifies options are within valid ranges
sub optCheck {
  if ($options{YearStart} < 1990 || $options{YearStart} > 2050) { usage(); }
  if ($options{YearEnd} < $options{YearStart} || $options{YearEnd} > 2050) { usage(); }
  $options{Year} = $options{YearStart};
}

# makePic0: Worker, actually creates picture and sets exif data (random month)
# arg1 Filename base string to sprint into
# arg2 number of current picture
sub makePic0 {
  my $FN=sprintf($_[0], $options{FileBaseName}, $_[1]);
  my @command1 = ("convert","-size","1024x768","xc:gray","+noise","Random",$FN);
  system(@command1)==0 or die ("Failed to create pictures!");
  my $month=sprintf("%02d",int(rand(12)+1));
  my @command2 = ("exiftool","-DateTimeOriginal='$options{Year}:$month:01 00:00:00'","-overwrite_original","-q",$FN);
  system(@command2)==0 or die ("Failed to insert exif data!");
  #-DateTimeOriginal, -CreateDate, and -ModifyDate are all standard, -AllDates sets all three
}

# makePictures: Runs convert and exiftool to create images as specified
# increments year automatically
sub makePictures {
  if($options{FileNum}<=0) { print("Nothing to do. No files to create."); usage(); }
  if (!-d $options{FileDir}) { make_path($options{FileDir}); }
  my $FileStr=$options{FileDir}."/%s%0".length($options{FileNum})."d.jpg";
  my $time1=Time::HiRes::gettimeofday();
  makePic0($FileStr,0);
  $time1=Time::HiRes::gettimeofday()-$time1;
  my $yearBumpCount=($options{FileNum}/($options{YearEnd}-$options{YearStart}+1));
  my $bump=0; # keeps track of how many times we have incremented the year
  printf("Please wait, creating $options{FileNum} pictures. This will take ~%0.2f seconds\n",($time1*$options{FileNum})) if !$options{Quiet};
  for(my $i=1;$i<$options{FileNum};$i++)
  {
    if($i-($bump*$yearBumpCount)>$yearBumpCount) 
      { $bump++; $options{Year}++;}
    makePic0($FileStr,$i);
  }
}

