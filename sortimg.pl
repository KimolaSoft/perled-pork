#!/usr/bin/perl
# Organizes image (jpg) files based on their EXIF date
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

# Main begins
if (!$ARGV[0]) { usage(); }
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
	'h|?'  => \$doHelp), or usage();
  if (!$ARGV[0] || $doHelp) { usage(); }
  if ($options{Verbose} && $options{Quiet}) { print("Quiet and verbose is somewhat an odd combination.\n"); }
  movePics(@ARGV);
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
  my $date=$exif->GetValue('DateTimeOriginal');
  $date=$exif->GetValue('CreateDate') if !defined $date;
  $date=$exif->GetValue('ModifyDate') if !defined $date;
  if (!defined $date && $options{DateAllowFC}) { $date=$exif->GetValue('FileCreateDate'); }
  if (!defined $date && $options{DateAllowFM}) { $date=$exif->GetValue('FileModifyDate'); }
  if (defined $date && $date=~/(\d+).(\d+)*/)
  { # found a valid date
    $date = Time::Piece->strptime(sprintf("$1%02d",$2),"%Y%m");
    return $date;
  }
  print(STDERR "Skipping: No EXIF data in file $_[0]\n") if !$options{Quiet};
  return; #ensure return is empty
}

=head2 movePic0
 Usage		: movePic0('filename_to_move')
 Function	: Worker method, moves picture based on exif data to target directory
 Argument	: Filename to process
=cut
sub movePic0 {
  my $date=getDate($_[0]);
  if(defined $date) {
    $date=$date->strftime($options{DirMonth});
    make_path($options{FileDir}.'/'.$date);
    my $newname=$options{FileDir}.'/'.$date.'/'.basename($_[0]);
    if (!-e $newname || $options{Overwrite}) { move($_[0],$newname); }
    else { 
      if ($newname ne $_[0] && !$options{Quiet})
      { print(STDERR "Skipping: $newname (file exists)\n"); }
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
    if (-f $file)
    {
      print("Processing $file\n") if $options{Verbose}>1;
      movePic0($file);
    } elsif (-d $file)
    {
      if ($options{Recursive})
      {
        print("Processing directory $file\n") if $options{Verbose};
        my @newlist=<$file/*>;
        if (defined $newlist[0])
        {
          movePics(@newlist);
          rmdir($file);
        }
      } else { print(STDERR "Skipping: Directory $file (recursive not specified)\n") if !$options{Quiet}; }
    }
#TODO calculate time for processing, occasional file updates for level 1 verbosity
  }
}
