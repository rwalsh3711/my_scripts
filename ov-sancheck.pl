#!/usr/bin/perl
#
# This script checks multiple flavors of multi-pathing software on these OS's:
# AIX: MPIO/VIO, Shark/ESS, HDLM, EMC, vxdmp
# Solaris: EMC, HDLM, vxdmp, mpxio
# HP-UX: EMC, HDLM
#
# The script should reside in: /usr/local/bin
#
# The most recent output of this script is in: /var/adm/ov-sancheck.log
# This file is overwritten each time the script runs.  However, older versions 
# of this file are saved if an error condition occurs.  The date of the error 
# is appended to the filename.  These are kept for a maximum of 60 days.
#
# The error log is: /var/adm/ov-sancheck-error.log and is monitored by
# HPOV.  This log is also automatically rotated on the 1st of each month, if
# there is no on-going issues.
#
# Version 2.30 9/22/15 Patrick Lieberg patrick_lieberg@optum.com
#
# Changes in v1.1:  Added checking of individual disks on vxdmp on AIX.
#		    Added vxdmp section to Solaris.
# Changes in v1.2:  Added a check for acknowledgement file.
#		    Errors are only reported if seen on
#               	consecutive iterations of the script.
# Changes in v1.3:  Added Solaris mpxio checking.
#		    Fixed checking for single-path configurations.
#		    Moved error checking and logging to subroutine.
#		    Moved iteration check to subroutine.
#		    Updated vxdmp and EMC routines to a more in depth check.
#		    Will now save a copy of the log file when an error is
#			first reported.
#		    Added auto-fix routine shells.
# Changes in v1.31: Fixed Solaris subrountine to skip vxdmp if other
#			multi-pathing software is detected first.
# Changes in v1.4:  Check for existence of multipath software before
#			running it.  Prevents possible error messages.
#		    Fixed mpxio not to report errors if the mpathadm
#			command fails to run.
#		    Added check to see if the script is already running
#			in case it hangs so we don't get multiple hung
#			processes.
#		    Fixed AIX vxdmp check so that it will not report single-
#		      	path errors for dmp devices that point to MPIO disk.
#		    Added auto-fix routine for HDLM.
# Changes in v1.5:  Fixed AIX vxdmp check to not return errors when checking
#			to see if the disks are managed by MPIO as well.
#		    Added a check to see if the script is running on an
#			LPAR on a p510.  If this is the case, ignore any
#			single-path disks on vscsi devices.
#		    Fixed the routine that checks for an already running
#			version of the script to eliminate bad PID matching.
#		    Added check to AIX HDLM section to not report any errors
#			from dlnkmgr if there are no disks listed in lspv.
#		    Redirected STDERR to the log file to prevent erroneous
#			errors from going to the console or being emailed.
#		    Update EMC checking for AIX and Solaris to report which
#			LUNs are mapped on only one path.
# Changes in v1.6:  Added checking of fscsi adapter settings on AIX.
#		    Fixed checking for whether an hdisk is managed by HDLM
#			so it is skipped by vxdmp checks.
#		    Added checking of MPIO disk settings and pcmsrv service.
#		    Added checking of queue depth for HDLM devices on AIX.
#		    Added a check to the HDLM auto-fix routine to check
#			the version of HDLM.  If 5.9, skip the auto-fix.
#		    Added a check to the MPIO routine.  If the hdisk is
#			managed by HDLM 5.9, skip the MPIO check.
#		    Fixed Solaris HDLM routine to not report errors from
#			dlnkmgr if no devices are found.
#		    Added checking of HDLM settings Auto Failback, Path
#			Health Checking and IEM.  Auto-failback will be set
#			if it is not correct.  Others will only report 
#			settings for now.
#		    Added section to log rotation that will delete copies
#			of the log that were saved from previous error
#			conditions that are older than 60 days.
#		    Added check to see if we are running on a Solaris non-
#			Global zone.  If so, do not run.
#		    Changed AIX EMC check routine to not report errors
#			on PowerPath devices that the OS sees but PowerPath
#			does not.
# Changes in v1.7:  When EMC devices are detected as single-path, the size of
#		    	the device is checked to see if the device in question
#			is a Gate Keeper.  If so, the single-path condition is
#			ignored.
#		    Rewrote HP and Solaris EMC routines to decrease runtime
#			of the script and to accomodate checking for Gate
#			Keeper devices.
#		    Adjusted AIX MPIO hcheck_interval setting check to account
#			for new default setting of 60.
# Changes in v1.71: Fixed Solaris and HP EMC checks to accomodate differing
#			output from the powermt command, such as more than
#			two paths listed or no Pseduo device listed.
#		    Fixed Solaris EMC check to identify more Gate Keeper
#			devices.  Now, anything less than 2457600 in size
#			will be identified.
# Changes in v1.8:  Added a version output in the log file.
#		    Fixed and enhanced the AIX Shark/ESS disk routine.
#		    Added a routine to place the failing devices into the
#			lock file.  The script will now continue to run even
#			if the lock file is present.  Instead we check the
#			current list of failed devices against what is in the
#			lock file.  If the list is the same, no new error is
#			generated.
#                   Fixed the Solaris mpxio detection routine as it was
#                       not properly detecting some versions.
#		    Fixed Solaris vxdmp check to weed out more non-SAN disk.
# 		    Added additional check for powermt on Sun systems for
#			/etc/powermt.
# Changes in v1.9:  Changed Solaris vxdmp section.  Instead of skipping this
#			check entirely when other flavors of multipathing are
#			found, the script now checks to see if the LUNs are 
#			managed by another service and if so, skips it.
# Changes in v1.91: Changes the AIX EMC check to not run powermt for every
#			hdiskpower device.  The powermt command is now run once
#			and the output captured for comparison.
#		    Updated Shark/ESS check to not report any disk found if
#			the 'datapath query device` command returns 
#			`No device file found`.
#		    Added a check for the mpxio files before checking their
#			contents to eliminate reported file-not-found errors.
#		    Added a check of mpxio devices on Solaris 8 and 9 to ensure
#			the luxadm command returns valid info.  If a SCSI error
#			is generated, the LUN is marked bad and an error is 
#			logged.
#		    Added some notes on AIX fscsi adapter settings and HDLM 
#			settings for all OS's.  Also added additional 
#			information messages to make the output of the script 
#			more clear.
#		    Fixed Solaris mpxio section so that when other flavors of
#			multipathing software detect disabled paths, the count
#			is not carried over to the mpxio check.
#		    Added a check for Solaris 10 systems running mpxio.  If the
#			'mpathadm list lu' command does not complete 
#			successfully, an error is generated and checking of 
#			luns is aborted.
# Changes in v1.92: Moved the Solaris vxdmp check to be last in the Sun 
#			subroutine.  Also added a check to see if the mpathadm
#			command failed during the mpxio check and if so, skip
#			the vxdmp check. 
# Changes in v1.93: Added a check in the Solaris vxdmp section to see if the
#			vxdisk list command fails when checking for path
#			count.  If it does, a better error message is logged.
#			Also, the vxdmp check will now skip devices marked
#			as NONAME.
#		    Added a command-line parameter that will make the script
#			skip any attempt to fix offline paths.
# Changes in v1.94: Updated single-path checks to ensure that if more than one
#			path is detected that they are on distinct HBAs.
# Changes in v1.96: Added support for Linux systems.  The script now checks
#			Veritas and RHEL5 multipath-enabled systems.
#		    Adjusted the check for previous iteraitons of the script
#			to see when the last iteration was started.  If it has
#			been more than 24 hours, generate an alert.
#		    Adjusted the check for fscsi adapter settings on AIX
#			systems to check the connection type and no longer
#			report dyntrk and fc_err_recov not being set on
#			direct-attach disk.
# Changes in v1.97: Fixed EMC check for single-path devices.
# Changes in v1.98: Fixed the checks for devices configured on only one path
#			so that they now verify that more than one HBA are used.
#		    Removed check for the script running longer than 24 hours
#			as the check was not working properly.
# Changes in v1.985: Fixed the check for previous iterations of the script to
#			ensure it is finding only ov-sancheck.
# Changes in v1.985: Changed Solaris vxdmp check to not run mpathadm for every
#			path when checking to see if disks are managed by
#			mpxio.
# Changes in v1.987: Fixed AIX MPIO check for disks defined only on one HBA.
# Changes in v2.0:   Added a check for the unlic state on PowerPath systems to
#			prevent it from causing a single-path alert.  It will
#			now generate its own error condition.
#		     Added a check for the iteration count in the log file. If
#			it indicates the error has existed for longer than one
#			week, another error is generated.
# Changes in v2.1:   Updated the Linux check to account for missing paths in
#			the output of the 'multipath -ll' command. Also, updated
#			the check for single-path devices to account for 
#			multiple paths on the same HBA.
# Changes in v2.15:  Fixed the Linux check to ignore the output of the 
#			multipath command if the multipathd service is off.
#		     Changed the mpio disk settings check to ignore IBM disk
#			and local scsi disk.
#		     Logs from error conditions will now be saved with both
#			the date and time allowing for multiple logs from the
#			same day to be saved.
# Changes in v2.16   Fixed the Solaris EMC check for single path devices. It
#			now used format to determine the hardware path of the
#			hba's.
#		     The entry in the error log and what will be displayed in
#			the HPSM ticket for a repeat alert has been changed.
#		     The Solaris vxdmp check now shows which paths are offline
#			rather than simply reporting the number of paths
#			offline.
# Changes in v2.17:  Changed the Solaris 10 mpxio check to use luxadm for both
#			path status and single-path checks.
#		     When the script detects that the error conditions have been
#			cleared, a log entry is now placed in the error log.
#		     The AIX check for HBA settings now checks for tape devices
#			in addition to direct-attached disk when determing
#			whether to exlude an HBA from the check.
# Changes in v2.18:  Added a check for NPIV-enabled AIX systems to verify there
#			are four paths for each disk.
# Changes in v2.19:  Updated Linux Redhat native multipathing check to account
#			for updated output of the multipath -ll command.
# Changes in v2.20:  Updated Redhat check to error if multipathd daemon is not
#			running.
# Changes in v2.21:  Updated the Redhat check to check for the version of the
#			device-mapper-multipath package and its different 
#			output.
# Changes in v2.22:  Updated Linux check for output of 'multipath -ll' command
#			to check for absence of multipath.conf file.
# Changes in v2.23:  Added check in Solaris 10 mpxio check to skip local devices
#			that are found in mapthadm output.
# Changes in v2.24:  Added a check for EMC Gatekeeper disks in the Linux native
#			mutlipathing section.
# Changes in v2.25:  Added the "ghost" status as acceptable for Linux native
#			multipathing for E-Series Netapp devices.
# Changes in v2.26:  Added check for Hadoop nodes.  Skip Linux check on these.
#
# Changes in v2.30:  Updated Solaris MPXIO check for Solaris 11.  Local disk
#			initiator ports are different.
#

# Load Modules.
use File::Copy;
use Getopt::Std;
getopt("s");

# Set constants.
my $error = 0;
my $iteration = 0;
my $iteration_error = 0;
my $singlepath = 0;
my @remediate;
my $ack_file = "/usr/local/bin/ov-sancheck.lock";
my $oldlogfile  = "/usr/local/bin/ov-sancheck.log";
my $logfile = "/var/adm/ov-sancheck.log";
my $errorfile = "/var/adm/ov-sancheck-error.log";
my $pidfile = "/usr/local/bin/ov-sancheck.pid";
my $version = "2.30";

MAIN();

sub MAIN()
{
  # Check if previous iteration of script is still running.
  if (-e $pidfile)
  {
    my $pid = `head $pidfile`;
    chomp($check_pid = `ps -fp $pid | grep -v PID`);
    return if ( ( $check_pid =~ /\b$pid\b/ ) && ( $check_pid =~ /ov-sancheck/ ))
  }

  # Capture pid of current process.
  open PID, ">$pidfile";
  print PID "$$";
  close PID;

  # Move old logfile to new location if needed.
  if (-e "$oldlogfile")
  {
    system "mv /usr/local/bin/ov-sancheck.log /var/adm";
  }

  # Rotate the log file.
  $logclean_result = &LogClean;

  # Check for errors reported on previous iteration.
  $iteration = &IterationCheck;

  # Check for two-week iteration length.
  $iteration_interval = ( $iteration / 84 );
  $iteration_error = 1 if ( $iteration_interval > 2 );

  # Open log(overwrite) and error(append) files.
  open ERROR, ">>$errorfile";

  open LOG, ">$logfile";
  select LOG;
  $| = 1;
  print "$logclean_result" if ( defined($logclean_result) );

  # Redirect STDERR to /dev/null
  open STDERR, ">>/dev/null";

  # Output the version to the log file
  print "Version: $version\n\n";

  # Determine OS.
  chomp($os = `uname -s`);

  if ($os eq "")
  {
    print "command to determine OS failed: $!";
    exit;
  } elsif ($os eq "AIX")
  {
    $result = &AIX;
  } elsif ($os eq "SunOS")
  {
    if ( -e "/usr/sbin/zoneadm" )
    {
      $zone_check = `zoneadm list`;
      $result = &SUN if ($zone_check =~ /global/s);
    } else
    {
      $result = &SUN;
    }
  } elsif ($os eq "HP-UX")
  {
    $result = &HPUX;
  } elsif ($os eq "Linux")
  {
    $result = &LINUX;
  } else
  {
    die "Unknown OS. $os is not supported by this script.";
  }

  # Try to remediate any errors that are found.
  if ($opt_s)
  {
    $skip_remediate = "1";
  }
  if ( (defined($remediate[0])) && ( $skip_remediate eq "0") )
  {
    foreach (@remediate)
    {
      &Remediate($_,$os);
      if ($remediate_return != 0)
      {
	print "$_ was not fixed.\n";
      }
    }
  }
  # Remove old logfiles from /usr/local/bin
  unlink "$oldlogfile" if -e "$oldlogfile";
}

sub AIX() {
  # Check settings on HBAs.
  my $direct_attach = 0;
  @fscsi = `lsdev -C |grep fscsi | grep Available`;
  if ( defined($fscsi[0]) )
  {
    print "NOTE: fscsi adapter settings are reported for informational purposes only.  These settings will not cause the script to generate an error.\n";
    foreach (@fscsi)
    {
      chomp;
      ($adapter,$location) = (split /\s+/, $_)[0, 2];
      # Check for non-disk devices
      $non_disk = `lsdev -C |grep $location`;
      next if ( $non_disk =~ /rmt|Tape|Library|Changer/ ); 
      @lsattr = `lsattr -El $adapter`;  
      foreach (@lsattr)
      {
	if (/^attach\s+(\w+)\s+.+/)
	{
	  $direct_attach = 1 if ($1 eq "al");
        }
	if (/^dyntrk\s+(\w+)\s+.+/)
	{
	  print "dyntrk not turned on for adapter $adapter.\n" if ( ($1 ne "yes") && ( $direct_attach == 0 ) );
	}
	if (/^fc_err_recov\s+(\w+)\s+.+/)
	{
	  print "fc_err_recov not set to fast_fail on adapter $adapter.\n" if ( ($1 ne "fast_fail") && ( $direct_attach == 0 ) );
	}
      }
    }
    print "-------------------------------------------------------------\n";
  }

  # Collect multi-path info.
  @hdlm = `/usr/DynamicLinkManager/bin/dlnkmgr view -path 2>&1`
        if -e "/usr/DynamicLinkManager/bin/dlnkmgr";
  @vxdmp = `vxdmpadm listctlr all`
	if -e "/usr/sbin/vxdmpadm";
  @emc = `lspv | grep hdiskpower`;
  $shark = `datapath query device`
	if -e "/usr/bin/datapath";
  @mpio = `lspath`
	if -e "/usr/sbin/lspath";

  # Parse multi-path info for errors.
  if ( defined($hdlm[0]) && $hdlm[0] !~ /dlnkmgr: not found/ )
  {
    print "HDLM detected.\n";
    # Check HDLM settings.
    @hdlm_settings = `/usr/DynamicLinkManager/bin/dlnkmgr view -sys 2>&1`;
    print "NOTE: HDLM settings are reported for informational purposes only.  These settings will not cause the script to generate an error.\n";
    foreach (@hdlm_settings)
    {
      chomp;
      print "$_\n" if (/^HDLM Version/);
      print "$_\n" if (/^Path Health Checking/);
      print "$_\n" if (/^Intermittent/);
      if (/^Auto Failback\s+.\s+(.+)/)
      {
	/([a-zA-Z]+).(\d+)./;
        ($on_off,$hdlm_afb_int) = ($1,$2);
	if ($on_off eq "off")
	{
	  print "$_\n";
	  print "Setting Auto Failback to on and interval to 5.\n";
	  $hdlm_set_afb_on = `/usr/DynamicLinkManager/bin/dlnkmgr set -afb on -intvl 5 -s`;
	  print "Error setting Auto Failback parameter.\n" unless ($hdlm_set_afb_on =~ /command completed normally/);
	} elsif ($hdlm_afb_int != 5)
	{
	  print "$_\n";
	  print "Setting Auto Failback interval to 5.\n";
	  $hdlm_set_afb_int = `/usr/DynamicLinkManager/bin/dlnkmgr set -afb on -intvl 5 -s`;
	  print "Error setting Auto Failback interval.\n" unless ($hdlm_set_afb_int =~ /command completed normally/);
	} else
        {
  	  print "$_\n";
        }
      }
    }
    if ( $hdlm[0] =~ /^KAPL/ )
    {
      $dlmfdrv_check = `lsdev -Cc disk |grep dlmfdrv`;
      if ( $dlmfdrv_check =~ /^\w+/ )
      {
        print "Error running dlnkmgr command, please invstigate.\n";
        $error++;
      } else
      {
        print "Error running dlnkmgr command, but no Hitachi devices detected.\n";
      }
    } else
    {
      foreach (@hdlm) 
      {
        if ( /^Path/ )
        {
          next;
        } elsif ( /Offline/)
        {
	  @bad_path_info = split /\s+/, $_;
	  push (@bad_luns, $bad_path_info[5]);
          $offline++;
        } 
        if ( /^\d+/ )
        {
          @path_info = split /\s+/, $_;
          push (@luns, $path_info[5]);
        }
      }
      foreach $count (@luns)
      {
        $lun_count{$count}++;
      }
      while ( ($key, $value) = each %lun_count )
      {
  	@hdlm_lun_check_path_list = ();
	@hdlm_lun_uniq = ();
        if ( $value == 1 )
        {
	  push (@bad_luns, $key);
          print "LUN $key shows only one path defined.\n";
	  $singlepath++;
        } else
  	{
	  @hdlm_lun_check = grep { /$key/ } @hdlm;
   	  foreach (@hdlm_lun_check)
	  {
	    chomp;
	    @hdlm_lun_check_line = split /\s+/, $_;
	    $hdlm_lun_check_path = $hdlm_lun_check_line[1];
	    $hdlm_lun_check_path =~ s/(\w{2}\.\w{2}).+/$1/;
	    push @hdlm_lun_check_path_list, $hdlm_lun_check_path;
   	  }
	  %hdlm_lun_seen = ();
	  foreach $hdlm_lun_item (@hdlm_lun_check_path_list)
	  {
	    push(@hdlm_lun_uniq, $hdlm_lun_item) unless $hdlm_lun_seen{$hdlm_lun_item}++;
	  }
	  if (scalar @hdlm_lun_uniq > 1)
	  {
	    $no_hdlm_error = 1;
	  } else
	  {
	    push (@bad_luns, $key);
            print "LUN $key appears to have all of its paths on one HBA.\n";
            $singlepath++;
	  }
	}
      }
      if ($singlepath > 0)
      {
        print "$singlepath single-path devices detected.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
        $error++;
	$problem++;
      }
      %seen = ();
      foreach $item (@bad_luns)
      {
	push (@uniq, $item) unless $seen{$item}++;
      }
      @bad_luns = @uniq;
      if ($offline > 0)
      {
	foreach (@bad_luns)
	{
          print "A path to LUN $_ is listed as Offline.\n";
	}
	print "$offline paths are listed as Offline.\n";
	$error++;
	$problem++;
	push @remediate, "hdlm";
      } 
      unless ( $problem > 0 )
      {
        print "No HDLM problems found.\n";
      } else
      {
	print "$problem problem paths detected.\n";
      }
      print "-------------------------------------------------------------\n";
    }
    # Check queue depth of dlmfdrv devices
    @dlm_devices = `lspv | grep dlmfdrv | grep -v dlmfdrvio`;
    print "NOTE: The queue_depth of HDLM devices is reported for informational purposes only.  Incorrect queue_depth settings will NOT generate an error for this script.\n";
    foreach (@dlm_devices)
    {
      chomp;
      /(^\w+)\s+.+/;
      (undef,$dlm_qd,undef) = split /\s+/, `lsattr -El $1 | grep queue_depth`;
      print "Warning: The queue depth for $1 is only $dlm_qd\n" unless ($dlm_qd > 7);
    }
    print "-------------------------------------------------------------\n";
  }

  if ( defined($vxdmp[0]) )
  {
    print "vxdmp detected.\n";
    foreach (@vxdmp) 
    {
      if ( /(fscsi\w+)/ )
      {
 	@vxdmp_ctlr = `vxdmpadm getsubpaths ctlr=$1`;
	foreach $vxdmp_check (@vxdmp_ctlr)
	{
          @line = split /\s+/, $vxdmp_check;
          next if ($line[0] =~ /^NAME|^===/);
          push @vxdmpluns, $line[3];
	}
      }
    }
    # Collect disk info so we can extract hardware location of hdisks
    @vxdmp_lsdev = `lsdev -Cc disk 2>/dev/null`;
    # Find unique luns.
    %seen = ();
    @uniq = grep { ! $seen{$_} ++ } @vxdmpluns;
    foreach $vxdmp_lun (@uniq)
    {
      @vxdisk = `vxdisk list $vxdmp_lun`;
      $skip_single_path = 0;
      @vxdmp_paths = ();
      @vxdmp_lun_uniq = ();
      %seen = ();
      @vxdmp_hw_loc_list = ();
      foreach (@vxdisk)
      {
        if (/(^hdisk\d+)\s+state=(\w+)/)
        {
 	  push (@vxdmp_paths, $1);
          unless ($2 eq "enabled")
	  {
	    push (@bad_luns, $vxdmp_lun);
	    $disabled++;
	  }
        }
      }
      foreach (@vxdmp_paths)
      {
	foreach $lsdev_check (@vxdmp_lsdev)
	{
	  $vxdmp_lsdev = $lsdev_check if ($lsdev_check =~ /^\b$_\b/);
	} 
        $hdisk_is_dlm = `/usr/DynamicLinkManager/bin/dlnkmgr view -lu | grep $_` if -e "/usr/DynamicLinkManager/bin/dlnkmgr";
        if  ( ( $vxdmp_lsdev =~ /MPIO/ ) || ( defined($hdisk_is_dlm) )  )
        {
          print "$_ points to an MPIO or HDLM device, ignoring.\n";
	  $skip_single_path = 1;
	  last;
        }
        $vxdmp_hw_loc = (split /\s+/, $vxdmp_lsdev)[2];
        $vxdmp_hw_loc =~ s/(^\w{2}-\w{2}).+/$1/;
        push (@vxdmp_hw_loc_list, $vxdmp_hw_loc);
      }
      next if ( $skip_single_path == 1 );
      foreach $item (@vxdmp_hw_loc_list)
      {
        push (@vxdmp_lun_uniq, $item) unless $seen{$item}++;
      }
      $pathcount = scalar @vxdmp_lun_uniq;
      if ($pathcount < 2)
      {
        push (@bad_luns, $vxdmp_lun);
        print "$vxdmp_lun shows all of its paths on one HBA.\n";
        $singlepath++;
      } 
    }
    if ($singlepath > 0)
    {
      print "$singlepath single-path devices detected.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
      $error++;
    }
    if ($disabled > 0)
    {
      print "$disabled disabled paths detected.\n";
      $error++;
      push @remediate, "vxdmp";
    }
    if ( ($disabled == 0) && ($singlepath == 0) )
    {
      print "No vxdmp problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }

  if ( defined($emc[0]) )
  {
    $powermt_out = `powermt display dev=all`;
    @powermt = split(/^\n/m, $powermt_out);
    $singlepath = 0;
    print "EMC PowerPath detected.\n";
    $pathcount = 0;
    foreach (@powermt)
    {
      @emc_fscsi = ();
      @emc_fscsi_uniq = ();
      %seen = ();
      $pathcount = 0;
      @powermt_dev = split(/\n/m, $_);
      foreach (@powermt_dev)
      {
	$hdiskpower = $powermt_dev[0];
	$hdiskpower =~ s/^Pseudo\sname=(.+)/$1/;
	if ( (/(fscsi\d+)/) && (! /Pseudo/ ) )
	{
	  push (@emc_fscsi, $1);
	  unless (/alive/)
	  {
	    push (@bad_luns, $hdiskpower);
	    $degraded++;
	  }
	}
      }
      foreach $item (@emc_fscsi)
      {
	push (@emc_fscsi_uniq, $item) unless $seen{$item}++;
      }
      $pathcount = scalar @emc_fscsi_uniq;
      push (@emc_single_path, $hdiskpower) if ($pathcount < 2);
    }
    if ( defined($emc_single_path[0]) )
    {
      foreach (@emc_single_path)
      {
        chomp ($emc_lun_size = `bootinfo -s $_`);
        if ( $emc_lun_size eq "2" )
        {
           print "$_ is a Gate Keeper device, single-path OK\n";
        } else
        {
	  push (@bad_luns, $_);
          $singlepath++;
          print "$_ shows all of its paths on one HBA.\n";
        }
      }
    }
    if ($degraded > 0)
    {
      print "$degraded degraded paths detected.\n";
      $error++;
      push @remediate, "emc";
    } 
    if ( $singlepath > 0 )
    {
      print "$singlepath devices show only one path defined.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
      $error++;
    }
    if ( ($degraded == 0) && ($singlepath == 0) )
    {
      print "No PowerPath problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }

  if ( ( defined($shark) ) && ( $shark !~ /No device file found/m ) )
  {
    $singlepath = 0;
    print "IBM ESS disk detected.\n";
    @shark = split /^\n/m, $shark;
    foreach (@shark)
    {
      @shark_lines = split /\n/, $_;
      $pathcount = 0;
      @shark_fscsi = ();
      @shark_fscsi_uniq = ();
      %seen = ();
      foreach ( @shark_lines )
      {
	if (/^DEV/)
	{
	  (undef, undef, undef, undef, $vpath, undef, undef, undef, undef) = split /\s+/, $_;
	} elsif (/(fscsi\d+)/)
	{ 
          push (@shark_fscsi, $1);
	  (undef, undef, undef, $state, $mode, undef, undef) = split /\s+/, $_;
	  unless ( ( ($state eq "OPEN") || ($state eq "CLOSE") ) && ( $mode eq "NORMAL" ) )
	  {
	    push (@bad_shark, $vpath);
	  }
	}
      }
      next if ( ! defined($vpath) );
      foreach $item (@shark_fscsi)
      {
        push (@shark_fscsi_uniq, $item) unless $seen{$item}++;
      }
      $pathcount = scalar @shark_fscsi_uniq;
      if ($pathcount < 2)
      {
	push (@bad_luns, $vpath);
	print "$vpath shows all of its paths on one HBA.\n";
	$singlepath++;
      }
    }
    if ( defined($bad_shark[0]) )
    {
      foreach (@bad_shark)
      {
	push (@bad_luns, $_);
        print "$_ is not in an operational state, run \"datapath query device\"\n";
        $degraded++;
      }
    }
    if ($degraded > 0)
    {
      print "$degraded problem paths detected.  Please investigate.\n";
      $error++;
      push @remediate, "shark";
    } 
    if ($singlepath > 0)
    {
      print "$singlepath devices show only one path defined.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
      $error++;
    }
    if ( ($degraded == 0) && ($singlepath == 0) )
    {
      print "No ESS problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }

  if ( defined($mpio[0]) )
  {
    print "MPIO detected.\n";
    $singlepath = 0;
    # Check to ensure pcmsrv service is running.
    $check_pcmsrv = `lssrc -s pcmsrv | grep -v Status`;
    unless ( $check_pcmsrv =~ /active|not on file/ )
    {
      print "pcmsrv not running, attempting to start.\n";
      $start_pcmsrv = `startsrc -s pcmsrv`;
      $recheck_pcmsrv = `lssrc -a | grep pcmsrv`;
      if ( $recheck_pcmsrv =~ /active/ )
      {
	print "pcmsrv started successfully.\n";
      } else
      {
        print "Unable to start pcmsrv.\n";
# Commented out error condition for this check until impact is better known.
#        $error++;
      }
    }
    # Check for NPIV
    $fcs_npiv = 1 if (`lsdev -C |grep fcs | grep Virtual`);
    print "NOTE: Checking of mpio disk settings hcheck_interval and hcheck_mode are for informational purposes only. Any warnings listed here will not cause the script to generate an error condition.\n";
    @mpio_check4hdlm = `/usr/DynamicLinkManager/bin/dlnkmgr view -path`
        if -e "/usr/DynamicLinkManager/bin/dlnkmgr";
    @mpio_lspv = `lspv`;
    foreach (@mpio_lspv)
    {
      @mpio_hbas = ();
      @mpio_hbas_uniq = ();
      %seen = ();
      chomp;
      $mpio_hdisk = (split /\s+/, $_)[0];
      @lspath_lines = grep { /\b$mpio_hdisk\b/ } @mpio;
      next if ( grep { /\b$mpio_hdisk\b/ } @mpio_check4hdlm );
      unless ( defined($lspath_lines[0]) )
      {
        next;
      } else
      {
	chomp;
	$mpio_settings_hdisk = (split /\s+/, $lspath_lines[0])[1];
	push (@mpio_settings_check, $mpio_settings_hdisk);
      }
      foreach (@lspath_lines)
      {
        chomp;
        ( $mpio_status,$mpio_hdisk,$mpio_hba ) = split /\s+/, $_;
	if ( $mpio_hba =~ /^scsi|sas/ )
	{
	  $skip_single_path = 1;
	  next;
	} else
	{
	  $skip_single_path = 0;
	}
        push (@mpio_hbas, $mpio_hba);
	unless ( $mpio_status =~ /Enabled/ )
        {
	  print "$mpio_hdisk on path $mpio_hba is not Enabled.\n";
          push (@bad_luns, $mpio_hdisk);
          $problem++;
        }
      }
      next if ( $skip_single_path == 1 );
      foreach $item (@mpio_hbas)
      {
    	 push (@mpio_hbas_uniq, $item) unless $seen{$item}++;
      }
      $pathcount = scalar @mpio_hbas_uniq;
      if ( $fcs_npiv == 1 )
      {
	@virtual_disk = `lsdev -Cc disk |grep Virtual`;
	push (@npiv_path_missing, $mpio_hdisk) if ( ($pathcount < 4) && ( ! grep { /$mpio_hdisk/ } @virtual_disk ) );
      }
      push (@mpio_single_path, $mpio_hdisk) if ($pathcount < 2);
    }
    # Check settings of hdisk devices.
    foreach $mpio_check_set_hdisk (@mpio_settings_check)
    {
      @mpio_lsattr_hdisk = `lsattr -El $mpio_check_set_hdisk`;
      foreach (@mpio_lsattr_hdisk)
      {
	chomp;
	last if ( ( /^PCM/ ) && ( /sddpcm|scsiscsd/ ) );
	if (/^hcheck_interval\s+(\d+)\s+.+/)
	{
	  print "$mpio_check_set_hdisk hcheck_interval is $1, should be 60.\n" if ( $1 != 60 );
	}
	if (/^hcheck_mode\s+(\w+)\s+.+/)
	{
	  print "$mpio_check_set_hdisk hcheck_mode is $1, should be nonactive.\n" if ( $1 ne "nonactive" );
	}
      }
    }
    if ( defined($npiv_path_missing[0]) )
    {
      foreach ( @npiv_path_missing )
      {
	print "$_ is not defined on all four NPIV HBAs.\n";
	$problem++;
      }
      $error++;
    }
    if ( defined($mpio_single_path[0]) )
    {
      $model = `lsattr -El sys0 | grep model`;
      unless ( $model =~ /9110-510|9110-51A/ )
      { 
	%mpio_lun_seen = ();
 	foreach $mpio_item (@mpio_single_path)
	{
	  push (@mpio_single_path_uniq, $mpio_item) unless $mpio_lun_seen{$mpio_item}++;
	}
	foreach (@mpio_single_path_uniq)
	{
	  push (@bad_luns, $_);
  	  $singlepath++;
	  print "$_ shows all of its paths on one HBA.\n";
	}
      }
    }
    if ($problem > 0)
    {
      print "$problem problem paths detected.  Please investigate.\n";
      $error++;
      push @remediate, "mpio";
    } 
    if ($singlepath > 0)
    {
      print "$singlepath devices show only one path defined.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
      $error++;
    }
    if ( ($problem == 0) && ($singlepath == 0) )
    {
      print "No MPIO problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }
  &ErrorLogging($error,\@bad_luns);
}

sub SUN() {
  # Ensure path is correct.
  $ENV{'PATH'} = "/etc:/usr/sbin:$ENV{'PATH'}";

  # Check for presence of HDLM, EMC PowerPath or vxdmp.
  @hdlm = `/opt/DynamicLinkManager/bin/dlnkmgr view -path 2>&1`
	if -e "/opt/DynamicLinkManager/bin/dlnkmgr";
  system "powermt display dev=all > /tmp/powermt.out 2>&1"
	if ( (-e "/usr/sbin/powermt" ) || (-e "/sbin/powermt" ) || (-e "/etc/powermt") );
  @vxdmp = `vxdmpadm listctlr all`
	if -e "/usr/sbin/vxdmpadm";
  
  # Check for mpxio.
  chomp($osversion = `uname -a`);
  $osversion =~ s/^\w+\s+\w+\s+(\d.\d+)\s+.+/$1/;
  if ( -e "/usr/sbin/mpathadm" )
  {
    @mpxio = `mpathadm list lu 2>&1`;
    @mpxio = () if ($mpxio[0] =~ /^ld.so.1/);
    $mpathadm = "yes";
  } else
  {
    @vhci = `grep mpxio-disable /kernel/drv/scsi_vhci.conf`
	if ( -e "/kernel/drv/scsi_vhci.conf" );
    @fp = `grep mpxio-disable /kernel/drv/fp.conf`
	if  ( -e "/kernel/drv/fp.conf" );
    if ( defined($vhci[0]) )
    {
      foreach (@vhci)
      {
        if ( ( /^mpxio/ ) && ( /no/ ) )
        {
          push (@mpxio, "yes");
        }
      }
    }
    if ( defined($fp[0]) )
    {
      foreach (@fp)
      {
        if ( ( /^mpxio/ ) && ( /no/ ) )
        {
          push (@mpxio, "yes");
        }
      }
    }
  }

  # Parse HDLM data if present.
  if ( defined($hdlm[0]) && $hdlm[0] !~ /target path was not found/ )
  {
    print "HDLM detected.\n";
    # Check HDLM settings.
    @hdlm_settings = `/opt/DynamicLinkManager/bin/dlnkmgr view -sys 2>&1`;
    print "NOTE: HDLM settings are reported for informational purposes only.  These settings will not cause the script to generate an error.\n";
    foreach (@hdlm_settings)
    {
      chomp;
      print "$_\n" if (/^HDLM Version/);
      print "$_\n" if (/^Path Health Checking/);
      print "$_\n" if (/^Intermittent/);
      if (/^Auto Failback\s+.\s+(.+)/)
      {
        /([a-zA-Z]+).(\d+)./;
        ($on_off,$hdlm_afb_int) = ($1,$2);
        if ($on_off eq "off")
        {
          print "$_\n";
          print "Setting Auto Failback to on and interval to 5.\n";
          $hdlm_set_afb_on = `/opt/DynamicLinkManager/bin/dlnkmgr set -afb on -intvl 5 -s`;
          print "Error setting Auto Failback parameter.\n" unless ($hdlm_set_afb_on =~ /command completed normally/);
        } elsif ($hdlm_afb_int != 5)
        {
          print "$_\n";
          print "Setting Auto Failback interval to 5.\n";
          $hdlm_set_afb_int = `/opt/DynamicLinkManager/bin/dlnkmgr set -afb on -intvl 5 -s`;
          print "Error setting Auto Failback interval.\n" unless ($hdlm_set_afb_int =~ /command completed normally/);
        } else
        {
          print "$_\n";
        }
      }
    }
    if ( $hdlm[0] =~ /^KAPL/ )
    {
      print "Error running dlnkmgr command, please investigate.\n";
      $error++;
    } else
    {
      print "$hdlm[0]\n";
      foreach (@hdlm)
      {
        if ( /^Path/ )
        {
          next;
        } elsif ( /Offline/)
        {
	  @bad_path_info = split /\s+/, $_;
          push (@bad_luns, $bad_path_info[5]);
          $offline++;
        } 
	if ( /^\d+/ )
        {
          @path_info = split /\s+/, $_;
          push (@luns, $path_info[5]);
        }
      }
      foreach $count (@luns)
      {
        $lun_count{$count}++;
      } 
      while ( ($key, $value) = each %lun_count )
      {
        @hdlm_lun_check_path_list = ();
        @hdlm_lun_uniq = ();
        if ( $value == 1 )
        {
          push (@bad_luns, $key);
          print "LUN $key shows only one path.\n";
	  $singlepath++;
        } else
        {
          @hdlm_lun_check = grep { /$key/ } @hdlm;
          foreach (@hdlm_lun_check)
          {
            chomp;
            @hdlm_lun_check_line = split /\s+/, $_;
            $hdlm_lun_check_path = $hdlm_lun_check_line[1];
            $hdlm_lun_check_path =~ s/(\w{2}\.\w{2}).+/$1/;
            push @hdlm_lun_check_path_list, $hdlm_lun_check_path;
          }
          %hdlm_lun_seen = ();
          foreach $hdlm_lun_item (@hdlm_lun_check_path_list)
          {
            push(@hdlm_lun_uniq, $hdlm_lun_item) unless $hdlm_lun_seen{$hdlm_lun_item}++;
          }
          if (scalar @hdlm_lun_uniq > 1)
          {
            $no_hdlm_error = 1;
          } else
          {
            push (@bad_luns, $key);
            print "LUN $key appears to have all of its paths on one HBA.\n";
            $singlepath++;
          }
        }
      }
      if ($singlepath > 0)
      {
        print "$singlepath single-path devices detected.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
        $error++;
      }
      %seen = ();
      foreach $item (@bad_luns)
      {
        push (@uniq, $item) unless $seen{$item}++;
      }
      @bad_luns = @uniq;
      if ($offline > 0)
      {
        foreach (@bad_luns)
        {
          print "A path to LUN $_ is listed as Offline.\n";
        }
        print "$offline paths are listed as Offline.\n";
	$error++;
	push @remediate, "hdlm";
      } elsif ($no_hdlm_error)
      {
        print "No HDLM problems found.\n";
      }
    }
    print "-------------------------------------------------------------\n";
  }
  # Parse EMC data if present.
  if ( -e "/tmp/powermt.out" )
  {
    print "EMC PowerPath detected.\n";
    open EMC, "/tmp/powermt.out";
    local $/ = undef;
    @emc = split(/^\n/m, <EMC>);
    close EMC;
    unlink "/tmp/powermt.out";
    $singlepath = 0;

    # Parse disk paths from format command for use in single-path check later
    $emc_format_input = `echo|format`;
    @emc_format = split /\n/, $emc_format_input;
    $emc_count = 0;
    foreach ( @emc_format )
    {
	    chomp;
  	  unless ( /(c\d+t\w+d\d+)/ )
      {
        $emc_count++;
        next
      } else
      {
        $emc_count++;
        $emc_disk = $1;
				$emc_format[$emc_count] =~ s/^\s+(.+)/$1/;
        chomp($emc_path_hash{$emc_disk} = $emc_format[$emc_count]);
      }
    }

    foreach (@emc)
    {
      @emc_path = ();
      @emc_path_uniq = ();
      %seen = ();
      $pathcount = 0;
      @emc_lines = split /\n/, $_;
      foreach ( @emc_lines )
      {
      	if ( /^\d+/ )
	      {
          $emc_path_line_disk = (split /\s+/, $_)[2];
					$emc_path_line_disk =~ s/(.+)s0$/$1/;
      	  unless (/alive/)
	        {
      	    push (@bad_luns, $emc_path_line_disk);
	          $degraded++;
	        }
    	    push (@emc_path, $emc_path_hash{$emc_path_line_disk});
      	  $pathcount++ if (/active|unlic/);
      	  $emc_unlic = 1 if (/unlic/);
	      }
      }
      if ( $pathcount == 1 )
      {
        push (@emc_single_path, $emc_path_line_disk);
      } else
      {
      	foreach $item (@emc_path)
	     {
     	  push (@emc_path_uniq, $item) unless $seen{$item}++;
	     }
       	$emc_pathcount = scalar @emc_path_uniq;
       	push (@emc_single_path, $emc_path_line_disk) if ($emc_pathcount < 2);
      }
    }
    if ( defined($emc_single_path[0]) )
    {
      $iostat = `iostat -En`;
      @iostat = split(/^Illegal/m, $iostat);
      foreach $emc_single_lun (@emc_single_path)
      {
      	$emc_single_lun =~ s/(\w+)s0/$1/;
        foreach (@iostat)
        {
          if ( (/\b$emc_single_lun\b/m) || (/($emc_single_lun)Soft/) )
          {
            @iostat_split = split /\n/, $_;
            foreach (@iostat_split)
            {
              if ( /^Size:/ )
              {
            		chomp;
                (undef, undef, $emc_lun_size) = split /\s+/, $_;
            		$emc_lun_size =~ s/<(\w+)/$1/;
            		$emc_lun_size_num = atoi("$emc_lun_size");
            		if ($emc_lun_size_num <= 47185920)
              	{
	                print "$emc_single_lun is a Gate Keeper device, single-path OK\n";
              	} else
              	{
							    push (@bad_luns, $emc_single_lun);
              	  $singlepath++;
              	  print "$emc_single_lun shows only one path defined.\n";
            	  }
              }
            }
          }
        }
      }
    }
    if ( $emc_unlic == 1 )
    {
      print "ERROR: PowerPath reporting an unlicensed condition.\n";
      $error++;
    }
    if ($degraded > 0)
    {
      print "$degraded degraded paths detected.\n";
      $error++;
      push @remediate, "emc";
    } 
    if ( $singlepath > 0 )
    {
      print "$singlepath devices show only one path defined.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
      $error++;
    }
    if ( ($degraded == 0) && ($singlepath == 0) )
    {
      print "No PowerPath problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }
  # Parse mpxio data if present.
  if ( (defined($mpxio[0]) ) && ( ! ( $mpxio[0] =~ /^ld.so.1/ ) ) )
  {
    $singlepath = 0;
    $disabled = 0;
    print "mpxio detected.\n";
    if ($mpathadm eq "yes" )
    {
      foreach (@mpxio)
      {
	if ( ( $mpxio[ $#mpxio ] =~ /Error: Unable to get configuration information/) || (  $mpxio[ $#mpxio ] =~ /Unable to complete operation/ ) )
        {
          print "mpathadm returned an error while executing. Processing of LUNs cancelled.\n";
          $disabled++;
	  $skip_vxdmp_check = "1";
          last;
        }
	chomp;
	if ( /^\s+\/dev\/rdsk/ )
	{
	  push (@mpxio_lun_list, $_);
	}
      }
      foreach $mpxio_lun (@mpxio_lun_list)
      {
	@luninfo = `luxadm display $mpxio_lun 2>&1`;
	if ( $luninfo[0] =~ /Error: SCSI failure/ )
        {
          print "$mpxio_lun indicates a SCSI failure when running luxadm.\n";
          push (@bad_luns, $mpxio_lun);
          $disabled++;
          next;
        } elsif ( $luninfo[0] =~ /Error: Could not find valid path to the device/ )
 	{
	  my $mpxio = (split /\s+/, `mpathadm show lu $mpxio_lun | grep Initiator`)[4];
	  if ( $mpxio =~ /^5|^w5/ )
	  {
	    print "$mpxio_lun appears to be a local device, skipping.\n";
	    next;
	  }
	}
        foreach (@luninfo)
        {
          chomp;
	  if ( /Controller/ )
          {
            s/^\s+(.+)/$1/;
            (undef, $mpxio_ctlr) = split /\s+/, "$_";
            push (@mpxio_ctlr_list, $mpxio_ctlr);
            $singlepath++;
          }
	  if ( /State/ )
 	  {
	    unless ( /ONLINE/ )
	    {
	      print "$mpxio_lun on controller $mpxio_ctlr is not online.\n";
	      $disabled++;
  	    }
	  }
	}
        if ($singlepath < 2)
        {
	  push (@bad_luns, $mpxio_lun);
          print "$mpxio_lun shows only one path defined.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
          $error++;
          $disabled++;
        } else
	{
	  foreach $item (@mpxio_ctlr_list)
          {
            push (@mpxio_path_uniq, $item) unless $seen{$item}++;
          }
          $mpxio_path_count = scalar @mpxio_path_uniq;
          if ( $mpxio_path_count < 2 )
          {
            push (@bad_luns, $mpxio_lun);
            print "$mpxio_lun shows all of its paths defined on one HBA. Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n"
;
            $error++;
            $disabled++;
          }
	}
      }
    } else
    # Solaris 8 or 9 parsing.
    {
      chomp(@devices = `ls -al /dev/rdsk | grep s2 | grep scsi_vhci`);
      foreach (@devices)
      {
	@mpxio_ctlr_list = ();
        @mpxio_path_uniq = ();
	%seen = ();
	$state = 0;
	$singlepath = 0;
	chomp;
	@split = split /\s+/, $_;
	@luninfo = `luxadm display /dev/rdsk/$split[8] 2>&1`;
        if ( $luninfo[0] =~ /Error: SCSI failure/ )
        {
          print "/dev/rdsk/$split[8] indicates a SCSI failure when running luxadm.\n";
          push (@bad_luns, $split[8]);
          $disabled++;
          next;
        }
	foreach (@luninfo)
	{
	  chomp;
	  if ( /State/ )
	  {
	    s/^\s+(.+)/$1/;
	    (undef, $value) = split /\s+/, "$_";
	    unless ( $value eq "ONLINE" )
            {
	      push (@bad_luns, $split[8]);
              $disabled++;
              print "/dev/rdsk/$split[8] shows as not online.\n";
            }
	  } elsif ( /Controller/ )
	  {
	    s/^\s+(.+)/$1/;
	    (undef, $mpxio_ctlr) = split /\s+/, "$_";
	    push (@mpxio_ctlr_list, $mpxio_ctlr);
	    $singlepath++;
	  }
	}
	if ($singlepath < 2)
	{
	  push (@bad_luns, $split[8]);
	  print "/dev/rdsk/$split[8] shows only one path defined.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
	  $error++;
	  $disabled++;
	} else
	{
	  foreach $item (@mpxio_ctlr_list)
	  {
	    push (@mpxio_path_uniq, $item) unless $seen{$item}++;
	  }
	  $mpxio_path_count = scalar @mpxio_path_uniq;
	  if ( $mpxio_path_count < 2 )
	  {
  	    push (@bad_luns, $split[8]);
	    print "/dev/rdsk/$split[8] shows all of its paths defined on one HBA. Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
	    $error++;
	    $disabled++;
	  }
	}
      }
    }
    if ($disabled > 0)
    {
      print "$disabled mpxio errors detected.\n";
      $error++;
      push @remediate, "mpxio";
    } else
    {
      print "No mpxio problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }
  # Parse vxdmp data if present.
  if ( ( defined($vxdmp[0])) && ( $skip_vxdmp_check eq "1" ) )
  {
    print "vxdmp detected.\n";
    print "mpxio check failed.  Skipping vxdmp check.\n";
  } elsif ( ( defined($vxdmp[0])) && ( $skip_vxdmp_check ne "1" ) )
  {
    print "vxdmp detected.\n";
    $singlepath = 0;
    foreach (@vxdmp)
    {
      if ( (/^(c\d+|emcp)/) && ! (/Disk|OTHER|SENA|FAKE|SUN3310|SUN3510|SEAGATE/i) )
      {
        @vxdmp_ctlr = `vxdmpadm getsubpaths ctlr=$1`;
        foreach $vxdmp_check (@vxdmp_ctlr)
        {
          $skip_vxdmp = 0;
          @line = split /\s+/, $vxdmp_check;
          next if ($line[0] =~ /^NAME|^===|NONAME/);
          if (defined($hdlm[0]))
          {
            $line[0] =~ s/(.+)s2$/$1/;
            $line[0] =~ m/^c\d{1,2}(.+)..(d\d+$)/;
            $partone = $1;
            $parttwo = $2;
            foreach (@hdlm)
            {
              next if ( /^Path/ );
              if ( /$partone..$parttwo/ )
              {
                print "$line[0] managed by HDLM, skipping.\n";
                $skip_vxdmp = "1";
                last;
              }
            }
          }
          if (defined($emc[0]))
          {
            $line[0] =~ s/^(\w+)\s+.+/$1/;
            chomp($vxdmp_found_emc = `powermt display dev=$line[0]`);
            unless ( $vxdmp_found_emc =~ /^Bad\sdev/ )
            {
              print "$line[0] managed by EMC, skipping.\n";
              $skip_vxdmp = "1";
            }
          }
          if (defined($mpxio[0]))
          {
            $line[0] =~ s/^(\w+)\s+.+/$1/;
            if ($mpathadm eq "yes" )
            {
              if ( grep { /$line[0]/ } @mpxio )
              {
                print "$line[0] managed by mpxio, skipping.\n";
                $skip_vxdmp = "1";
              }
            } else
            {
              if (`ls -al /dev/rdsk/$line[0] | grep scsi_vhci`)
              {
                print "$line[0] managed by mpxio, skipping.\n";
                $skip_vxdmp = "1";
              } else
              {
                if (`ls -al /dev/rdsk/$line[0]s2 | grep scsi_vhci`)
                {
                  print "$line[0] managed by mpxio, skipping.\n";
                  $skip_vxdmp = "1";
                }
              }
            }
          }
          if ( $skip_vxdmp ne "1" )
          {
            push @vxdmpluns, $line[3];
          }
        }
      }
    }
    # Find unique luns.
    %seen = ();
    @uniq = grep { ! $seen{$_} ++ } @vxdmpluns;
    foreach (@uniq)
    {
      @vxdisk = `vxdisk list $_ 2>&1`;
      if ( $vxdisk[0] =~ /Disk\snot\sin\sthe\sconfiguration/ )
      {
        print "vxprint failed when running against $_ - was this device reclaimed?\n";
        $disabled++;
        next;
      }
      foreach (@vxdisk)
      {
        $pathcount = $1 if (/^numpaths:\s+(\d+)/);
        if (/state=(\w+)/)
        {
          @vxdmp_line = split /\s+/, $_;
          unless ($vxdmp_line[1] =~ /enabled/)
          {
	    print "$vxdmp_line[0] shows one of its paths is not enabled.\n";
            push (@bad_luns, $vxdmp_line[0]);
            $disabled++;
          }
        }
      }
      if ($pathcount < 2)
      {
        push (@bad_luns, $_);
        print "$_ shows only one path defined.\n";
        $singlepath++;
      }
    }
    if ($singlepath > 0)
    {
      print "$singlepath single-path devices detected.  Check the LUN masking or
 provisioning in SANScreen to ensure it is correct.\n";
      $error++;
    }
    if ($disabled > 0)
    {
      print "$disabled disabled paths detected.\n";
      $error++;
      push @remediate, "vxdmp";
    }
    if ( ($disabled == 0) && ($singlepath == 0) )
    {
      print "No vxdmp problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }
  &ErrorLogging($error,\@bad_luns);
}

sub HPUX() {
  # Collect multi-pathing info.
  @hdlm = `/opt/DynamicLinkManager/bin/dlnkmgr view -path 2>&1`
	if -e "/opt/DynamicLinkManager/bin/dlnkmgr";
  system "/sbin/powermt display dev=all > /tmp/powermt.out"
	if -e "/sbin/powermt";

  # Parse multi-pathing info.
  if ( defined($hdlm[0]) && $hdlm[0] !~ /dlnkmgr: not found/ )
  {
    print "HDLM detected.\n";
    # Check HDLM settings.
    @hdlm_settings = `/opt/DynamicLinkManager/bin/dlnkmgr view -sys 2>&1`;
    print "NOTE: HDLM settings are reported for informational purposes only.  These settings will not cause the script to generate an error.\n";
    foreach (@hdlm_settings)
    {
      chomp;
      print "$_\n" if (/^HDLM Version/);
      print "$_\n" if (/^Path Health Checking/);
      print "$_\n" if (/^Intermittent/);
      if (/^Auto Failback\s+.\s+(.+)/)
      {
        /([a-zA-Z]+).(\d+)./;
        ($on_off,$hdlm_afb_int) = ($1,$2);
        if ($on_off eq "off")
        {
          print "$_\n";
          print "Setting Auto Failback to on and interval to 5.\n";
          $hdlm_set_afb_on = `/opt/DynamicLinkManager/bin/dlnkmgr set -afb on -intvl 5 -s`;
          print "Error setting Auto Failback parameter.\n" unless ($hdlm_set_afb_on =~ /command completed normally/);
        } elsif ($hdlm_afb_int != 5)
        {
          print "$_\n";
          print "Setting Auto Failback interval to 5.\n";
          $hdlm_set_afb_int = `/opt/DynamicLinkManager/bin/dlnkmgr set -afb on -intvl 5 -s`;
          print "Error setting Auto Failback interval.\n" unless ($hdlm_set_afb_int =~ /command completed normally/);
        } else
        {
          print "$_\n";
        }
      }
    }
    if ( $hdlm[0] =~ /^KAPL/ )
    {
      print "Error running dlnkmgr command, please investigate.\n";
      $error++;
    } else
    {
      print "$hdlm[0]\n";
      foreach (@hdlm)
      {
        if ( /^Path/ )
        {
          next;
        } elsif ( /Offline/ )
        {
	  @bad_path_info = split /\s+/, $_;
          push (@bad_luns, $bad_path_info[5]);
          $offline++;
        } 
	if ( /^\d+/ )
        {
          @path_info = split /\s+/, $_;
          push (@luns, $path_info[5]);
        }
      }
      foreach $count (@luns)
      {
        $lun_count{$count}++;
      }
      while ( ($key, $value) = each %lun_count )
      {
        @hdlm_lun_check_path_list = ();
        @hdlm_lun_uniq = ();
        if ( $value == 1 )
        {
	  push (@bad_luns, $key);
          print "LUN $key shows only one path.\n";
	  $singlepath++;
        } else
        {
          @hdlm_lun_check = grep { /$key/ } @hdlm;
          foreach (@hdlm_lun_check)
          {
            chomp;
            @hdlm_lun_check_line = split /\s+/, $_;
            $hdlm_lun_check_path = $hdlm_lun_check_line[1];
            $hdlm_lun_check_path =~ s/(\w{2}\.\w{2}).+/$1/;
            push @hdlm_lun_check_path_list, $hdlm_lun_check_path;
          }
          %hdlm_lun_seen = ();
          foreach $hdlm_lun_item (@hdlm_lun_check_path_list)
          {
            push(@hdlm_lun_uniq, $hdlm_lun_item) unless $hdlm_lun_seen{$hdlm_lun_item}++;
          }
          if (scalar @hdlm_lun_uniq > 1)
          {
            $no_hdlm_error = 1;
          } else
          {
            push (@bad_luns, $key);
            print "LUN $key appears to have all of its paths on one HBA.\n";
            $singlepath++;
          }
        }
      }
      if ($singlepath > 0)
      {
        print "$singlepath single-path devices detected.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
        $error++;
      }
      %seen = ();
      foreach $item (@bad_luns)
      {
        push (@uniq, $item) unless $seen{$item}++;
      }
      @bad_luns = @uniq;
      if ($offline > 0)
      {
	foreach (@bad_luns)
        {
          print "A path to LUN $_ is listed as Offline.\n";
        }
        print "$offline paths are listed as Offline.\n";
	$error++;
	push @remediate, "hdlm";
      } elsif ($no_hdlm_error)
      {
        print "No HDLM problems found.\n";
      }
    }
    print "-------------------------------------------------------------\n";
  }
  if ( -e "/tmp/powermt.out" )
  {
    print "EMC PowerPath detected.\n";
    open EMC, "/tmp/powermt.out";
    local $/ = undef;
    @emc = split(/^\n/m, <EMC>);
    close EMC;
    unlink "/tmp/powermt.out";
    $singlepath = 0;
    foreach (@emc)
    {
      $pathcount = 0;
      @emc_lines = split /\n/, $_;
      foreach ( @emc_lines )
      {
        if ( /^\s+\d+/ )
        {
          @emc_path_line = split /\s+/, $_;
          unless (/alive/)
	  {
	    push (@bad_luns, $emc_path_line[3]);
	    $degraded++;
	  }
          $pathcount++ if (/active/);
        }
      }
      if ( $pathcount < 2 )
      {
        push (@emc_single_path, $emc_path_line[3]);
      }
    }
    if ( defined($emc_single_path[0]) )
    {
      foreach $emc_single_lun (@emc_single_path)
      {
	$diskinfo = `diskinfo /dev/rdsk/$emc_single_lun 2>&1`;
	@lun_diskinfo = split /\n/, $diskinfo;
	(undef, undef, $emc_lun_size, undef) = split /\s+/, $lun_diskinfo[4];
	if ($emc_lun_size < 3000)
        {
          print "$emc_single_lun is a Gate Keeper device, single-path OK\n";
        } else
        {
	  push (@bad_luns, $emc_single_lun);
          $singlepath++;
          print "$emc_single_lun shows only one path defined.\n";
        }
      }
    }
    if ($degraded > 0)
    {
      print "$degraded degraded paths detected.\n";
      $error++;
      push @remediate, "emc";
    } 
    if ( $singlepath > 0 )
    {
      print "$singlepath devices show only one path defined.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
      $error++;
    }
    if ( ($degraded == 0) && ($singlepath == 0) )
    {
      print "No PowerPath problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }
  &ErrorLogging($error,\@bad_luns);
}

sub LINUX() {
 # Set PATH
  $ENV{'PATH'} = "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/pb/bin:/root/bin:/etc/vx/bin:/opt/VRTS/bin/:/root/bin:/opt/OV/bin:/opt/OV/bin/OpC:/opt/perf/bin:/opt/OV/bin/OpC/utils:/var/opt/OV/bin/instrumentation";

  # Check for Hadoop node and skip check, if necessary
  if ( -e "/opt/mapr" )
  {
    print "Hadoop node detected.  SAN path checking suppressed.\n";
    exit;
  }

  # Check for presence of vxdmp or RHEL native multipath.
  @vxdmp = `/sbin/vxdmpadm listctlr all 2>&1`
        if -e "/sbin/vxdmpadm";
  @rhel5 = `/sbin/multipath -ll`
	if -e "/sbin/multipath"; 

  # Parse RHEL native multipath if present.
  if ( ( defined($rhel5[0]) ) && ( $vxdmp[0] !~ /STATE/ )  && ( ! grep { /multipath.conf does not exist/ } @rhel5 ) )
  {
    my $multipathd_fail = 0;
    print "RHEL native multipathing detected.\n";
    # Check to make sure multipathd is running 
    $rhel5_multipathd = `service multipathd status`;
    unless ( $rhel5_multipathd =~ /running/ )
    {
      print "ERROR: multipathd daemon is not running.\n";
      $error++;
      $multipathd_fail = 1;
    }
    @rhel5_hosts = `systool -c fc_host|grep Device|grep -v Class`;
    foreach (@rhel5_hosts)
    {
      chomp;
      s/\s+Device\s=\s"host(\d+)"/$1/;
      @rhel5_devices = `ls -ld /sys/class/scsi_disk/$_*`;
      foreach (@rhel5_devices)
      {
        chomp;
        $rhel5_dev_path = (split /\s+/)[8];
        $rhel5_dev_path =~ s/\/sys\/class\/scsi_disk\/(.+)/$1/;
        @rhel5_dev_list = grep { /\b$rhel5_dev_path\b/ } @rhel5;
        chomp($rhel5_dev_entry = $rhel5_dev_list[0]);
        unless ( $rhel5_dev_entry =~ /\d+:\d+:\d+:\d+/ )
        {
          print "Path $rhel5_dev_path appears in /sys/class/scsi_disk, but appears to be missing.\n";
	  $rhel5_disabled++;
          next;
        }
	$multipath_ver = `rpm -q device-mapper-multipath 2>&1`;
	$oracle_linux = `rpm -q oraclelinux-release 2>&1`;
	if ( ( $oracle_linux =~ /not installed/ ) && ( $multipath_ver !~ /0.4.9/ ) )
	{
          ($rhel5_host_info, $rhel5_path, $rhel5_status) = (split /\s+/, $rhel5_dev_entry)[2, 3, 5];
          chomp($fdisk = `sfdisk -s /dev/$rhel5_path`);
          if ( $fdisk =~ /\b2880\b/ )
          {
            print "Disk $rhel5_path is a Gatekeeper disk, skipping further checks.\n";
            next;
          }
          ($rhel5_host_port, $rhel5_ldev) = (split /:/,$rhel5_host_info)[0, 3];
          $rhel5_hba_count{$rhel5_ldev}{$rhel5_host_port}++;
          $rhel5_status =~ /\[(\w+)\]\[(\w+)\]/;
          ($rhel5_dm_state,$rhel5_phys_state) = ($1,$2);
          unless ( ( $rhel5_dm_state =~ /active/ ) && ( $rhel5_phys_state =~ /ready|ghost/ ) )
          {
            push (@bad_luns, $rhel5_path);
            print "Path $rhel5_host_info for device $rhel5_path is not active and ready.\n";
            $rhel5_disabled++;
          }
	} else
	{
	  ($rhel5_host_info, $rhel5_path, $rhel5_dm_state, $rhel5_phys_state) = (split /\s+/, $rhel5_dev_entry)[2, 3, 5, 6];
          chomp($fdisk = `sfdisk -s /dev/$rhel5_path`);
          if ( $fdisk =~ /\b2880\b/ )
          {
            print "Disk $rhel5_path is a Gatekeeper disk, skipping further checks.\n";
            next;
          }
          ($rhel5_host_port, $rhel5_ldev) = (split /:/,$rhel5_host_info)[0, 3];
          $rhel5_hba_count{$rhel5_ldev}{$rhel5_host_port}++;
          unless ( ( $rhel5_dm_state =~ /active/ ) && ( $rhel5_phys_state =~ /ready|ghost/ ) )
          {
            push (@bad_luns, $rhel5_path);
            print "Path $rhel5_host_info for device $rhel5_path is not active and ready.\n";
            $rhel5_disabled++;
          }
        }
      }
    }
    for $rhel5_element ( keys %rhel5_hba_count )
    {
      $rhel5_pathcount = scalar keys %{ $rhel5_hba_count{$rhel5_element} };
      if ( $rhel5_pathcount < 2 )
      {
        $rhel5_singlepath++;
        $error++;
      }
    }
    if ($rhel5_singlepath > 0)
    {
      print "$rhel5_singlepath single-path devices detected.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
      $error++;
    }
    if ($rhel5_disabled > 0)
    {
      print "$rhel5_disabled disabled paths detected.\n";
      $error++;
    }
    if ( ($rhel5_disabled == 0) && ($rhel5_singlepath == 0) && ($multipathd_fail == 0) )
    {
      print "No RHEL native multipathing problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }
  
  # Parse vxdmp data if present.
  if ( defined($vxdmp[0]) )
  {
    print "vxdmp detected.\n";
    foreach (@vxdmp)
    {
      if ( (/^(c\d+)/) && ! (/OTHER|SENA|FAKE/i) )
      {
        @vxdmp_ctlr = `/sbin/vxdmpadm getsubpaths ctlr=$1`;
        foreach $vxdmp_check (@vxdmp_ctlr)
        {
          @line = split /\s+/, $vxdmp_check;
          next if ($line[0] =~ /^NAME|^===|NONAME/);
          push @vxdmpluns, $line[3];
        }
      }
    }
    # Find unique luns.
    %seen = ();
    @uniq = grep { ! $seen{$_} ++ } @vxdmpluns;
    foreach (@uniq)
    {
      @vxdisk = `/sbin/vxdisk list $_ 2>&1`;
      if ( $vxdisk[0] =~ /Disk\snot\sin\sthe\sconfiguration/ )
      {
        print "vxdisk command failed when running against $_ - was this device reclaimed?\n";
        $disabled++;
        next;
      }
      foreach (@vxdisk)
      {
        $pathcount = $1 if (/^numpaths:\s+(\d+)/);
        if (/state=(\w+)/)
        {
          @vxdmp_line = split /\s+/, $_;
          unless ($vxdmp_line[1] =~ /enabled/)
          {
            push (@bad_luns, $vxdmp_line[0]);
            $disabled++;
          }
        }
      }
      if ($pathcount < 2)
      {
        push (@bad_luns, $_);
        print "$_ shows only one path defined.\n";
        $singlepath++;
      }
    }
    if ($singlepath > 0)
    {
      print "$singlepath single-path devices detected.  Check the LUN masking or provisioning in SANScreen to ensure it is correct.\n";
      $error++;
    }
    if ($disabled > 0)
    {
      print "$disabled disabled paths detected.\n";
      $error++;
      push @remediate, "vxdmp";
    }
    if ( ($disabled == 0) && ($singlepath == 0) )
    {
      print "No vxdmp problems found.\n";
    }
    print "-------------------------------------------------------------\n";
  }
  &ErrorLogging($error,\@bad_luns);
}

sub atoi() {
  my $t;
  foreach my $d (split(//, shift())) 
  {
    $t = $t * 10 + $d;
  }
  return $t;
}

sub LogClean() {
  # Rotate log on 1st day of the month.
  chomp($today = `date "+%d"`);
  if ( ($today == 1) && ($iteration < 1) )
  {
    rename "/var/adm/ov-sancheck-error.log", "/var/adm/ov-sancheck-error.log.1";
  }
  # Remove log copies older than 60 days.
  my @old_logfiles = glob "/usr/local/bin/ov-sancheck.log.* /var/adm/ov-sancheck.log.*";
  foreach (@old_logfiles)
  {
    if (-M $_ > 60)
    {
    $logclean = "$_ is older than 60 days, deleting it.\n";
    unlink $_ or $unlink = "Failed to remove $_: $!\n";
    }
  }
}

sub IterationCheck() {
  # Check for iteration count in log file.
  open PREVLOG, "/var/adm/ov-sancheck.log";

  @lines = <PREVLOG>;
  foreach (@lines)
  {
    if ( /iteration\s+(\d+)/ )
    {
      $return = $1;
      last;
    }
  }

  close PREVLOG;
  return $return;
}

sub ErrorLogging() {
  # Check for errors and log if necessary.
  @uniq = ();
  $local_error = $_[0];
  @local_bad_luns = @{$_[1]};
  %seen = ();
  foreach (@local_bad_luns)
  {
    push (@uniq, $_) unless $seen{$_}++;
  }
  @local_bad_luns = @uniq;
  if ( -e $ack_file )
  {
    open LOCK, "$ack_file";
    local $/ = undef;
    @lock_bad_luns = split(/\n/m, <LOCK>);
    close LOCK;
    %seen = ();
    foreach $lock_find (@lock_bad_luns) { $seen{$lock_find} = 1 }
    foreach $local_find (@local_bad_luns)
    {
      unless ($seen{$local_find})
      {
        push (@more_bad, $local_find);
      }
    }
  }
  if ( ($local_error > 0) && ($iteration == 1) && (! -e $ack_file) )
  {
    $iteration++;
    chomp($date = `date "+%b %e %T"`);
    print ERROR "$date Error: $local_error SAN pathing problems found.  See /var/adm/ov-sancheck.log for details.\n";
    print "Error iteration $iteration occured.\n";
    open ACK, ">>$ack_file";
    foreach (@local_bad_luns)
    {
      print ACK "$_\n";
    }
    close ACK;
    chomp($date = `date "+%m-%d-%y.%T"`);
    $savelog = "$logfile.$date";
    close LOG;
    copy($logfile,$savelog);
  } elsif ( ($local_error > 0) && ($iteration != 1) && ( ! defined($more_bad[0]) ) )
  {
    if ( $iteration_error == 1 )
    {
      chomp($date = `date "+%b %e %T"`);
      print ERROR "$date Error: Repeat Alert: $local_error SAN pathing problems found.  See /var/adm/ov-sancheck.log for details.\n";
      print "REMINDER NOTE: This system has had a failure for more than two weeks since the last alert was generated.\nPlease check for other open tickets in HPSM.\n";
      $iteration = 2;
    }
    $iteration++;
    print "Error iteration $iteration occured.\n";
  } elsif ( ($local_error > 0) && ($iteration > 1) && ( defined($more_bad[0]) ))
  {
    $iteration++;
    chomp($date = `date "+%b %e %T"`);
    print ERROR "$date Error: $local_error SAN pathing problems found.  See /var/adm/ov-sancheck.log for details.\n";
    print "Error iteration $iteration occured.\n";
    open ACK, ">>$ack_file";
    foreach (@more_bad)
    {
      print ACK "$_\n";
    }
    close ACK;
    chomp($date = `date "+%m-%d-%y"`);
    $savelog = "$logfile.$date";
    close LOG;
    copy($logfile,$savelog);
  } elsif ( ($local_error == 0) && (-e $ack_file) )
  {
    chomp($date = `date "+%b %e %T"`);
    print "No problems found.  Removing ack file.\n";
    print ERROR "$date Error Condition cleared.\n";
    unlink "$ack_file";
  }
}

sub Remediate {
  local ($flavor, $os) = @_;
  if ($flavor eq "hdlm")
  {
    if ($os eq "AIX")
    {
      $dlmpath = "/usr/DynamicLinkManager/bin";
      $dlm_version = `$dlmpath/dlnkmgr view -sys |grep "HDLM Version"`;
      return if ($dlm_version =~ /05-9|06-/);
    } else
    {
      $dlmpath = "/opt/DynamicLinkManager/bin";
    }
    @pathids = `$dlmpath/dlnkmgr view -path | grep Offline`;
    foreach (@pathids)
    {
      chomp;
      s/^(\d+)\s+.+/\1/;
      system "$dlmpath/dlnkmgr offline -pathid $_ -s >/dev/null 2>&1";
      sleep 1;
      system "$dlmpath/dlnkmgr online -pathid $_ -s >/dev/null 2>&1";
    }
    $recheck_pathids = `$dlmpath/dlnkmgr view -path |grep Offline`;
    if ( defined($recheck_pathids) )
    {
      $return = 1;
    } else
    {
      $return = 0;
    }
  } elsif ($flavor eq "vxdmp")
  {
  } elsif ($flavor eq "emc")
  {
  } elsif ($flavor eq "shark")
  {
  } elsif ($flavor eq "mpio")
  {
  } elsif ($flavor eq "mpxio")
  {
  }
}

