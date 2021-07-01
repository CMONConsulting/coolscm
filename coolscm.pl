#!/usr/local/bin/perl
############################################################
#      |-------------------------------------------|       #
#      |             **** coolSCM ****             |       #
#      |   Checkin-order oriented listbased SCM    |       #
#      | A manual configuration management utility |       #
#      |            -------------------            |       #
#      | Providing simple version and configuration|       #
#      | control for development and release of    |       #
#      | locally stored electronic documents       |       #
#      |-------------------------------------------|       #
############################################################
# Created 20010924 by Thomas Karlkvist, Teleca Systems AB  #
# E-mail: thomas@karlkvist.com                             #
############################################################
#
# List of commands:
# CI Checkin file argument list into the $ARCHIVE directory
# CO Overwriting existing working file with the last saved version
#
# LA List add elements to configuration element list
# LE List edit to remove entry from configuration element list
# LS List status to display current configuration element list
# BS Set baseline, store current version numbers as baseline file
# RS Set release, make current baselin into a release
#
############################################################
#
# Change list
# -------------------------------------------------------
# Rev type   Number      Date     Time  Author
# Comment
# -------------------------------------------------------
# Release    R1.0.0      20011017 14.35 Thomas Karlkvist
# R1.0.0 release, with CI and CO support
# -------------------------------------------------------
# Baseline   R1.1.0-2    20011024 16.47 Thomas Karlkvist
# Added warning() function for warning prints
# Complete but not fully verified LIST ADD and LIST EDIT 
# functionality
# -------------------------------------------------------
# Baseline   R1.1.0-3    20011025 01.29 Thomas Karlkvist
#  -Uppdaterat SCM-metoden
#  -Lagt till list_status
#  -Nya hjälpfunktioner getINputLine och getInputString
#  -Omstrukturering med funktionsdeklarationer och main högst upp i programmet
# -------------------------------------------------------
# Version   23           20yymmdd hh.mm Thomas Karlkvist
# baseline_set: Implemented comment entry 
# (known mismatch in typing by added ' ' yet unsolved)
# Added getDirLocation() for cwd environment, used by
# latestBaseline()
# dateAndTime(): Time representation now have initial zero 
# for timestamps lower than 10
# -------------------------------------------------------
# Version   xx           20yymmdd hh.mm Thomas Karlkvist
# -------------------------------------------------------
#
############################################################


#package coolSCM;

use Config;
use File::Copy;
use File::Spec::Functions;

#
# Function declarations
#
sub printHelp;
sub checkSwitch;
sub archiveDir;
sub ci_exec;
sub co_exec;
sub list_add;
sub list_edit;
sub list_status;
sub baseline_set;
sub release_set;
sub getSCMLIST;
sub latestBaseline;
sub dateAndTime;
sub getYesNo;
sub headerBOM;
sub REMOVE;
sub error;
sub warning;


#
# Variable definitions
#
$VERSION = 'P1.1.0';

$ERR = "Error: ";
$WARN = "Warning: ";
$CIERR = "CHECKIN syntax error: ";
$CIARG = "CHECKIN argument invalid: ";
$COERR = "CHECKOUT syntax error: ";
$COARG = "CHECKOUT argument invalid: ";
$LISTARG = "LIST argument invalid: ";
$LAARG = "LIST ADD argument invalid: ";
$LEARG = "LIST EDIT argument invalid: ";
$BLARG = "BASELINE argument invalid: ";

$COOL = "COOLSCM";
$SCMLIST = "COOLSCM-BOM";
$BLPREFIX = "bl-";
$RELPREFIX = "rel-";
# Note, if ever changed - make sure to compensate regexps \. escapes
$VERDELIMIT = ".";


# Set OS dependent definitions
if ($Config{'osname'} eq "MSWin32") # If Windows platform
{
  print "Running on a Windows platform\n";
  $ARCHIVE = ".\\${COOL}\\";
  $EXECRM = "del";
  $DIRDELIMIT = "\\";
}
elsif 	($Config{'osname'} eq ("Solaris") or 
	 $Config{'osname'} eq ("linux") or 
	 $Config{'osname'} eq ("darwin") or
	 $Config{'osname'} eq ("cygwin") or
	 0
	) # If UNIX platform
{
  print "Running on a unix-like platform\n";
  $ARCHIVE = "./${COOL}/";
  $EXECRM = "/bin/rm";
  $DIRDELIMIT = "/";
}

printf "Running coolSCM under OS $Config{'osname'}\n with ARCHIVE named $ARCHIVE and REMOVE as $EXECRM\n";


#--------------------------------------------------------------
# Start of main program
#
# Process input arguments
#

# Check if switch options are used
checkSwitch();

# Get first non-switch argument
$_ = $ARGV[0];
shift;

# On stated subcommand, execute accordingly
CMDSW:
{
   # If CHECKIN command
   if ( /^ci$/ | /^checkin?$/ ) 
   {
      $cmd = CI; 
      print "Selected: $cmd command\n"; 
      CIARGSW:
      {
         $_ = @ARGV[0];

         # End CI if no arguments are given
         if ( /^$/) { error ("${ERR}${CIERR}No file list for checkin\n"); last CIARGSW; }

         # Make sure $ARCHIVE directory exists
         archiveDir();

         # Checkin all files in the current directory
         #  (Should get also OSs without wild card expansion)
         if ( /^\*$/ ) 
         {
            print "Checking in all files in this directory\n"; 
            print "Later... for now, state each file on command line\n";
            last CIARGSW;
         }

         # Allow alphanumeric file names (with '_' and '-') also started by . or .. 
         # Process each stated file
         while ($_ = $ARGV[0], /^\.{0,2}\w+/)
         {
	   # Make sure search path is in local directory, ignore otherwise
	   #$subPath = "." . "$DIRDELIMIT" . $_ ; print "$localPath\n";
	   if (-e $_) {
	     print "Checking in file $_: ";
	     ci_exec( $_ ); 
	   }
	   else { printf ("${WARN}${CIARG}\n  Non-existing file stated: $_, ignored\n"); }
	   shift;
         }
         last CIARGSW if $_ eq ""; # Ignore non-valid file names

         # Warn if no alpha-numeric arguments was stated
         printf ("${WARN}${CIERR}Non-valid pathname to file stated: $_, ignored\n"); 
         shift;
         redo if $ARGV[0] ne "";
      } # end of CIARGSW
      last CMDSW; 
   } # end of checkin command

   # If CHECKOUT command
   if ( /^co$/ | /^checkou?t?$/ ) 
   { 
      $cmd = CO; 
      print "Selected: $cmd command\n"; 
      COARGSW: 
      {
         $_ = @ARGV[0];

         # End CO if no arguments are given
         if ( /^$/) { error ("${ERR}${COERR}No file for checkout\n"); last COARGSW; }

         if ( /^\.{0,2}\w+/ && -e $_  && -e $ARCHIVE ) 
	 {
	   co_exec($_);
	   last COARGSW;
	 }
	 else
	 {
            # Check if file exists in ARCHIVE but not in directory
            printf ("${WARN}${COARG}No saved version of file $_, ignored\n"); 
            last COARGSW; 
         }

         if ( /^\.{0,2}\w+/ && -e $_  && -e $ARCHIVE) { co_exec($_); last COARGSW; }
         else 
         { 
            printf ("${WARN}${COARG}File $_ not found in $ARCHIVE\n"); 
            last COARGSW; 
         }

         # Warn if no alpha-numeric arguments was stated
         printf ("${WARN}${COARG}Non-valid pathname to file stated: $_, ignored\n"); 
         shift;
      } # end of COARGSW

      last CMDSW; 
   } # end of checkout command
   if ( /^ch?e?c?k?$/ )
   { 
	error ("${ERR}Ambigious checkin or checkout command: $_\n");
   }

   # If list command
   if ( /^list$/ | /^la$/ | /^le$/ | /^ls$/ )
   {
     $cmd = 'LIST';
     print "Selected: $cmd command\n";

   LISTARGSW:
     {
       # Possibly long LIST command syntax, then extract the operation
       if ( /^list$/ ) {
	 if ( ($ARGV[0] eq "") | ($ARGV[0] !~ /^-/) )
	 {
	   error("${ERR}${LISTARG}No list operation supplied\n");
	 }
	 # Get switch argument to decide valid operation
	 $_ = @ARGV[0];
	 shift @ARGV; # Get the operation arguments
       }

       # If LIST ADD
       if ( /^la$/ |  /^-[a|A]d?d?$/) {
	 #print "LIST ADD @ARGV because coolSCM cmd $_\n"; 
	 # Make sure that $ARCHIVE exists but remove if no $SCMLIST is created
	 archiveDir();

         # Allow alphanumeric file names (with '_' and '-') also started by . or .. 
         # Process each stated file
         while ($_ = $ARGV[0], /^\.{0,2}\w+/) {
	   #print "Check file $_\n";
	   if (-e $_) {
	     push @listToAdd, $_;
	   } else {
	     printf ("${WARN}${LAARG}Non-existing file stated: $_, ignored\n");
	   }
	   shift;
         }
	 #print "Will add list @listToAdd\n";
	 list_add( @listToAdd );

	 last LISTARGSW;
       }

       # If LIST EDIT
       if ( /^le$/ | /^-[e|E]d?i?t?$/ ) 
       {
	 if ( -e "${ARCHIVE}${SCMLIST}" ) {
	   # Check which edit operation to perform
	   $_ = @ARGV[0];	# Get the operation argument, if any
	   if ( $_ =~ /^c(lear)?/ ) {
	     $cmd = 'LC';
	   } elsif ( ($_ eq "") | ($_ =~ /^a(ll)?/) ) {
	     $cmd = 'LE';
	   } else {
	     error ("${ERR}${LEARG}\n  Edit arguments ignored, will edit all elements in ${SCMLIST}\n");
	   }

	   # Edit the list
	   list_edit();
	 } else {
	   warning("${WARN}${LISTARG}No current $SCMLIST to edit\n");
	 }

	 last LISTARGSW;
       }

       if ( /^ls$/ | /^-[s|S](tat)?u?s?/) {
	 #print "LS\n"; 
	 $_ = @ARGV[0]; shift @ARGV; list_status(@ARGV); last LISTARGSW;
       }
   } # end of LISTARGSW

     last CMDSW;
   } # end of list command



   # If baseline command
   if ( /^baseline$/ | /^bl$/ | /^bs$/ | /^bg$/ ) {

     $cmd = 'BASELINE';
     print "Selected: $cmd command\n";

   BLARGSW:
     {
       # Possibly long BASELINE command syntax, then extract the operation
       if ( /^baseline$/ | /^bl$/ ) {
	 if ( ($ARGV[0] eq "") | ($ARGV[0] !~ /^-/) ) {
	   error("${ERR}${LISTARG}No baseline operation supplied\n");
	 }
	 # Get switch argument to decide valid operation
	 $_ = @ARGV[0];
	 shift @ARGV;		# Get the operation arguments
       }

       # If BASELINE SET
       # Either of the arguments'baseline -set', 'bl -set' or 'bs' are accepted
       if ( /^bs$/ |  /^-set$/)
       {
	 if (-e "${ARCHIVE}${SCMLIST}" ) {
	   baseline_set ();
	 } else {
	   error("${ERR}${BLARG}No $SCMLIST exist, first run LA to add elements in list\n");
	 }

       }
     }				# end of BLARGSW
     last CMDSW;
   }				# end of baseline command


   # No coolSCM command match
   error ("${ERR}Unknown coolscm subcommand: $_\n");
 }				# end of CMDSW
#
# end of main program
#----------------------------------------------------------------

#
# Start of function defintions
#

sub printHelp 
{
   print "Printing help @ARGV\n";
   $_ = $ARGV[0];
   if ( /^ci$/ | /^checkin?$/ )
   {
      $helpcmd = CI; 
   }
   elsif ( /^co$/ | /^checkou?t?$/ ) 
   {
      $helpcmd = CO; 
   }
   else 
   { 
      printf("\nSyntax:\n coolscm { ci | co | la | le  }\n"); 
      printf("\nOptions:\n coolscm -help | -v.er.sion \n"); 
   }
   HELPCMD:
   {
      if ( $helpcmd =~ /^CI$/ ) 
      { 
         printf ("\n CI syntax:\n coolscm ci | checki.n { * | file [file ...] }\n");
         last HELPCMD;
      }
      if ( $helpcmd =~ /^CO$/ ) 
      { 
         printf ("\n CO syntax:\n coolscm co | checko.ut <filename>\n");
         last HELPCMD;
      }
      print "Please enter your command\n";
   }
   exit 0;
}

sub checkSwitch
{
   $_ = $ARGV[0];
   while ($_ = $ARGV[0], /^-/)  
   {
      if ( ($_ =~ /^-[h|H]e?l?p?$/) or $#ARGV < 0 ) { shift @ARGV; printHelp(); } 
      if (/^-s(tatus)?/) { print "Listing coolscm status\nLater...\n"; } 
      if (/^-v(er)?(sion)?$/) { print "Version of coolSCM: $VERSION\n"; exit 0;} 
      last;
   }
}

sub archiveDir
{
   # print "Storage in dir $ARCHIVE\n" 
   unless ( -d $ARCHIVE)
   {
      print "Creating $ARCHIVE for storage\n";
      mkdir $ARCHIVE;
   }
}




sub ci_exec
{
  $file = $_; 
  # Maybe: Check if unnumbered file version exists; if so save as last version
  opendir (ARCHDIR, $ARCHIVE) or die ("Could not read from $ARCHIVE\n");
  # If VERDELIMIT is ever changed, note regexp escape
  @fileversions = grep { /^${file}\.[1-9][0-9]{0,3}$/ } readdir(ARCHDIR);
  closedir(ARCHDIR);
  if ( @fileversions ) {
    @ordered = sort {$b <=> $a} @fileversions;
    # Match up to suffixed version numerals and add one to give next index
    $ver = $ordered[0];
    $ver =~ s/.*?([1-9][0-9]*)$/$1/;
    $ver++;
    # Save modification time on last version, else zeroed in following check
    $prevVerTime = (stat($ARCHIVE . $ordered[0]))[9]; 
  }
  else { $ver = 1; } # No previous checkin if no listmatch on the file
  # Check that modification time differs on last version
  if ( $prevVerTime != (stat($file))[9] ) 
  {
    # Calculate next file version name and copy
    $newver = "$ARCHIVE" . "$file" . "$VERDELIMIT" . "$ver";
    print "version $newver\n";
    copy($file, $newver);
  }
  else {print "No changes made, CI ignored\n";}
}


sub co_exec
{
   $file = $_; 
   opendir (ARCHDIR, $ARCHIVE) or die ("Could not read from $ARCHIVE\n");
   # If VERDELIMIT is ever changed, note regexp escape \.
   @fileversions = grep { /^${file}\.[1-9][0-9]{0,3}$/ } readdir(ARCHDIR);
   closedir(ARCHDIR);
   if ( @fileversions ) {
      @ordered = sort {$b <=> $a} @fileversions;
      $oldver = $ARCHIVE . $ordered[0];
      print "Overwriting working version with last saved version, $ordered[0], from $ARCHIVE\n";
      copy($oldver, $file) or die ("Could not copy $oldver"); 
   }
   else { printf ("${WARN}${COARG}No saved version of file found: $_ ignored\n"); }
}


#
# Add single file to SCMLIST, if valid
#
sub list_add {

  # Get existing SCMLIST, if any and not empty, to match on existing entries
  if ( ( -e "${ARCHIVE}${SCMLIST}" ) | ( -z "${ARCHIVE}${SCMLIST}" ) )
  {
    $printHeader = "false";
    @currentList = getSCMLIST();
    #print "Now @currentList\n";
  }
  else {
    $printHeader = "true"; 
  }

  # Match entered elements from current directory and add those not previously listed
  #  Call to list_add only contain valid elements from current directory
  if ( @listToAdd ) {
    #print "Adding @listToAdd to ${ARCHIVE}${SCMLIST}\n";
    open SCMLIST, ">>${ARCHIVE}${SCMLIST}" or die ("Could not open ${ARCHIVE}${SCMLIST}\n");
    # If we did not find any $SCMLIST we want to print the file header. Once.
    if ( $printHeader eq "true" )
    {
      print SCMLIST headerBOM();
      $printHeader = "false";
    }

    while ( @listToAdd ) {
      # Make sure the entry does not exist already
      $oldElement = "false";
      foreach $currentList ( @currentList ) {
	#print "check $currentList\n";
	if ( $listToAdd[0] eq $currentList) {
	  $oldElement = "true";
	  last;
	}
      }
      if ( $oldElement eq "false" ) {
	my $default = "yes";
	print "Add $listToAdd[0] to ${ARCHIVE}${SCMLIST} [$default]? ";
	$addElement = getYesNo($default);
	if ( $addElement eq "yes" ) {
	  # If file|dir, add f|d $listToAdd[0] to ${SCMLIST}
	  if ( -f $listToAdd[0] ) {
	    print SCMLIST "f $listToAdd[0]\n";
	  } elsif ( -d $listToAdd[0] ) {
	    print SCMLIST "d $listToAdd[0]\n";
	  }
	}
      }
      shift @listToAdd;
    }
    # Maybe inform of outcome

    close SCMLIST;
  } else {
    printf ("${WARN}${LISTARG}No valid file arguments to list in ${SCMLIST}\n");
  }
}


sub list_edit {
  #print "Editing ${ARCHIVE}${SCMLIST}\n";

  # Read list of current configuration elements
  open SCMLIST, "<${ARCHIVE}${SCMLIST}";
  while ( my $line = <SCMLIST> ) {
    push @oldList, $line;
    if ( $line =~ m/^[f|d].*\n/ ) {
      $line =~ s/^[f|d] (.*)\n/$1/ ; $element = $1;
      push @currentList, $element ;
      #print "Element in list: $element\n";
    }
  }
  close SCMLIST;

  #print "List edit $cmd on @currentList\n";
  # Either EDIT CLEAR...
  if ( $cmd eq 'LC')
  {
    # Remove SCMLIST
    REMOVE( "${ARCHIVE}${SCMLIST}" );
    printf ("Removed ${ARCHIVE}${SCMLIST}\n");  
  }
  else # $cmd eq LIST EDIT ALL
  {
    # Preserve initial list lines that are not element references
    $listLine = 0;
    foreach $oldList (@oldList)
    {
      if ( $oldList =~ m/^[d|f]/ ) {last; }
      #print "oldList line \n$oldList";
      push @newList, "$oldList";
      $listLine++; #print "Next listLine $listLine\n";
    }
    #print "Initial newList \n@newList";

    # Choose items to remove, will match oldList[$listLine]
    $kept = 0;
    while ( @currentList )
    {
      # Confirm each entry, default keep entry
      my $default = "no";
      printf ("Remove element $currentList[0] [$default]? ");
      $removeElement = getYesNo($default);
      if ( $removeElement eq "no" ) {
	push @newList, $oldList[$listLine];
	$kept++;
      }
      $listLine++; #print "Next listLine $listLine\n";	

      shift @currentList;
    }

    # Replace previous list with @newList, if any elements remain
    if ( $kept > 0 ) {
      open SCMLIST, ">${ARCHIVE}${SCMLIST}" or die ("Could not open ${ARCHIVE}${SCMLIST}\n");
      while (@newList) {
	print SCMLIST $newList[0];
	shift @newList;
      }
      close SCMLIST;
    } else {
      printf ("Removed all entries of $SCMLIST, removing the file\n");
      # Remove SCMLIST
      REMOVE("${ARCHIVE}${SCMLIST}");
    }
  }

}


sub list_status {
  print "Status of $SCMLIST\n(the following elements are listed in ${ARCHIVE}${SCMLIST})\n";
  @currentList = getSCMLIST();
  foreach $currentList ( @currentList ) {
    #print "Element $currentList\n";
    if ( -f $currentList ) {
      print " file $currentList"; # Receiving end-of-line!
    } elsif ( -d $currentList ) {
      print "dir  $currentList"; # Receiving end-of-line!
    }
    print "\n";
  }
}


sub baseline_set {

  # Set current information data 
  my $dirName; # "MY_ITEM"
  my $index; # X == 1,2,3,...
  my @timestamp = dateAndTime();
  my $date = @timestamp[0];
  my $time = @timestamp[1];
  my $IGP; # "/proj/myproj"
  my $IGP_BL; # "R_1_0_0-X"
  my @comment; #"This should be a comment that describes what was changed since last baseline for the configuration item MY_ITEM."

  # Get directory name
  

  # Get comment string
  @comment = getInputString("Please enter a valid comment for the new baseline\nThe comment should reflect all changes made to the configuration item since last baseline:\n");

  # Get next baseline index
  # E.g. C:\shared\thomas_view_snap\sysnote25\9420-00\Teleca_SCM_Model\coolscm\test
  $index = latestBaseline(".");

  #
  # Retrieve current file versions
  #
  my @fileList = getSCMLIST(); #print "Current ${ARCHIVE}${SCMLIST} is @fileList\n";
  my @currFileVers;
  foreach $fileList ( @fileList) {
    # Handle each file element in the list, file or directory
    if ( -f $fileList ) {
      #print "Now checking file $fileList\n";
      # Get a list of fileversions
      opendir (ARCHDIR, $ARCHIVE) or die ("Could not read from $ARCHIVE\n");
      # If VERDELIMIT is ever changed, note regexp escape
      @fileversions = grep { /^$fileList\.[1-9][0-9]{0,3}$/ } readdir(ARCHDIR);
      closedir(ARCHDIR);

      # printf("Current fileversions are: @fileversions\n");
      if ( @fileversions ) {
	@ordered = sort {$b <=> $a} @fileversions;
	# Save file version with highest index
	push @currFileVers, $ordered[0];
      } else {
	warning ("${WARN}${BLARG}\n  No version checked in of $fileList (file ignored), first run CI $fileList or LE to remove from $SCMLIST\n") ;
      }
    } # end of if $fileList is file

    # Handle each directory element in the list
    elsif ( -d $fileList) {
      # Element in SCMLIST is directory, hence get latest baseline
      #printf("Now checking directory $fileList\n");
      push @currFileVers, "$fileList" . "-BL";
    } # end of if $fileList is directory

    else {
      warning ("${WARN}${BLARG}\n  No version checked in of $fileList (file ignored), first run CI $fileList or LE to remove from $SCMLIST\n") ;
    } # No previous checkin if no listmatch on the file
  }
  print "These versions will be baselined: @currFileVers\n";


  #
  # Create baseline file header info
  #
  my $blFile = "$BLPREFIX" . "$dirName-$index";
  my $BLinfo = <<EOBLINFO;
$blFile
------------------------------------------
Date: $date $time
IGP reference: $IGP
  Latest baseline: $IGP_BL
Comment:
 @comment

Element versions:
EOBLINFO


#Referenced configuration items:
#  $subCMP[0]-$subCMP[1]

#print "will write to $blFile\n${BLinfo}@currFileVers\n";

  # If baseline for CMP

  # Create a copy of current SCMLIST
  copy ("${ARCHIVE}${SCMLIST}", "${ARCHIVE}${SCMLIST}-$index");

  # Create the baseline file
  open BL, ">${ARCHIVE}${blFile}" or die ("Could not open ${ARCHIVE}${blFile}\n");
  print BL $BLinfo;
  foreach $currFileVers (@currFileVers) {
    print BL "  ";
    print BL $currFileVers;
    print BL "\n";
  }
  print BL "  MY_ITEM-$index\n";
  print BL "  COOLSCM-BOM-$index\n";
  close BL;

  print "Created template baseline file, ${ARCHIVE}${blFile}\nPlease edit and rename as needed (the template will be overwritten at next baseline set)\n";
}


sub release_set {
  my @args = @_;

  my $dirName = $args[0];
  my $index = $args[1];
  my $date = $args[2];
  my $time = $args[3];
  my $comment = $args[4];
  my $IGP = $args[5];
  my $IGP_BL = $args[6];
  my $file = "fileA.8";
  my @subCMP = "test", 1;

  my $blFile = "$RELPREFIX" . "$dirName-$index";
  my $BLinfo = <<EOBLINFO;
$blFile
------------------------------------------
Date: $date $time
IGP reference: $IGP
  Latest baseline:
Comment:
$comment
Element versions:
  MY_ITEM-$index
  COOLSCM-BOM-$index
EOBLINFO

  # Retrieve current file versions
  my @fileList = getSCMLIST(); print "got @fileList\n";
  my @currFileVers;
  foreach $fileList ( @fileList)
  {
    opendir (ARCHDIR, $ARCHIVE) or die ("Could not read from $ARCHIVE\n");
    # If VERDELIMIT is ever changed, note regexp escape
    @fileversions = grep { /^${fileList}\.[1-9][0-9]{0,3}$/ } readdir(ARCHDIR);
    closedir(ARCHDIR);
    if ( @fileversions ) {
      @ordered = sort {$b <=> $a} @fileversions;
      # Save file version with highest index
      push @currFileVers, $ordered[0];
    } else {
      error ("${ERROR}${BLARG}\n  No version checked in of $fileList, first run CI $fileList or LE to remove from $SCMLIST\n") ;
    } # No previous checkin if no listmatch on the file
  }
 # print "These versions: @currFileVers\n";

#Referenced configuration items:
#  $subCMP[0]-$subCMP[1]

#print "will write to $blFile\n${BLinfo}@currFileVers\n";

  # If baseline for CMP

  # Create a copy of current SCMLIST
  copy ("${ARCHIVE}${SCMLIST}", "${ARCHIVE}${SCMLIST}-$index");

  # Create the baseline file
  open BL, ">${ARCHIVE}${blFile}" or die ("Could not open ${ARCHIVE}${blFile}\n");
  print BL $BLinfo;
  foreach $currFileVers (@currFileVers) {
    print BL "  ";
    print BL $currFileVers;
    print BL "\n";
  }
  close BL;

  print "Created template baseline file, ${ARCHIVE}${blFile}\nPlease edit and rename as needed (the template will be overwritten at next baseline set)\n";
}


# Read current SCMLIST
sub getSCMLIST {
  my @currentList;
  #print "Reading ${ARCHIVE}${SCMLIST}\n";
  open SCMLIST, "<${ARCHIVE}${SCMLIST}";
  while ( my $line = <SCMLIST> ) {
    if ( $line =~ m/^[f|d].*\n/ ) {
      $line =~ s/^[f|d] (.*)\n/$1/ ; 
      $element = $1;
      push @currentList, $element ;
      #print "Element in list: $element\n";
    }
  }
  close SCMLIST;
  return @currentList;
}

# Get name of current directory
sub getDirLocation {
  # Argument may be set to '.'
  my @args = @_;
  my $dirName = $args[0];

  chdir ( File::Spec->abs2rel($dirName, rootdir() ) );
  my $relpath = File::Spec->abs2rel(curdir(), rootdir() );
  print "Now in $relpath\n";
}

# Get latest baseline-file index
sub latestBaseline {
  my @args = @_;
  my $dirName = $args[0];
  my @dirLocation = getDirLocation();
  my $relpath = $dirLocation[0];

  opendir (ARCHDIR, $ARCHIVE) or die ("Could not read from $ARCHIVE\n");
  # If VERDELIMIT is ever changed, note regexp escape
  @baselineRevisions = grep { /^${fileList}\.[1-9][0-9]{0,3}$/ } readdir(ARCHDIR);
  closedir(ARCHDIR);
  print "Got baselines @baselineRevisions\n";

}

# Calculate date and time
  sub dateAndTime {
  my @datelist = localtime (time);	# Perl generated timelist

  # Format date
  my $year = @datelist[5]; 
  my $mon = @datelist[4] + 1; if ($mon < 10) {$mon = "0" . "$mon"; }
  my $mday = @datelist[3]; if ($mday < 10) {$mday = "0" . "$mday"; }
  my $tyear = substr($year, -2, 2); # Strip 100-year value to gain ten-years
  #print "\nTenyears is $tyear\n";
  my $hyear = 19 + ($year - $tyear) / 100 ;
  #print "Hundredyears is $hyear\n";   # Strip 10-year value to gain hundred-years
  my $date = "$hyear$tyear$mon$mday";
  # print "Date is $hyear$tyear$mon$mday\n";

  # Format time
  my $hour = @datelist[2]; if ($hour < 10) {$hour = "0" . "$hour"};
  my $min = @datelist[1]; if ($min < 10) {$min = "0" . "$min"};
  my $sec = @datelist[0]; if ($sec < 10) {$sec = "0" . "$sec"};
  my $time = "$hour.$min:$sec";
  # print "Time is $time\n";

  return ($date, $time);
}

# Read one-line of input, ended by RETURN (newline)
sub getInputLine {
  my @args = @_;
  my $instruction = $args[0];
  my $line;
  print "$instruction";
  while ( $line = <STDIN>) {
    if ( $line =~ /^$/ ) {
      print "Please enter a non-empty string\n";
    } else { return $line;}
  }
}


# Read an input string
# Input is ended by an empty dot '.' and RETURN (newline)
sub getInputString {
  my @args = @_;
  my $instruction = $args[0];
  my @string;
  my $line;
  print "$instruction";
  while ( $line = <STDIN>) {
    if ( $line !~ /^\.$/ ) {
      push @string, "$line";
    } else { return @string;}
  }
}

# Read a yes|no answer, ended by RETURN (newline)
sub getYesNo {
  my @args = @_;
  my $defaultString = $args[0];
  my $line;
  while ( $line = <STDIN>) {
    # Check input string to match yes|no
    if ( $line =~  m/^[y|Y](es)?$/ ) {
      return "yes";
    } elsif ( $line =~ m/^[n|N]o?$/ ) {
      return "no";
    }
    # If empty string, return default string
    elsif ( $line =~ /^$/ ) {
      if ( $defaultString =~ "yes" ) {return "yes";}
      elsif ( $defaultString =~ "no" ) {return "no";}
    }
    else { print "Please answer yes|no\n";}
  }
}


# Set BOM list header (returns header string)
sub headerBOM {

my $header = <<EOHEADER;
Current configuration element list
(BOM, bill-of-materials)
-----------------------------------
EOHEADER

return $header;
}

sub REMOVE {
  my @rmList = @_;
  system($EXECRM, @rmList);
}


sub error {
  printf ("@_\n");
  exit 1;
}


sub warning {
  printf ("@_\n");
}
