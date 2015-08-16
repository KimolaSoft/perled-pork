#!/usr/bin/perl
=head1 sortimg.pl
 Program to sort files primarily based on their EXIF modify date.
   Other date sources such as modification date allow use with more
   than only image files.

 USAGE:	To sort files in directory Pictures into directories based
   on their year and month (e.g. 2015/01-January) into a directory
   named output:
	./sortimg.pl -lm -o output Pictures
 Use -? for detailed help.
=cut
use strict;
use warnings;
use Getopt::Long;
use Image::ExifTool;
use Time::Piece;
use File::Path qw(make_path);
use File::Copy qw(move);
use File::Basename;

# Variable definitions
my %optHelp = (
	"-y"		=> "Sort only into year directories, ignore month",
	"-nm"		=> "Use month names as well as numbers (e.g. 2009/01-Jan)",
	"-m"		=> "Month names - no numbers (e.g. 2012/Mar, sorts poorly)",
	"-lm"		=> "Use long month names (e.g. 2011/01-January)",
	"-l"		=> "Long month - no numbers (e.g. 2010/February, sorts poorly)",
	"-fc"		=> "Allow use of file creation date",
	"-fm"		=> "Allow use of file modification date when no EXIF data",
	"-ow"		=> "Overwrite existing files (Danger)",
	"-r"		=> "Recurse subdirectories",
	"-v"		=> "Verbose",
	"-q"		=> "Quiet (suppresses warnings)",
	"-vv"		=> "Even more Verbose",
	"-h or -?" 	=> "This Menu");
my %options = (
	DirMonth	=> "%Y/%m",
	DateAllowFC	=> 0,
	DateAllowFM	=> 0,
	Recursive	=> 0,
	Overwrite	=> 0,
	Verbose		=> 0,
	Quiet		=> 0,
	FileDir		=> ".");
my $doHelp = 0;
my $exif = new Image::ExifTool;
my $numFiles = 0;
my $numDone = 1; # Must begin at 1 to prevent division by zero later
my $clock = Time::Piece->strptime('00','%S');

# Main begins
  usage() if (!$ARGV[0]);
  GetOptions ( 
	'y'    => sub { $options{DirMonth}="%Y"; },
	'nm'   => sub { $options{DirMonth}="%Y/%m-%b"; },
	'm'    => sub { $options{DirMonth}="%Y/%b"; },
	'lm'   => sub { $options{DirMonth}="%Y/%m-%B"; },
	'l'    => sub { $options{DirMonth}="%Y/%B"; },
	'v'    => \$options{Verbose},
	'vv'   => sub { $options{Verbose}=2; },
	'q'    => \$options{Quiet},
	'r'    => \$options{Recursive},
	'ow'   => \$options{Overwrite},
	'o:s'  => \$options{FileDir},
	'fc'   => \$options{DateAllowFC},
	'fm'   => \$options{DateAllowFM},
	'h|?'  => \$doHelp) or usage();
  usage() if (!$ARGV[0] || $doHelp);
  print("Quiet and verbose is somewhat an odd combination.\n") if ($options{Verbose} && $options{Quiet});
  $numFiles = countFiles(@ARGV);
  $|=1; # Enable flushing for prints
  movePics(@ARGV);
  printf("File $numDone of $numFiles\n") if ($options{Verbose});
# Main ends

# Subroutines
=head2 usage
 Usage		: usage()
 Function	: Display help menu for how to use the script
 Argument	: None
=cut
sub usage {
  print("Sorts files into YYYY/MM directories, e.g. 2014/12\n");
  print("\nUSAGE: $0 [options] <files-to-process>\n");
  foreach my $key (sort keys %optHelp)
  { printf("  %-12s %s\n",$key,$optHelp{$key}); }
  print(" Note: Use of -fc or -fm will allow any file to be sorted, not only images.\n");
  exit;
}

=head2 getDate
 Usage		: getDate('filename_to_query')
 Function	: Get date/time data from file
 Argument	: Filename to process
 Returns	: Time::Piece (or undefined if no date found)
=cut
sub getDate {
  $exif->ExtractInfo($_[0]);
  my $date = $exif->GetValue('DateTimeOriginal');
  $date = $exif->GetValue('CreateDate') if (!defined $date);
  $date = $exif->GetValue('ModifyDate') if (!defined $date);
  $date = $exif->GetValue('FileCreateDate') if (!defined $date && $options{DateAllowFC});
  $date = $exif->GetValue('FileModifyDate') if (!defined $date && $options{DateAllowFM});
  if (defined $date && $date =~ /(\d+).(\d+)*/) {
    $date = Time::Piece->strptime(sprintf("$1%02d",$2),"%Y%m");
    return $date;
  }
  print(STDERR "Skipping: No EXIF data in file $_[0]\n") if (!$options{Quiet});
  return; #ensure return is empty
}

=head2 movePic0
 Usage		: movePic0('filename_to_move')
 Function	: Worker method, moves picture based on exif data to target directory
 Argument	: Filename to process
=cut
sub movePic0 {
  my $date = getDate($_[0]);
  if (defined $date) {
    $date = $date->strftime($options{DirMonth});
    make_path($options{FileDir}.'/'.$date) if (!-d ($options{FileDir}.'/'.$date));
    my $newname = $options{FileDir}.'/'.$date.'/'.basename($_[0]);
    if (!-e $newname || $options{Overwrite}) {
      move($_[0],$newname); 
    } else { 
      print(STDERR "Skipping: $newname (file exists)\n") if ($newname ne $_[0] && !$options{Quiet});
    }
  }
}

=head2 movePics
 Usage		: movePics(@array_of_files)
 Function	: Moves files based on exif image date. If recursive specified, calls self for directories.
 Argument	: Array of files/directories to process
=cut
sub movePics {
  foreach my $file (@_)
  {
    printf("File $numDone of $numFiles\n") if ($options{Verbose} && !($numDone % 100));
    if (-f $file)
    {
      print("Processing $file\n") if ($options{Verbose}>1);
      movePic0($file);
      $numDone++;
    } elsif (-d $file)
    {
      if ($options{Recursive})
      {
        #blankLine() if ($options{Verbose});
        print("\nProcessing directory $file\n") if ($options{Verbose}>1);
        my @newlist = <$file/*>;
        if (defined $newlist[0])
        {
          movePics(@newlist);
          rmdir($file); # only actually works when directory is empty, so safe to call
        }
      } else { print(STDERR "Skipping: Directory $file (recursive not specified)\n") if (!$options{Quiet}); }
    }
  }
}

=head2 countFiles
 Usage		: countFiles(@array_of_files)
 Function	: Counts the number of files that may be impacted. If recursive, calls itself.
 Argument	: Array of files/directories to process
 Returns	: Number of files found
=cut
sub countFiles {
  my $num = 0;
  foreach my $file (@_)
  {
    $num++ if (-f $file);
    if (-d $file) {
      my @newlist = <$file/*>;
      $num += countFiles(@newlist) if (defined $newlist[0]);
    }
  }
  return $num;
}
