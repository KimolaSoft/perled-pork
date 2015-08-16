#!/usr/bin/perl
=head1 mkimg.pl
 Program to create jpg image files and set exif modify date within the files
 USAGE:	To create 20 files named file01.jpg to file20.jpg:
	./mkimg.pl -n 20
 Use -? for detailed help.
=cut
use strict;
use warnings;
use Getopt::Long;
use Time::HiRes;
use File::Path qw(make_path);
use Time::Piece;
# Variable definitions
my %optHelp = (
	"-n"		=> "Number of random files to generate (Required option)",
	"-f"		=> "Base filename, e.g. '-f file' yields a filename like file0.jpg",
	"-allowroot"	=> "Permit use as root (potentially unsafe)",
	"-fy"		=> "First year for new files (range: 1990 - 2030) default 2010",
	"-ly"		=> "Last year for new files (range: 1990 - 2030) default 2015",
	"-o"		=> "Output directory for created files (created if non-existant)",
	"-q"		=> "Quiet",
	"-v"		=> "Verbose",
	"-h or -?" 	=> "This Menu");
my %options = ( 
	FileNum		=> 0,
	FileBaseName	=> "file",
	FileDir		=> "./",
	NoRootCheck	=> 0,
	Quiet		=> 0,
	Verbose		=> 0,
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
	'v'    => \$options{Verbose},
	'fy:i' => \$options{YearStart},
	'ly:i' => \$options{YearEnd},
	'h|?'  => \$doHelp), or usage();
  if ($ARGV[0] || $doHelp) { usage(); }
  if (!$options{NoRootCheck} && !$<) { print("Please do not run me as root.\n"); exit;}
  optCheck();
  makePictures();
# Main ends

# subroutines
=head2 usage
 Usage		: usage()
 Function	: Display help menu for how to use the script
 Argument       : None
=cut
sub usage {
  print("Creates specified number of jpg images with varying EXIF date data\n");
  print("\nUSAGE: $0 [options]\n");
  foreach my $key (sort keys %optHelp)
  { printf("  %-12s %s\n",$key,$optHelp{$key}); }
  print("\nexample: The following will create 20 sample input files\n\t$0 -n 20\n");
  exit;
}

=head2 optCheck
 Usage		: optCheck()
 Function	: Verifies valid years have been specified for start/end
 Argument	: None
=cut
sub optCheck {
  usage() if ($options{YearStart} < 1990 || $options{YearStart} > 2030);
  usage() if ($options{YearEnd} < $options{YearStart} || $options{YearEnd} > 2030);
  $options{Year} = $options{YearStart};
  print("Quiet and verbose is somewhat an odd combination.\n") if ($options{Verbose} && $options{Quiet});
}

=head2 makePic0
 Usage		: makePic0('path/to/file/to/create%02d.jpg',$id)
 Function	: Worker method, creates file specified using system call to convert
		: Also sets EXIF DateTimeOriginal to specified year and random month
 Argument1	: Filename to create, including %d for printing file number into
 Argument2	: File number
=cut
sub makePic0 {
  my $FN = sprintf($_[0], $_[1]);
  my @command1 = ("convert","-size","1024x768","xc:gray","+noise","Random",$FN);
  system(@command1)==0 or die ("Failed to create pictures!");
  my $month=sprintf("%02d",int(rand(12)+1));
  my @command2 = ("exiftool","-DateTimeOriginal='$options{Year}:$month:01 00:00:00'","-overwrite_original","-q",$FN);
  system(@command2)==0 or die ("Failed to insert exif data!");
  #-DateTimeOriginal, -CreateDate, and -ModifyDate are all standard, -AllDates sets all three
}

=head2 blankLine
 Usage		: blankLine(20)
 Function	: Writes argument backspaces, argument spaces, then argument backspaces 
		: to clear the current line
 Argument	: Number of characters to "erase"
=cut
sub blankLine {
  print("\b"x($_[0]));
  print(" " x($_[0]));
  print("\b"x($_[0]));
}

=head2 makePictures
 Usage		: makePictures()
 Function	: Calls makePic0 to create specified number of images. Reports status.
		: Also increments year as needed to average the same number each year.
 Argument	: None
=cut
sub makePictures {
  if ($options{FileNum} <= 0) { print("Nothing to do. No files to create."); usage(); }
  make_path($options{FileDir}) if (!-d $options{FileDir});
  my $FileStr = "$options{FileDir}/$options{FileBaseName}%0".length($options{FileNum})."d.jpg";
  my $time0 = Time::HiRes::gettimeofday();
  makePic0($FileStr,0);
  my $yearBumpCount = ($options{FileNum}/($options{YearEnd}-$options{YearStart}+1));
  my $bump = 0; # keeps track of how many times we have incremented the year
  my $clock = Time::Piece->strptime('00','%S');
  printf("Please wait, creating $options{FileNum} pictures. This will take ~%0d seconds\n",((Time::HiRes::gettimeofday()-$time0)*$options{FileNum})) if !$options{Quiet};
  my $status = sprintf(($options{FileNum}-1)." files, ".($clock+((Time::HiRes::gettimeofday()-$time0)*($options{FileNum}-1)))->strftime("%H:%M:%S")." remaining");
  print($status) if ($options{Verbose});
  for (my $i = 1; $i < $options{FileNum}; $i++) {
    if ($options{Verbose} && !(($i) %10)) {
      blankLine(length($status));
      $status = sprintf(($options{FileNum}-$i)." files, ".($clock+((Time::HiRes::gettimeofday()-$time0)/$i*($options{FileNum}-$i)))->strftime("%H:%M:%S")." remaining");
      print($status);
    }
    if ($i-($bump*$yearBumpCount)>$yearBumpCount) {
      $bump++; 
      $options{Year}++;
    }
    makePic0($FileStr,$i);
  }
  blankLine(length($status)) if ($options{Verbose});
  print("\nCompleted.\n") if (!$options{Quiet});
}
