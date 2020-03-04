#!/usr/bin/ksh

# unixinfo:
# Purpose: system information gathering
#
# How to use it:
#  Save this file as /tmp/UNIXinfo.txt then run "ksh /tmp/UNIXinfo.txt" as root
#  This script has been tested on AIX, Solaris or Redhat Linux systems.
#
# Output:
#  Using ftp, the output was sent to teller directly.
#
# Author: Wei Wu
# Date:   5/24/06
#
# modification:
#   WW 5/24/06 init for AIX and Solaris
#   WW 1/29/07 add for Linux
#   DG 4/9/07  add exports.
#
# Warning: Do not alter this file.
#

AWK="/usr/bin/awk"
HOST="`hostname | $AWK -F'.' '{print tolower($1)}'`"
ECHO="echo"

sendto="randy_lindberg@uhc.com"
_log_write() {
  set +x
  echo
  # echo "$*"
  set -x
}

_gather_aix_info()
{
  exec > /tmp/UNIXinfo.$(uname -n)
  exec 2>&1
  /usr/bin/banner $HOST
  _log_write "======================= System Information ============="

  set -x
  uname -a
  hostname
  uname -m
  echo "model and type"
  uname -M
  echo "serial number"
  uname -m | cut -c4-8
  bootinfo -K
  oslevel -r
  instfix -i|grep ML

  # check capactiy entitlement (or entitled capacity)
  _log_write "======================= LPAR Information ============="
  if [[ -x /usr/bin/lparstat ]] 
  then
    lparstat -i
  fi

  # check network
  _log_write "======================= Network Information ============="
  ifconfig -a
  _log_write "======================= netstat -rn ============="
  netstat -rn
  _log_write "======================= netstat -a =============="
  netstat -a
  _log_write "======================= netstat -i =============="
  netstat -i
  _log_write "======================= no values ==============="
  no -a|egrep 'rfc1323|tcp_sendspace|tcp_recvspace'

  _log_write "======================= /etc/hosts =============="
  cat /etc/hosts
  _log_write "======================= /etc/filesystems ========"
  cat /etc/filesystems
  _log_write "======================= /etc/exports ============"
  cat /etc/exports
  _log_write "======= directories exports to NFS clients ======"
  exportfs
  _log_write "======= Name resolution information ============="
  cat /etc/resolv.conf

  _log_write "======================= Volume Information ============="
  _log_write "====== List all defined volume groups ========"
  lsvg
  _log_write "====== List only the active volume groups ===="
  lsvg -o
  _log_write "==== Display information about all varied-on VGs ===="
  lsvg -o|lsvg -i
  _log_write "==== List info regarding physical volumes on all active VGs ======"
  lsvg -o|lsvg -ip
  _log_write "==== List info regarding logical volumes on all active VGs ======="
  lsvg -o|lsvg -il
  lsvg -o|lsvg -il|egrep -v ':|LV NAME'|awk '{print $1}' | xargs -n 1 lslv
  _log_write "====== List all paging space info ==========="
  lsps -a
  _log_write "====== List every known physical volume in the system ==="
  lspv
  _log_write "====== Display filesystem statistics in unit of 1k ======"
  df -k
  _log_write "====== Sum up total/free/used filesystem statistics not counting NFS ======"
  df -k | awk '!/:/{t+=$2;f+=$3}END{print "Filesystems Total/Free/Used(in GB)", t/1024/1024, f/1024/1024, (t-f)/1024/1024}'
  _log_write "======================= lsjfs ==============="
  lsjfs
  _log_write "======================= lsjfs2 =============="
  lsjfs2
  _log_write "====== Display all mounted filesystems and the options =="
  mount


  _log_write "======================= Device Information ============="
  if [[ -x /usr/bin/datapath ]] 
  then
    _log_write "====== The next two commands are related to SHARKS ======"
    _log_write "====== display fibre channel adapter and disk datapath status ===="
    datapath query adapter
    datapath query device
  fi
  _log_write "====== Display configured adapters ======================"
  lsdev -Cc adapter
  _log_write "====== List all disks available via fibre channel adapters ==="
  lsdev -Cc disk -s fcp
  _log_write "====== List all disks available via Data Path Optimizer Pseudo Device Driver ==="
  lsdev -Cc disk -s dpo
  _log_write "====== Display configured fiber channel adapters ========"
  lsdev -C|grep fcs
  _log_write "====== Display detail configuration ====================="
  lscfg -v
  _log_write "====== size of configured memory ========================"
  lsattr -El mem0
  _log_write "====== list configured processors ======================="
  lsdev -Cc processor
  _log_write "====== Another view to see system config using prtconf =="
  prtconf
  _log_write "====== Displays dynamically reconfigurable pci slots ========"
  lsslot -c pci

  _log_write "======================= Begin HACMP check  =============="
  if [[ -f /usr/es/sbin/cluster/utilities/cltopinfo ]]; then
    _log_write "-------- Show cluster name and security mode"
    /usr/es/sbin/cluster/utilities/cltopinfo -c
    _log_write "-------- Show all interfaces configured in the cluster"
    /usr/es/sbin/cluster/utilities/cltopinfo -i
    _log_write "-------- Show all the nodes configured in the cluster"
    /usr/es/sbin/cluster/utilities/cltopinfo -n
    _log_write "-------- Show all the networks configured in the cluster"
    /usr/es/sbin/cluster/utilities/cltopinfo -w
    _log_write "-------- Show Cluster App Startup shutdown script location"
    /usr/es/sbin/cluster/utilities/cllsserv
    _log_write "-------- Show Cluster Resource"
    /usr/es/sbin/cluster/utilities/clshowres
    _log_write "-------- List the app startup and shutdown scripts"
    for appscript in $(/usr/es/sbin/cluster/utilities/cllsserv); do
      if [[ -f $appscript ]]; then
         _log_write "------------- $appscript -------------"
         cat $appscript
      fi
    done
  elif [[ -f /usr/sbin/cluster/utilities/clshowsrv ]]; then
    /usr/sbin/cluster/utilities/clshowsrv -a
    _log_write "-------- Show cluster Topology"
    /usr/sbin/cluster/utilities/cllscf
    _log_write "-------- Show Cluster Definitions"
    /usr/sbin/cluster/utilities/cllsclstr
    _log_write "-------- Show Cluster Resource"
    /usr/sbin/cluster/utilities/clshowres
    _log_write "-------- Show Cluster App Startup shutdown script location"
    /usr/sbin/cluster/utilities/cllsserv
    _log_write "-------- List the app startup and shutdown scripts"
    for appscript in $(/usr/es/sbin/cluster/utilities/cllsserv); do
      if [[ -f $appscript ]]; then
         _log_write "------------- $appscript -------------"
         cat $appscript
      fi
    done
  else
    _log_write "======================= NO HACMP ======================"
  fi
  _log_write "======================= END HACMP check  =============="

  _log_write "======================= Server Start-Up Setup ==========="
  cat /etc/inittab
  _log_write "======================= /etc/inetd.conf ================="
  egrep -v '^$|^#' /etc/inetd.conf
  if [[ -f /etc/rc.local ]]; then
     cat /etc/rc.local
  fi
  _log_write "====== List running active subsystems ==================="
  lssrc -a | grep active

  _log_write "======================= Top 10 most-used users =========="
  last -10000 | awk '{print $1}' | sort | uniq -c | sort -nr | head

  _log_write "======================= Cronjobs ========================"
  for i in /var/spool/cron/crontabs/*; do echo "\n$i"; egrep -v '^$|^#' $i; done

  if [[ -x /usr/DynamicLinkManager/bin/dlnkmgr ]]; then
    _log_write "============= Hitachi Drive Status ======================"
    /usr/DynamicLinkManager/bin/dlnkmgr view -path

    _log_write "============= Hitachi Drive Mapping to hdisk ============"
    /usr/DynamicLinkManager/bin/dlnkmgr view -lu

    _log_write "============= Hitachi software configuration ============"
    /usr/DynamicLinkManger/bin/dlnkmgr view -sys
  fi

  if (( `ps -ef|grep -c ora_smon` > 1 )); then
    _log_write "====== List current running Oracle smon processes ======"
    ps -ef | grep smon | grep -v grep

    _log_write "========= Get guessitimate SGA size in byte ============"
    ipcs -mb
  fi

  _log_write "======================= Processes Listing =============="
  ps -ef

  if (( `ps -ef | grep -c java` > 1 )); then
    _log_write "===================== Java Processes by Kbyte ========"
    ps -e -o vsz,args|grep java|grep -v grep
  fi
}


_gather_sun_info()
{
  exec > /tmp/UNIXinfo.$(uname -n)
  exec 2>&1
  AWK="/usr/xpg4/bin/awk"
  GREP="/usr/xpg4/bin/grep"
  DIFF=0
  METADB="/usr/sbin/metadb"
  METASTAT="/usr/sbin/metastat"
  export LD_LIBRARY_PATH="/usr/lib:/usr/openwin/lib:$LD_LIBRARY_PATH"
  PGREP="/usr/bin/pgrep"
  /usr/bin/banner $HOST
  _log_write "======================= System Information ============="
  set -x
  uname -a
  hostname
  showrev
  # showrev -p

  # check network
  _log_write "======================= Network Information ============="
  _log_write "======================= ifconfig -a ============="
  /usr/sbin/ifconfig -a
  _log_write "======================= netstat -rn ============="
  netstat -rn
  _log_write "======================= netstat -a ============="
  netstat -a
  _log_write "======================= netstat -i ============="
  netstat -i

  _log_write "============ Begin Read clusters,vfstab,resolv.conf,md.conf,exports ==="

  for i in /etc/clusters /etc/serialports /etc/hosts /etc/vfstab /etc/resolv.conf /kernel/drv/md.conf /etc/exports; do
    if [[ -f $i ]]; then
      _log_write "File $i exists, the contents is listed below"
      cat $i
    else
      _log_write "File $i does not exist"
    fi
  done
  _log_write "============ End Read clusters,vfstab,resolv.conf,md.conf,exports ==="

  _log_write "============ BEGIN DISK Info ==="
  if [[ -f /usr/sbin/luxadm ]]; then
    _log_write "display basic information about attached arrays"
    /usr/sbin/luxadm probe
    _log_write "display the firmware revision of any Fibre-Channel HBA cards"
    /usr/sbin/luxadm fcode_download -p
    _log_write "display info on any Fibre-Channel HBA cards"
    /usr/sbin/luxadm qlgc
  fi
  _log_write "============ End DISK Info ==="

  _log_write "======================= df -k ============="
  df -k

  _log_write "======================= list current mounting options ========"
  mount

  # print system configuration
  _log_write "======================= print system configuration ============"
  /usr/sbin/prtconf -v

  # display more hardware information
  _log_write "======================= more hardware information ============"
  /usr/platform/`uname -m`/sbin/prtdiag -v

  # Sun Clusters
  _log_write "======================= BEGIN Sun Cluster Info ============"

  if [[ -x /usr/cluster/bin/scstat ]] 
  then
    _log_write "This is a Sun Cluster 3.x Node"
    export PATH=$PATH:/usr/cluster/bin:/etc/vx/bin:/opt/VRTSvmsa/bin
    _log_write "show the DID numbers assigned to the disks in the cluster"
    scdidadm -L
    /usr/cluster/bin/scstat
    _log_write "list the cluster configuation information"
    /usr/cluster/bin/scconf -p
    _log_write "list NAFO Group Configuration"
    pnmset -p
    _log_write "display all the SC config"
    /usr/cluster/bin/scconf -pvv
    /usr/cluster/bin/scrgadm -pvv
  elif [[ -x /opt/SUNWcluster/bin/hastat ]]
  then
    _log_write "This is a Sun Cluster 2.x Node"
    /opt/SUNWcluster/bin/hastat
    CLUS="`/opt/SUNWcluster/bin/hastat | grep 'LIST OF NODES' | awk '{print $6}' | sed 's/<//' | sed 's/>//'`"
    /opt/SUNWcluster/bin/scconf $CLUS -p
  else
    _log_write "This is not a Sun Cluster Node"
  fi
  _log_write "======================= END Sun Cluster Info ============"

  # if Veritas Volume Manager is in use
  if [ ! "`$PGREP vxconfigd`" = "" ]
  then
    _log_write "======================= BEGIN Veritas VM Info ============"

    _log_write "display a brief summary of disk groups"
    vxdg list

    _log_write "check disk status"
    vxdisk list

    _log_write "display detailed configuration information"
    vxprint -ht

    _log_write "======================= End Veritas VM Info ============"
  elif [ ! "`$PGREP mdmonitordb`" = "" ]
    then

      # if DiskSuite is in use
      _log_write "======================= show DiskSuite information ====="
      $METASTAT 
    else
      /usr/bin/banner "Raw Disk"
      /usr/sbin/df -k | $GREP -v -e "^Filesystem" -e "Totals" | \
        $AWK '{print $1}' | sort -u -k1.10,1.15 | \
        xargs -L1 -t prtvtoc -h > $OFILE2 2>&1
  fi

  _log_write "======================= list all configurable hardware information"
  cfgadm -al

  _log_write "======================= list all the disks"
  /usr/bin/echo "" | /usr/sbin/format
 ##  echo|format

  _log_write "======================= vxdmpadm listctlr all =========="
  vxdmpadm listctlr all

  _log_write "======================= Server Start-Up Setup ==========="
  cat /etc/inittab
  egrep -v '^$|^#' /etc/inetd.conf
  ls /etc/rc3.d
  if [[ -f /etc/rc.local ]]; then
     cat /etc/rc.local
  fi

  _log_write "======================= Top 10 most-used users =========="
  last -10000 | awk '{print $1}' | sort | uniq -c | sort -nr | head

  _log_write "======================= Cronjobs ========================"
  for i in /var/spool/cron/crontabs/*; do echo "\n$i"; egrep -v '^$|^#' $i; done

  if [[ -x /opt/DynamicLinkManager/bin/dlnkmgr ]]; then
    _log_write "============= Hitachi Drive Status ======================"
    /opt/DynamicLinkManager/bin/dlnkmgr view -path

    _log_write "============= Hitachi Drive Mapping to hdisk ============"
    /opt/DynamicLinkManager/bin/dlnkmgr view -lu

    _log_write "============= Hitachi software configuration ============"
    /opt/DynamicLinkManger/bin/dlnkmgr view -sys
  fi

  if (( `ps -ef|grep -c ora_smon` > 1 )); then
    _log_write "======================= Oracle ========================="
    ps -ef | grep smon | grep -v grep
    ipcs -mb | egrep -e 'oracle|Shared|shmid'
  fi

  _log_write "======================= Processes Listing =============="
  /usr/ucb/bin/ps augxww

  _log_write "======================= Shared Memory =============="
  /bin/ipcs -mb
}


_gather_linux_info()
{
  exec > /tmp/UNIXinfo.$(uname -n)
  exec 2>&1
  echo $HOST
  _log_write "======================= System Information ============="

  set -x
  uname -a
  cat /proc/version
  cat /etc/redhat-release
  hostname
  grep MemTotal /proc/meminfo
  _log_write "Note: Hyper-threading likely is on. 1 cpu appears to be 2"
  grep "model name" /proc/cpuinfo | uniq -c | sed 's/model name//'
  mount | column -t
  cat /proc/partitions
  _log_write "======================= PCI Information ================"
  lspci -tv
  lsusb -tv

  # check network
  _log_write "======================= Network Configuration =========="
  netstat -in|awk '/eth/{print $1}'|cut -d: -f1|sort -u|xargs -n 1 ethtool
  /sbin/ifconfig -a
  route
  cat /etc/sysconfig/network
  cat /etc/hosts
  cat /etc/nsswitch.conf | egrep -v '^#|^$'
  cat /etc/resolv.conf
  cat /etc/exports
  exportfs

  _log_write "======================= Top 10 most-used users =========="
  last -10000 | awk '{print $1}' | sort | uniq -c | sort -nr | head

  _log_write "======================= Swap Space ====================="
  cat /proc/swaps
  _log_write "=========== Free and used memory in the system ========="
  free
  _log_write "======================= Memory Info ===================="
  cat /proc/meminfo

  _log_write "============== Summary Logical Volumes Management ======"
  /usr/sbin/vgdisplay -A -s
  /usr/sbin/pvdisplay -s

  _log_write "============== Detail Logical Volumes Management ======="
  /usr/sbin/vgdisplay -A
  /usr/sbin/pvdisplay
  /usr/sbin/lvdisplay

  _log_write "======================= Partitions and Filesystems ====="
  fdisk -l
  df -h
  cat /etc/fstab
  cat /proc/mounts

  _log_write "======================= Kernel Parameters =============="
  cat /etc/sysctl.conf
  # sysctl -a

  _log_write "======================= Boot Configuration ============"
  cat /boot/grub/grub.conf
  _log_write "======================= List loaded modules ==========="
  lsmod
  _log_write "======= Query runlevel info for system services ======="
  chkconfig --list|egrep 'on|xinetd'

  _log_write "======================= Device Information ============="
  cat /proc/pci

  _log_write "======================= Processors ====================="
  cat /proc/cpuinfo

  # _log_write "=======================  Installed Software =========="
  # rpm -qa
  ## List all packages by installed size (Bytes) on rpm distros
  # rpm -q -a --qf '%10{SIZE}\t%{NAME}\n' | sort -k1,1n

  if (( `ps -ef|grep -c ora_smon` > 1 )); then
    _log_write "======================= Oracle ========================="
    ps -ef | grep smon | grep -v grep
    ipcs -m | egrep -e 'oracle|Shared|shmid'
  fi

  _log_write "========= Process Hierachy ============================="
  ps -e -o pid,args --forest

  _log_write "========= Process by % cpu usage ======================="
  ps -ew -o pcpu,cpu,nice,state,cputime,args --sort pcpu | sed '/^ 0.0 /d'

  _log_write "========= Processes by memory usage (top 20) ==========="
  ps -ew -orss=,args= | sort -u -b -k1,1rn | pr -TW$COLUMNS | head -20

  _log_write "========= List Active Connections to/from system ======="
  netstat -tup | awk '{print substr($4,0,index($4,":")-1)," ",substr($5,0,index($5,":")-1)," ",$6}' | sort | uniq -c

  if [[ -x /usr/bin/pstree ]]; then
    _log_write "========= List Java or Weblogic Processes ============"
    pstree -al|egrep 'wladmin|start|java|weblogic'|egrep -v 'egrep|pstree| start |-start '
  fi
}


# print "Please send file /tmp/UNIXinfo.$(uname -n) to $sendto."
if [[ $(uname -s) = AIX ]]; then
  _gather_aix_info
elif [[ $(uname -s) = SunOS ]]; then
  _gather_sun_info
elif [[ $(uname -s) = Linux ]]; then
  _gather_linux_info
else
  print this script needs to be run on AIX, SunOS, or Linux systems only
  exit
fi

cat /tmp/UNIXinfo.$(uname -n) | mailx -s "UNIXinfo for `uname -n`" $sendto

un=$(uname -n)
ftp -n 10.121.20.78 <<EOF
user test abc124
put /tmp/UNIXinfo.$un sysinfo/UNIXinfo.$un
quit
EOF
