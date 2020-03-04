#!/usr/bin/ksh
#DO NOT EDIT WITHOUT RAJ'S PERMISSION!!!
#Version 3 9/19/08
#Modified for VIO automation buildout
#rajesh_singh@uhc.com
#
# Setup RR frames with 4 vios
#
#
#This script was made to automate the basice things we need to do
#to prepare a new LPAR before we run the nima8001:/uht_packages/AIX53/AIX53_build_script.txt
#To date, it will:
#   Setup PATH in /etc/environment
#   Setup Name Services
#   Remove ".uhc.com" from /etc/hosts file
#   Setup `hostname`.bu IP address on en1 and modify /etc/hosts
#   Configure PV's for MPIO
#   Add the C30 or C130 disk to rootvg
#   Add the C60 or C160 disks to viovg
#   Setup root's password to be the same as on nima8001
#   Setup zuhl, zig, mgtp8013, mgtp8014, apsp0530's SSH keys
#   Setup SSH
#   Setup SSH Keys to log into nima8001 without a password
#   Update AIX 5.3.5
#   Run the addbox.sh script on zuhl 
#   Copy nima8001:/uht_packages/AIX53/AIX53_build_script.txt to /tmp
#   Copy nima8001:/uht_packages/AIX53/os-diag.ksh to /tmp

#Check if SSH was installed the by NIM install
function Check_for_SSH {
   #Modified 2008/10/09 by Roger Brown to handle the new openssh installs
   if [[ -s /usr/local/bin/ssh ]]; then
        SSHCMD=/usr/local/bin/ssh
        SCPCMD=/usr/local/bin/scp
   elif [[ -s /usr/bin/ssh ]]; then
        SSHCMD=/usr/bin/ssh
        SCPCMD=/usr/bin/scp
   else
      #Get openssh from the nim server
      nimclient -o cust -a filesets=openssh.base openssh.license openssh.man.en_US openssh.msg.EN_US openssl.base openssl.license openssl.man.en_US -a lpp_source=lpp_source53_tl07sp4 1>/dev/null 2>/dev/null
   fi
   #Check again
   if [[ -s /usr/local/bin/ssh ]]; then
	SSH_FOUND_RESULTS="/usr/local/bin/ssh"
   elif [[ -s /usr/bin/ssh ]]; then
	SSH_FOUND_RESULTS="/usr/bin/ssh"
   else
	SSH_FOUND_RESULTS="/usr/local/bin/ssh-keygen not found"
   fi
   if [[ $SSH_FOUND_RESULTS == "/usr/local/bin/ssh-keygen not found" ]] ; then
      echo
      echo "   OPENSSH was not installed by NIM!"
      echo "   Please run the following commands to get the OPENSSH package from the host (not the NIM server) and re-execute this script:"
      echo
      echo "      ftp nima8001" 
      echo "          (login as root)"
      echo "          cd /uht_packages/OPENSSH/current_release/"
      echo "          lcd /tmp"
      echo "          bin"
      echo "          prompt"
      echo "          mget openssh-3.*aix5*.bff.Z openssh.install"
      echo "          quit"
      echo "      chmod +x /tmp/openssh.install;cd /tmp;/tmp/openssh.install"
      exit
   fi
}

#Setup PATH in /etc/environment
function Setup_PATH {
   PATH_RESULTS=`grep "/usr/local/bin" /etc/environment`
   if [[ $PATH_RESULTS == "" ]] ; then
      echo "   Setting up PATH variables in /etc/environment"
      date=`date +%m%d%y%H%M%S`
      cp /etc/environment /etc/environment.$date
      PATH1=`grep ^PATH /etc/environment`
      PATH2=":/usr/local/bin"
      sed s/"^PATH.*"// /etc/environment.$date > /etc/environment
      echo "$PATH1$PATH2" >> /etc/environment
   fi
}


#Setup Name Services
function Setup_NS {
   #Someone added the below line without fully testing it.
   #Removing it because it returns a null string causing the
   #ifconfig to bomb. - Raj
   #GET_INT=$(netstat -i | grep "$(hostname)\." | awk '{print $1}')

   INMN=n
   echo "   Setting up Name Services"

   #Unfortunately, someone added the below "if" clause and didn't
   #test it out. I'm removing it due to bad scripting - Raj
   #if [[ `ifconfig ${GET_INT} |head -2|tail -1|awk 'FS="." {print $2}'` < 118 ]]; then
   #   INMN=y
   #fi

   #Here is the original
   if [[ `ifconfig en0 2>/dev/null|head -2|tail -1|awk 'FS="." {print $2}'` < 118 ]]; then
      INMN=y
   fi

   if [[ -n $INMN && $INMN = 'y' ]]; then
      echo "nameserver\t10.7.136.103" > /etc/resolv.conf
      echo "nameserver\t10.1.112.104" >> /etc/resolv.conf
      echo "domain  uhc.com" >> /etc/resolv.conf
   else
      echo "nameserver\t10.1.112.104" > /etc/resolv.conf
      echo "nameserver\t10.7.136.103" >> /etc/resolv.conf
      echo "domain  uhc.com" >> /etc/resolv.conf
   fi
}


#Remove ".uhc.com" from /etc/hosts file
function Remove_UHC_COM {
   UHCCOM=`grep "\`hostname\`.uhc.com" /etc/hosts`
   if [[ $UHCCOM != "" ]] ; then 
      echo "   Removing ".uhc.com" from hostname in /etc/hosts"
      date=`date +%m%d%y%H%M%S`
      cp /etc/hosts /etc/hosts.$date;sed s/`hostname`.uhc.com/`hostname`/g /etc/hosts.$date > /etc/hosts
   fi
}


#Setup `hostname`.bu IP address on en1 and modify /etc/hosts
#Modified by Harlan
function Setup_Hostnamebu {
   echo "   Adding \"bu\" to hostname backup address in /etc/hosts"
   BUIP=`nslookup \`hostname 10.117.7.30|awk 'FS="." {print $1}'\`bu|tail -2|awk '{print $2}'|grep -v 10.117.7.30`
   lsdev -C | grep ent5 > /dev/null
   if [[ $? -eq 0 ]] then
      EN=en5
   else
      EN=en1
   fi
   if [[ $BUIP = 10.1.112.104 || $BUIP = 10.7.136.103 ]]; then
      echo "*** Cannot find backup IP in Name Server ***"
      echo "*** Please manually enter IP for en1     ***"
   elif [[ $BUIP != `ifconfig ${EN} |tail -2|head -1|awk '{print $2}'` ]]; then
      echo "   Assigning $BUIP to interface ${EN}"
      lsdev -C | grep ent5 > /dev/null
        chdev -l $EN -a netaddr=$BUIP -a netmask=255.255.252.0 -a state=up 1>/dev/null
      date=`date +%m%d%y%H%M%S`
      cp /etc/hosts /etc/hosts.$date
      sed s/"$BUIP.*`hostname`"/"$BUIP   `hostname`bu"/g /etc/hosts.$date > /etc/hosts
   fi
}

#Configure PV's & FSCSI for MPIO
function Configure_PV_FSCSI_MPIO {
   echo "   Configure PV's for MPIO"
   lpar_id=`lparstat -i | grep "Partition Number" | awk 'FS=":" {print $2}'`
   MOD=`expr $lpar_id % 2`

   for pv in `lspv|awk '{print $1}'`
   do
       chdev -l $pv -a hcheck_interval=30 -a queue_depth=8  -P 1>/dev/null 2>/dev/null

   #Setup MPIO prioritization
   X=0
   for p in $(lspath -l $pv | grep vscsi | awk '{print $3}')
       do
       export VSCSI${X}=$(echo $p)
       X=$(expr $X + 1)
   done
       #For lpar_id's that are odd, direct their IO to the Secondary VIO
       if [ "$MOD" != "0" ] ; then
           if [[ $(echo $VSCSI0 | cut -f2 -d "i") -lt $(echo $VSCSI1 | cut -f2 -d "i") ]]
           then
             if [ $VSCSI0 ] ; then chpath -l $pv -p $VSCSI0 -a priority=1 1>/dev/null 2>/dev/null
             fi
             if [ $VSCSI1 ] ; then chpath -l $pv -p $VSCSI1 -a priority=2 1>/dev/null 2>/dev/null
             fi
           else
             if [ $VSCSI1 ] ; then chpath -l $pv -p $VSCSI1 -a priority=1 1>/dev/null 2>/dev/null
             fi
             if [ $VSCSI0 ] ; then chpath -l $pv -p $VSCSI0 -a priority=2 1>/dev/null 2>/dev/null
             fi 
         fi
       else
           if [[ $(echo $VSCSI0 | cut -f2 -d "i") -lt $(echo $VSCSI1 | cut -f2 -d "i") ]] 
           then
             if [ $VSCSI1 ] ; then chpath -l $pv -p $VSCSI1 -a priority=1 1>/dev/null 2>/dev/null
             fi
             if [ $VSCSI0 ] ; then chpath -l $pv -p $VSCSI0 -a priority=2 1>/dev/null 2>/dev/null
             fi
           else
             if [ $VSCSI0 ] ; then chpath -l $pv -p $VSCSI0 -a priority=1 1>/dev/null 2>/dev/null
             fi
             if [ $VSCSI1 ] ; then chpath -l $pv -p $VSCSI1 -a priority=2 1>/dev/null 2>/dev/null
             fi
         fi
          
       fi
done
}


#Add the C30 or C130 disk to rootvg
function C30_C130 {
   #Check system model if it is a 510
   #If so, don't extend rootvg to 2nd hdisk. Dave's script will not work.
   #Dave's script will do that for us.
   SYSTEM_MODEL=`prtconf|grep "System Model:"|awk 'FS="," {print $2}'`
   if [ $SYSTEM_MODEL == "9110-510" ] ; then 
      return 
   fi 
   echo "   Adding the C30 or C130 disks to rootvg"
   for pv in `lspv|awk '{print $1}'` 
   do 
       ROOTVG=`lspv $pv 2>/dev/null | grep rootvg` 
       ROOTC30=`lscfg -vl $pv|egrep "\-C30\-|\-C130\-"|awk '{print \$1}'`
       if [[ -n $ROOTC30 && $ROOTVG == "" ]] ; then 
          extendvg -f rootvg $ROOTC30 1>/dev/null 2>/dev/null
       fi                                                  
   done                                                    
}


#Add the C60 or C160 disks to viovg
function C60_C160 {
   #Check system model if it is a 510
   #If so, do nothing. This disk will be used as rootvg and mirrored to it.
   SYSTEM_MODEL=`prtconf|grep "System Model:"|awk 'FS="," {print $2}'`
   if [ $SYSTEM_MODEL == "9110-510" ] ; then                       
      return                                                       
   fi                                                              
   echo "   Adding the C60 or C160 disks to viovg"
   SANVG="viovg"
   FIRST_TIME="TRUE"
   for pv in `lspv|awk '{print $1}'`
   do
       SANVG_CHECK=`lspv $pv 2>/dev/null | grep $SANVG`
       if [[ -n $SANVG_CHECK ]] ; then FIRST_TIME="FALSE"
       fi
       ROOTC60=`lscfg -vl $pv|egrep "\-C60\-|\-C160\-"|awk '{print \$1}'`
       ERROR=""
       if [[ -n $ROOTC60 && $FIRST_TIME == "TRUE" ]] ; then
          mkvg -f -B -y $SANVG -s 64 $ROOTC60 1>/dev/null 2>/dev/null
          FIRST_TIME="FALSE"
       elif [[ -n $ROOTC60 && $FIRST_TIME == "FALSE" ]] ; then
            extendvg -f $SANVG $ROOTC60 2>/dev/null
       fi
   done
}


#Setup SSH for Client LPARS
function Setup_SSH {
   HOSTNAME=`hostname`
   if ! [[ -s /.ssh/id_rsa && -s /.ssh/id_rsa.pub ]] ; then
      echo "   Setting up SSH"
      mkdir -p /.ssh
      export PATH=$PATH:/usr/local/bin:.;ssh-keygen -b 1024 -N "" -t rsa -f /.ssh/id_rsa 1>/dev/null
   fi
   CKSUM=`cksum /etc/security/passwd`
   if [[ $CKSUM == "310027972 190 /etc/security/passwd" ]] ; then

      #Use nima8001's private key to get into nima8001 without a password
      nima8001_ssh_privkey="-----BEGIN DSA PRIVATE KEY-----\nMIIBvAIBAAKBgQDgb7HiLxA8sQLbEiCLJqtSHFulaRNF8wQksYDHLwLPgsUG7zn3\namSvlNBdUnNZuWd14UrzYNMX9b8hgxuo0bKrwK9Euf0i5OkzKu1FXF674cpO+lOa\nNLkS3VpusZDuE+UJoXLqohXV8/EKfgfH4eFsvbTGTG3u/wEvI8ZNf1f8GQIVAIB/\nJf4utsd+wp7wN96VGQRoSHydAoGBAIAwUC3VQbMkD2Lvhe5R7uCeSigXAdf1wI7B\nGk95YiGeuap9t1ARdX13v6IpMOjp3JuJjcqeRiLcevgMmtC4dLvl8HnEQU6Y+rfr\nMY+VTooBU/hDmUNFb27GEbhZKzsVsjgugQUQIMsQrF0oSqKgOC5n7Zwx1WXHcZWY\n6vWf22g0AoGBALaCHxjec7tWsx0ZITgrdZi7LlpGjSjjHg4t9ArYLA5mi9Af4mdQ\nwQMpSuMkPBXjjGGViWYq+lX+DaOLWn8Y2M9X7pc58AGgnKBJEHd96Oy4hkG6nGAB\n1GCJZpIsvu4byW4BbTRXK6yy2URoDmFJxpqZy84IGPkW2vJ2e3Fs6HEfAhQ0UKt0\nnY7+WgvI2nSN+5wGU+H/pQ==\n-----END DSA PRIVATE KEY-----"

      nima8001_ssh_pubkey="ssh-dss AAAAB3NzaC1kc3MAAACBAOBvseIvEDyxAtsSIIsmq1IcW6VpE0XzBCSxgMcvAs+CxQbvOfdqZK+U0F1Sc1m5Z3XhSvNg0xf1vyGDG6jRsqvAr0S5/SLk6TMq7UVcXrvhyk76U5o0uRLdWm6xkO4T5QmhcuqiFdXz8Qp+B8fh4Wy9tMZMbe7/AS8jxk1/V/wZAAAAFQCAfyX+LrbHfsKe8DfelRkEaEh8nQAAAIEAgDBQLdVBsyQPYu+F7lHu4J5KKBcB1/XAjsEaT3liIZ65qn23UBF1fXe/oikw6Oncm4mNyp5GItx6+Aya0Lh0u+XwecRBTpj6t+sxj5VOigFT+EOZQ0VvbsYRuFkrOxWyOC6BBRAgyxCsXShKoqA4LmftnDHVZcdxlZjq9Z/baDQAAACBALaCHxjec7tWsx0ZITgrdZi7LlpGjSjjHg4t9ArYLA5mi9Af4mdQwQMpSuMkPBXjjGGViWYq+lX+DaOLWn8Y2M9X7pc58AGgnKBJEHd96Oy4hkG6nGAB1GCJZpIsvu4byW4BbTRXK6yy2URoDmFJxpqZy84IGPkW2vJ2e3Fs6HEf root@nima8001"

      nima8001_known_hosts="nima8001,10.115.176.60 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA0oPwGKDpLr/R+tVCiUDbzFmnePjSwjemqgaK804MvgUftmBjoLXBtJLssWNOs0Eyv+9UA/E3mpTFVPAVU0nXuOAmNzsd6RKT7RxdHi7LrBQk/M1SkTkUu2GO9rPLHiGW/LtV6PId3nvMmJE0oyMlZ/raOttwLcZ9AJjtSa6cHFE="

      #Make nima8001 private SSH key LPAR's private key
      echo $nima8001_ssh_privkey > /.ssh/id_dsa
      chmod 600 /.ssh/id_dsa
      echo $nima8001_ssh_pubkey  > /.ssh/id_dsa.pub
      echo $nima8001_known_hosts > /.ssh/known_hosts

      #Get the latest root password from nima8001
      echo "   Setting up root password"
      date=`date +%m%d%y%H%M%S`
      cp /etc/security/passwd /etc/security/passwd.$date
      $SCPCMD -q nima8001:/etc/security/passwd /etc/security/passwd

      #Distribute LPAR's public key to nima8001
      EXISTINGKEYS=`$SSHCMD -q nima8001 "grep $HOSTNAME /.ssh/authorized_keys2"`
      CURRENTKEYS=`cat /.ssh/id_rsa.pub`
      if [[ $CURRENTKEYS != $EXISTINGKEYS ]] ; then
         echo "   Distributing `hostname`'s keys to nima8001"
         #Get the domain name
         DOMAIN=`cat /etc/resolv.conf|grep domain|awk '{print $2}'`

         #Replace the above with the "from" statement for security reasons.
           #Get the IP address of this server from DNS
                #Save the current hostname
                HOSTNAME=`hostname`
                HOSTNAME=`echo $HOSTNAME|sed s/.$DOMAIN//g`

                #Save the current IP address
                IP=`netstat -ni|grep en|grep -v link|head -1|awk '{print $4}'`

         #/usr/local/bin/ssh -q nima8001 "echo `cat /.ssh/id_rsa.pub` >> /.ssh/authorized_keys2"
         $SSHCMD -q nima8001 "echo from=\\\"$HOSTNAME,$HOSTNAME.$DOMAIN,$IP\\\" `cat /.ssh/id_rsa.pub` >> /.ssh/authorized_keys2"
      fi

      rm /.ssh/id_dsa /.ssh/id_dsa.pub
      #Create access for zig, zuhl, mgtp8013, mgtp8014 & apsp0530 to LPAR 
      echo "   Adding zig, zuhl, mgtp8013, mgtp8014 & apsp0530's keys to authorized_keys2"
      #echo "from=\"zuhl,zuhl.uhc.com,168.183.92.80,10.7.140.112,10.7.136.121\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA3qefRCnzXdVY6N9l3XPG4I179FQ/KSv1hlagcDHuceI8FTqhn6TTdHogRbKFLB0Sb8iVLmdn3P8FoYh4TriWHH3NCreeUcPTTV5PNh89e6wr9n6Du65NF9H/aaVVk7j+tsBY1h6sktlB/bBeKteCcLhASCKMgJvE8KE922QCmJ8= root@zuhl
#from=\"zig,zig.uhc.com,168.183.51.54\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAoKpXjjetR6Dl3+ytjt0MpvJsaRKJezr2Jz3e/3wJzCn7Opc3m6Vpl6hseZaJGigtu2c5UtYt1Z0KHd1Oey1nlCpSONE2UyDB7BFunN10IMEiGj6wA9ZRF/8N5a5Cey+iFO12SMC9PoGSCiK1wHfR/F5DQuuIz0H3xc+y09nGNrc= root@zig
#from=\"mgtp8013,mgtp8013.uhc.com,10.115.192.93\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAqOJK1OWz/CPgzoKj8PXYEcFYbZhKre3vLqbXRd6qxjxuPsS9A19TYujGobpPa4wyNsNEw2o5IW602O8rT03RRs/1COxed7Ef/fh8Ab0JTn6/9HQwzxh7SPn6MR4g/DTlA9h9gCQZUG9t05Ts5j/Za+ioX30YwtKcKmyFJAYRJaM= root@mgtp8013
#from=\"mgtp8014,mgtp8014.uhc.com,10.122.76.245 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA5O6B/k0wSTG/7Y/V2kHpOXGpm7zfsan7s1GFqqMr1+pQ0eAt01gyPxPjU/246x6uHmGTOJ5ra66t9j80CqNVmKLV6xFRXf0rvbDYsce8M3pn6XPruG8umssFWOL8VBcjfKX9hGcMva4baIfuYNLk0XhtmhzuctVpUjxCwslZ2zs= root@mgtp8014
#from=\"apsp0530,apsp0530.uhc.com,10.220.197.44\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA3zTcKxQY9kNczVQ0igawe9PKuD8ZJ8bEQiSq8sAMerC4tz0coApZgpVY3n6SJ4o1AQEp4wDp4tSPAYLfXZMIh4SLV8MloVkKWKJueSs3z8Gaipjc5QIM7wvqHdUQX78yxo2/ceSxLktTArBQ6RN+yJreoIj8tgLj+jfBOPPuO+8= root@apsp0530" >> /.ssh/authorized_keys2
      echo "from=\"zuhl,zuhl.uhc.com,168.183.92.80,10.7.140.112,10.7.136.121\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA3qefRCnzXdVY6N9l3XPG4I179FQ/KSv1hlagcDHuceI8FTqhn6TTdHogRbKFLB0Sb8iVLmdn3P8FoYh4TriWHH3NCreeUcPTTV5PNh89e6wr9n6Du65NF9H/aaVVk7j+tsBY1h6sktlB/bBeKteCcLhASCKMgJvE8KE922QCmJ8= root@zuhl
from=\"zig,zig.uhc.com,168.183.51.54\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAoKpXjjetR6Dl3+ytjt0MpvJsaRKJezr2Jz3e/3wJzCn7Opc3m6Vpl6hseZaJGigtu2c5UtYt1Z0KHd1Oey1nlCpSONE2UyDB7BFunN10IMEiGj6wA9ZRF/8N5a5Cey+iFO12SMC9PoGSCiK1wHfR/F5DQuuIz0H3xc+y09nGNrc= root@zig
from=\"mgtp8013,mgtp8013.uhc.com,10.115.192.93\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAqOJK1OWz/CPgzoKj8PXYEcFYbZhKre3vLqbXRd6qxjxuPsS9A19TYujGobpPa4wyNsNEw2o5IW602O8rT03RRs/1COxed7Ef/fh8Ab0JTn6/9HQwzxh7SPn6MR4g/DTlA9h9gCQZUG9t05Ts5j/Za+ioX30YwtKcKmyFJAYRJaM= root@mgtp8013
from=\"mgtp8014,mgtp8014.uhc.com,10.122.76.245\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA5O6B/k0wSTG/7Y/V2kHpOXGpm7zfsan7s1GFqqMr1+pQ0eAt01gyPxPjU/246x6uHmGTOJ5ra66t9j80CqNVmKLV6xFRXf0rvbDYsce8M3pn6XPruG8umssFWOL8VBcjfKX9hGcMva4baIfuYNLk0XhtmhzuctVpUjxCwslZ2zs= root@mgtp8014
from=\"apsp0530,apsp0530.uhc.com,10.220.197.44\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA3zTcKxQY9kNczVQ0igawe9PKuD8ZJ8bEQiSq8sAMerC4tz0coApZgpVY3n6SJ4o1AQEp4wDp4tSPAYLfXZMIh4SLV8MloVkKWKJueSs3z8Gaipjc5QIM7wvqHdUQX78yxo2/ceSxLktTArBQ6RN+yJreoIj8tgLj+jfBOPPuO+8= root@apsp0530" >> /.ssh/authorized_keys2
   fi

   # Start sshd daemon
   if [ -x /etc/rc.openssh ]; then
      echo "   Starting SSH daemon"
      sh /etc/rc.openssh start 1>/dev/null
   elif [[ -f /usr/bin/ssh ]]; then
      echo "   Starting SSH daemon"
      startsrc -s sshd
   fi

   #Add openssh to /etc/initab
   INITTAB_SSH=`lsitab openssh`
   if [[ $INITTAB_SSH == "" && -f /etc/rc.openssh ]] ; then
      echo "   Adding openssh to /etc/initab"
      mkitab "openssh:2:wait:/etc/rc.openssh start"
   fi

   #Change "PermitRootLogin yes" to "PermitRootLogin without-password" in /etc/ssh/sshd_config
   PERMITROOTLOGIN=`grep "PermitRootLogin yes" /etc/ssh/sshd_config`
   if [[ $PERMITROOTLOGIN != "" ]] ; then
      echo "   Changing PermitRootLogin \"yes\" to \"without-password\" in /etc/ssh/sshd_config"
      date=`date +%m%d%y%H%M%S`
      cp /etc/ssh/sshd_config /etc/ssh/sshd_config.$date
      sed s/"PermitRootLogin yes"/"PermitRootLogin without-password"/ /etc/ssh/sshd_config.$date > /etc/ssh/sshd_config
   fi
}

#Update bos.compat.links if necessary
function Update_bos_compat_links {
   echo "   Updating bos.compat.links if necessary"
   BCL=`lppchk -v 2>&1|grep bos.compat.links`

   nima8001_known_hosts="nima8001,10.115.176.60 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA0oPwGKDpLr/R+tVCiUDbzFmnePjSwjemqgaK804MvgUftmBjoLXBtJLssWNOs0Eyv+9UA/E3mpTFVPAVU0nXuOAmNzsd6RKT7RxdHi7LrBQk/M1SkTkUu2GO9rPLHiGW/LtV6PId3nvMmJE0oyMlZ/raOttwLcZ9AJjtSa6cHFE="
   found_in_known_hosts=`grep nim8001 /.ssh/known_hosts`
   if ! [[ -n $found_in_known_hosts ]] ; then       
      echo $nima8001_known_hosts >> /.ssh/known_hosts
   fi

   if [[ -n $BCL ]] ; then
	$SCPCMD nima8001:/export/lpp_source/lpp_source53_05sp3/installp/ppc/bos.compat.5.3.0.30.* /tmp 1>/dev/null 2>/dev/null
	cd /tmp;inutoc .;installp -d . ALL 1>/dev/null 2>/dev/null
   fi
}

#Remove bos.compat.links so lppchk -c returns clean
function Remove_bos_compat_links {
   BCL=`lppchk -v 2>&1|grep bos.compat.links`
   if [[ -n $BCL ]] ; then
      /usr/lib/instl/sm_inst installp_cmd -u -f'bos.compat.links' 1>/dev/null 2>/dev/null
   fi
}

#Update X11.msg.en_US.Dt.helpmin if necessary
function Update_X11_msg_en_US_Dt_helpmin {
   echo "   Updating X11.msg.en_US.Dt.helpmin if necessary"
   XmeDh=`lppchk -v 2>&1|grep X11.msg.en_US.Dt.helpmin`
   nima8001_known_hosts="nima8001,10.115.176.60 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA0oPwGKDpLr/R+tVCiUDbzFmnePjSwjemqgaK804MvgUftmBjoLXBtJLssWNOs0Eyv+9UA/E3mpTFVPAVU0nXuOAmNzsd6RKT7RxdHi7LrBQk/M1SkTkUu2GO9rPLHiGW/LtV6PId3nvMmJE0oyMlZ/raOttwLcZ9AJjtSa6cHFE="
   found_in_known_hosts=`grep nim8001 /.ssh/known_hosts`
   if ! [[ -n $found_in_known_hosts ]] ; then
      echo $nima8001_known_hosts >> /.ssh/known_hosts
   fi
 
   if [[ -n $XmeDh ]] ; then 
      $SCPCMD nima8001:/export/lpp_source/lpp_source53_04sp2/installp/ppc/X11.msg.en_US.5.3.0.0.I /tmp
      cd /tmp;inutoc .;installp -d . ALL
   fi
}

#Update AIX5.3.5
function Update_AIX535 {
   echo "   Updating AIX 5.3.5 if necessary"
   /usr/sbin/nimclient -o cust -a lpp_source=lpp_source53_05sp5 -a fixes="update_all" 1>/dev/null 2>/dev/null
}

#Apply efix 76720SP2-2.060427
function Apply_EFIX {
   echo "   Copying over efix efix_AIX53_TL4CSP.epkg.Z from nima8001 to /tmp"
   $SCPCMD -q nima8001:/uht_packages/AIX53/EFIX/NIS_AIX53_TL4CSP/efix_AIX53_TL4CSP.epkg.Z /tmp
   echo "   Applying efix efix_AIX53_TL4CSP.epkg.Z if necessary"
   /usr/sbin/slibclean
   emgr -e /tmp/efix_AIX53_TL4CSP.epkg.Z 1>/dev/null 2>/dev/null
}

#Add machine to BOX Database on Zuhl
function Setup_BOXDB {
   #Set hostname
   HOSTNAME=`hostname`

   echo "   Running the addbox.sh command on zuhl"
   SERVER_NAME_FOUND=`$SSHCMD -q nima8001 "/usr/local/bin/ssh -q zuhl \"grep $HOSTNAME /usr/local/bin/mass_pass_boxes\""`
   if [[ -n $SERVER_NAME_FOUND ]] ; then
      echo "      $SERVER_NAME_FOUND already in BOX Database on Zuhl"
   else
      #Get Location of LPAR
      for INTERFACE in `lsdev|grep "en[0-9]"|awk '{print $1}'`
      do
          OUTPUT=`ifconfig $INTERFACE 2>/dev/null|awk '{print $2}'|head -2|tail -1|grep ^10`
          if [[ -n $OUTPUT ]] ; then
              
	     SECONDOCTECT=`echo $OUTPUT|awk 'FS="." {print $2}'`

             case $SECONDOCTECT in
		114|115|116|117)
		     LOCATION=Plymouth
		     ;;
		220|221|222|223)
		     LOCATION=Eagan
		     ;;
		216|217)
		     LOCATION=Trumbull
		     ;;
	     esac

             break
          fi
      done

      #Get Serial number of LPAR
      SERIAL=`lsattr -El sys0 -a systemid|awk '{print $2}'|awk 'FS="," {print $2}'|cut -c 3-`

      #Get Type of LPAR
      TYPE_NUM=`echo $HOSTNAME|cut -c 5`

      if [[ $TYPE_NUM == 8 ]] ; then
         TYPE=Test
      elif [[ $TYPE_NUM == 9 ]] ; then
         TYPE=Development
      elif [[ $TYPE_NUM == 0 ]]; then
         TYPE=Production
      else TYPE=""
      fi

      if [[ -n $TYPE && -n $SERIAL && -n $LOCATION ]] ; then
	 #Add $HOSTNAME to known.hosts file on zuhl
	 $SSHCMD -q nima8001 "/usr/local/bin/ssh -q zuhl \"ssh -o stricthostkeychecking=no $HOSTNAME exit\"" 2>/dev/null
         #Execute addbox.sh commnd
         $SSHCMD -q nima8001 "/usr/local/bin/ssh -q zuhl \"/usr/local/bin/addbox.sh -h $HOSTNAME -l $LOCATION -s $SERIAL -t unix -T $TYPE 1>/dev/null\"" 
      fi
    fi
}


#Copy over AIX53_build_script.txt file from nima8001 to /tmp
function Copy_Build_Script {
   echo "   Copying over AIX53_build_script.txt from nima8001 to /tmp"
   $SCPCMD -q nima8001:/uht_packages/AIX53/AIX53_build_script.txt /tmp
   echo "      Until the AIX53_build_script.txt gets modified not to use \"script\","
   echo "      you will have to log into $HOSTNAME and run the command:"
   echo "            script /var/AIX53_build_script.\`date +%m-%d-%Y.%H:%M\`"
   echo "            /tmp/AIX53_build_script.txt"
} 

#Copy over os-diag.ksh file from nima8001 to /tmp
function Copy_os_diag {
   echo "   Copying over AIX53_QA_script.ksh from nima8001 to /tmp"
   $SCPCMD -q nima8001:/uht_packages/AIX53/AIX53_QA_script.ksh /tmp
}


#Created by Harlan Grimm
function Setup_Etherchannel
{
   typeset OS_LEVEL=`oslevel -s`
   typeset ADAPTER_COUNT=`lsdev -C | grep ent[0-9] | wc -l`

   # Check if we have 4 virtual adaptes
   # Check the OS LEVEL
#   if [[ "${OS_LEVEL}" != "5300-05-03" ]] ; then
#      if [[ "${OS_LEVEL}" != "5300-05-05" ]] ; then
#         if [[ "${OS_LEVEL}" != "5300-05-CSP" ]] ; then
#            if [[ "${OS_LEVEL}" != "5300-05-06" ]] ; then
#               return -1
#            fi
#         fi
#      fi
#   fi

   if [[ $ADAPTER_COUNT -lt 4 ]] ; then
       #Commeneted out by Raj, because it messes up the formatted output I originally setup.
       #echo "Not enough virtaul adapters for EtherChannel"
       return -1
   fi

   # Next check if we have IP addresses
   typeset GET_INT=$(ifconfig -a | grep en[0-9] | cut -f1 -d":")
   typeset IP=$(ifconfig $GET_INT 2>/dev/null | grep inet | awk '{print $2}')
   typeset GW=$(netstat -nr | grep default | awk '{print $2}')
   typeset pt_cnt=$(echo $IP | sed -e "s/\./ /g" | wc -w)
   if [[ $pt_cnt -ne 4 ]] ; then
      return -1
      #Commeneted out by Raj, because it messes up the formatted output I originally setup.
      #echo "Do not have the IP address"
   fi

   gw_cnt=$(echo $GW | sed -e "s/\./ /g" | wc -w)

   if [[ $gw_cnt -ne 4 ]] ; then
      #Commeneted out by Raj, because it messes up the formatted output I originally setup.
      #echo "Not enough virtaul adapters for EtherChannel"
      echo "Gate address not available."
      return -1
   fi

   HST=$(hostname)

   # Configure NIB 
   lpar_id=$(lparstat -i | grep "Partition Number" | awk 'FS=":" {print $2}')
   MOD=$(expr $lpar_id % 2)

   # Down and detach active adapter
   ifconfig $GET_INT down detach 1>/dev/null 2>/dev/null
   chdev -l $GET_INT -a state=detach 1>/dev/null 2>/dev/null
   rmdev -l $GET_INT 1>/dev/null 2>/dev/null

   for ENT in $(lsdev -C | grep ent[0-9] | awk '{print $1}') ; do
       CS=$(lscfg -vl $ENT | grep $ENT | awk '{print $2}' | cut -f3 -d"-")
       case $CS in
            C10|C20)
                if [[ $MOD -eq 0 ]] ; then
                   E1C1=${ENT}
                else 
                   E1C2=${ENT}
                fi
                ;;
            C11|C21)
                if [[ $MOD -eq 0 ]] ; then
                   E2C1=${ENT}
                else 
                   E2C2=${ENT}
                fi
                ;;
            C110|C120)
                if [[ $MOD -eq 0 ]] ; then
                   E1C2=${ENT}
                else 
                   E1C1=${ENT}
                fi
                ;;
            C111|C121)
                if [[ $MOD -eq 0 ]] ; then
                   E2C2=${ENT}
                else 
                   E2C1=${ENT}
            fi
            ;;
      esac
   done   

   # Make Ether Channel
   mkdev -c adapter -s pseudo -t ibm_ech -a adapter_names=${E1C1} \
   -a backup_adapter=${E1C2} -a num_retries=8 -a retry_time=8 -a netaddr=10.220.192.1 1>/dev/null 2>/dev/null

   mkdev -c adapter -s pseudo -t ibm_ech -a adapter_names=${E2C1} \
   -a backup_adapter=${E2C2} -a num_retries=8 -a retry_time=8 -a netaddr=10.222.40.1 1>/dev/null 2>/dev/null

   # Not sure why this happens but we must run cfgmgr to get the en4 and en5
   cfgmgr

   # Do a mktcpip and chdev on the new adapters
   mktcpip -h $HST -a $IP -g $GW -m 255.255.252.0 -i en4 -s 1>/dev/null 2>/dev/null
}


function Clean_Up {
   echo "   DoNe!"
   echo "   Cleaning up now."
   HOSTNAME=`hostname`
   echo "   Reboot $HOSTNAME now to fix its backup network."
   Suicide
   #Kill the update script running on nim server.
   #This is to resolve an issue where the update script doesn't end
   LINE=`$SSHCMD -q $HOSTNAME "ps -ef|grep $HOSTNAME|grep ksh"`
   PID=`echo $LINE|awk '{print $2}'`
   RESULTS=`$SSHCMD -q $HOSTNAME "kill $PID" ` # 1>/dev/null 2>/dev/null`
   LINE=`$SSHCMD -q $HOSTNAME "ps -ef|grep $HOSTNAME|grep \"nim -o cust -a installp_flags=-aXg\""`
   PID=`echo $LINE|awk '{print $2}'`
   RESULTS=`$SSHCMD -q $HOSTNAME "kill $PID" ` #1>/dev/null 2>/dev/null`
}

function Suicide {
   #Kill this process if this script was not started with lpar_nim_update5.3.5.ksh
   NIM_SERVER=`grep NIM_MASTER_HOSTNAME= /etc/niminfo | awk 'FS="=" {print $2}'`

   if [[ "${NIM_SERVER}" != "nima8001" ]] ; then
      NIM_SERVER="nima8001 $SSHCMD -q ${NIM_SERVER}"
   fi

   echo "   Waiting 30 Seconds for NIM to clean me up, otherwise I will terminate myself."
   echo
   echo "sleep 30" > /tmp/Suicide.$$
   echo "echo   Commiting suicide now!" > /tmp/Suicide.$$
   echo "kill $$ 1>/dev/null 2>/dev/null" >> /tmp/Suicide.$$
   echo "rm /tmp/Suicide.$$" >> /tmp/Suicide.$$
   chmod 755 /tmp/Suicide.$$
   PROCESS=`$SSHCMD -q ${NIM_SERVER} ps -ef | grep /usr/bin/ksh | grep ${HOSTNAME} | grep -v grep|awk '{print \$2}'`
   $SSHCMD -q ${NIM_SERVER} kill ${PROCESS} 2>/dev/null
   PROCESS=`$SSHCMD -q ${NIM_SERVER} ps -ef | grep "nim -o cust -a installp_flags=-aXg ${HOSTNAME}"|grep -v grep|awk '{print \$2}'`
   $SSHCMD -q ${NIM_SERVER} kill ${PROCESS} 2>/dev/null
   /tmp/Suicide.$$ 1>/dev/null 2>/dev/null
}

function Check_For_VIO_Server {
   typeset LPPCHECK

   LPPCHECK=`lslpp -l ios.cli.rte 2>&1 | awk '{print $2}'`
   if [[ "${LPPCHECK}" == "0504-132" || "${LPPCHECK}" == "Fileset" ]] ; then
      OS_TYPE="AIX"
   else
      OS_TYPE="VIO"
   fi
}

#This function will set up the VIO HBAs with Fast Fail and Dynamic Tracking on
function VIO_Setup_FF_and_DT {
   typeset FSCSI
   typeset DYNTRK
   typeset FC_ERR_RECOV

   for FSCSI in `lsdev | grep fscsi | awk '{print $1}' | xargs` ; do
       DYNTRK=`lsattr -El "${FSCSI}" -a dyntrk | grep yes`
       FC_ERR_RECOV=`lsattr -El "${FSCSI}" -a fc_err_recov | grep fast_fail`
       if [[ "${DYNTRK}" == "" || "${FC_ERR_RECOV}" == "" ]] ; then 
          echo "   Setting up HBA ${FSCSI} for Fast Failing and Dynamic Tracking"
          chdev -l "${FSCSI}" -a fc_err_recov=fast_fail -a dyntrk=yes 1>/dev/null 2>/dev/null
          chdev -l "${FSCSI}" -a fc_err_recov=fast_fail -a dyntrk=yes -P 1>/dev/null 2>/dev/null
       else echo "   HBA ${FSCSI} has already been set for Fast Failing and Dynamic Tracking"
       fi
   done
}


#This function will set up VIO SNMP
function VIO_Setup_SNMP {
   typeset DATE=`date +%m%d%y%H%M%S`
   typeset SNMPD_FOUND
   typeset SNMPDV3_FOUND
   typeset COUNT="0"

   SNMPD_FOUND=`grep public /etc/snmpd.conf`
   if [ "${SNMPD_FOUND}" != "" ] ; then
      echo "   Updating /etc/snmpd.conf"
      cp /etc/snmpd.conf /etc/snmpd.conf.$DATE
      sed s/public/mgtusc/g /etc/snmpd.conf.$DATE > /etc/snmpd.conf
      COUNT="1"
   fi

   SNMPDV3_FOUND=`grep public /etc/snmpdv3.conf`
   if [ "${SNMPDV3_FOUND=}" != "" ] ; then
      echo "   Updating /etc/snmpdv3.conf"
      cp /etc/snmpdv3.conf /etc/snmpdv3.conf.$DATE
      sed s/public/mgtusc/g /etc/snmpdv3.conf.$DATE > /etc/snmpdv3.conf
      COUNT="1"
   fi

   #Bounce the demons if we made changes to SNMP
   if [ "${COUNT}" == "1" ] ; then
      stopsrc -s snmpd >/dev/null 2>&1
      startsrc -s snmpd >/dev/null 2>&1

      stopsrc -s hostmibd >/dev/null 2>&1
      stopsrc -s snmpd >/dev/null 2>&1
      stopsrc -s dpid2 >/dev/null 2>&1
   else echo "   SNMP already properly configured"
   fi
}

#This function will be used to install the SSH client on the VIO server
function VIO_Install_SSH {
   #typeset SSH_CURRENT_VERSION="OpenSSH_3.8.1p1 UHG-2004042901, OpenSSL 0.9.7d 17 Mar 2004"
   #typeset SSH_INSTALLED_VERSION=`$SSHCMD -V 2>&1`
   typeset KEYS
   typeset INITTAB_SSH
   typeset DATE=`date +%m%d%y%H%M%S`
   typeset PERMITROOTLOGIN
   typeset NIMA8001_SSH_PRIVKEY
   typeset NIMA8001_SSH_PUBKEY

   #if [ "${SSH_INSTALLED_VERSION}" != "${SSH_CURRENT_VERSION}" ] ; then
   #   echo "   Installing SSH ${SSH_CURRENT_VERSION}"
   #   #Use nima8001's private key to get into nima8001 without a password
   #   NIMA8001_SSH_PRIVKEY="-----BEGIN DSA PRIVATE KEY-----\nMIIBvAIBAAKBgQDgb7HiLxA8sQLbEiCLJqtSHFulaRNF8wQksYDHLwLPgsUG7zn3\namSvlNBdUnNZuWd14UrzYNMX9b8hgxuo0bKrwK9Euf0i5OkzKu1FXF674cpO+lOa\nNLkS3VpusZDuE+UJoXLqohXV8/EKfgfH4eFsvbTGTG3u/wEvI8ZNf1f8GQIVAIB/\nJf4utsd+wp7wN96VGQRoSHydAoGBAIAwUC3VQbMkD2Lvhe5R7uCeSigXAdf1wI7B\nGk95YiGeuap9t1ARdX13v6IpMOjp3JuJjcqeRiLcevgMmtC4dLvl8HnEQU6Y+rfr\nMY+VTooBU/hDmUNFb27GEbhZKzsVsjgugQUQIMsQrF0oSqKgOC5n7Zwx1WXHcZWY\n6vWf22g0AoGBALaCHxjec7tWsx0ZITgrdZi7LlpGjSjjHg4t9ArYLA5mi9Af4mdQ\nwQMpSuMkPBXjjGGViWYq+lX+DaOLWn8Y2M9X7pc58AGgnKBJEHd96Oy4hkG6nGAB\n1GCJZpIsvu4byW4BbTRXK6yy2URoDmFJxpqZy84IGPkW2vJ2e3Fs6HEfAhQ0UKt0\nnY7+WgvI2nSN+5wGU+H/pQ==\n-----END DSA PRIVATE KEY-----"
   #   NIMA8001_SSH_PUBKEY="ssh-dss AAAAB3NzaC1kc3MAAACBAOBvseIvEDyxAtsSIIsmq1IcW6VpE0XzBCSxgMcvAs+CxQbvOfdqZK+U0F1Sc1m5Z3XhSvNg0xf1vyGDG6jRsqvAr0S5/SLk6TMq7UVcXrvhyk76U5o0uRLdWm6xkO4T5QmhcuqiFdXz8Qp+B8fh4Wy9tMZMbe7/AS8jxk1/V/wZAAAAFQCAfyX+LrbHfsKe8DfelRkEaEh8nQAAAIEAgDBQLdVBsyQPYu+F7lHu4J5KKBcB1/XAjsEaT3liIZ65qn23UBF1fXe/oikw6Oncm4mNyp5GItx6+Aya0Lh0u+XwecRBTpj6t+sxj5VOigFT+EOZQ0VvbsYRuFkrOxWyOC6BBRAgyxCsXShKoqA4LmftnDHVZcdxlZjq9Z/baDQAAACBALaCHxjec7tWsx0ZITgrdZi7LlpGjSjjHg4t9ArYLA5mi9Af4mdQwQMpSuMkPBXjjGGViWYq+lX+DaOLWn8Y2M9X7pc58AGgnKBJEHd96Oy4hkG6nGAB1GCJZpIsvu4byW4BbTRXK6yy2URoDmFJxpqZy84IGPkW2vJ2e3Fs6HEf root@nima8001"

   #   #Make nima8001 private SSH key LPAR's private key
   #   echo "${NIMA8001_SSH_PRIVKEY}" > /.ssh/id_dsa
   #   chmod 600 /.ssh/id_dsa
   #   echo "${NIMA8001_SSH_PUBKEY}" > /.ssh/id_dsa.pub

   #   scp -q -o stricthostkeychecking=no nima8001:/uht_packages/OPENSSH/current_release/openssh.install . 
   #   scp -q -o stricthostkeychecking=no nima8001:/uht_packages/OPENSSH/current_release/openssh-3.8.1p1-2004042900-aix51.bff.Z .
   #   if [ -f /home/padmin/openssh.install ] ; then  
   #      rm openssh-3.8.1p1-2004042900-aix51.bff 1>/dev/null 2>/dev/null
   #      ksh /home/padmin/openssh.install 1>/dev/null 2>/dev/null
   #      rm /.ssh/id_dsa
   #      rm /.ssh/id_dsa.pub
   #   else echo "   The openSSH package was not copied from nima8001"
   #   fi

   #else echo "   SSH openssh-3.8.1p1 already installed"
   #fi

   if ! [[ -s /.ssh/id_rsa && -s /.ssh/id_rsa.pub ]] ; then
      echo "   Setting up SSH Keys"
      mkdir -p /.ssh
      export PATH=$PATH:/usr/local/bin:.;ssh-keygen -b 1024 -N "" -t rsa -f /.ssh/id_rsa 1>/dev/null
   fi

   #Create access for zig, zuhl, mgtp8013, and mgtp8014 to LPAR
   KEYS=`cat /.ssh/authorized_keys2 2>&1|egrep -v "zuhl|zig|mgtp8013|mgtp8014|apsp0530"`
   if [ "${KEYS}" != "" ] ; then
      echo "   Creating SSH keys for zuhl, zig, mgtp8013, mgtp8014, & apsp0530"
      echo "from=\"zuhl,zuhl.uhc.com,168.183.92.80,10.7.140.112,10.7.136.121\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA3qefRCnzXdVY6N9l3XPG4I179FQ/KSv1hlagcDHuceI8FTqhn6TTdHogRbKFLB0Sb8iVLmdn3P8FoYh4TriWHH3NCreeUcPTTV5PNh89e6wr9n6Du65NF9H/aaVVk7j+tsBY1h6sktlB/bBeKteCcLhASCKMgJvE8KE922QCmJ8= root@zuhl
from=\"zig,zig.uhc.com,168.183.51.54\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAoKpXjjetR6Dl3+ytjt0MpvJsaRKJezr2Jz3e/3wJzCn7Opc3m6Vpl6hseZaJGigtu2c5UtYt1Z0KHd1Oey1nlCpSONE2UyDB7BFunN10IMEiGj6wA9ZRF/8N5a5Cey+iFO12SMC9PoGSCiK1wHfR/F5DQuuIz0H3xc+y09nGNrc= root@zig
from=\"mgtp8013,mgtp8013.uhc.com,10.115.192.93\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAqOJK1OWz/CPgzoKj8PXYEcFYbZhKre3vLqbXRd6qxjxuPsS9A19TYujGobpPa4wyNsNEw2o5IW602O8rT03RRs/1COxed7Ef/fh8Ab0JTn6/9HQwzxh7SPn6MR4g/DTlA9h9gCQZUG9t05Ts5j/Za+ioX30YwtKcKmyFJAYRJaM= root@mgtp8013
from=\"mgtp8014,mgtp8014.uhc.com,10.122.76.245\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA5O6B/k0wSTG/7Y/V2kHpOXGpm7zfsan7s1GFqqMr1+pQ0eAt01gyPxPjU/246x6uHmGTOJ5ra66t9j80CqNVmKLV6xFRXf0rvbDYsce8M3pn6XPruG8umssFWOL8VBcjfKX9hGcMva4baIfuYNLk0XhtmhzuctVpUjxCwslZ2zs= root@mgtp8014
from=\"apsp0530,apsp0530.uhc.com,10.220.197.44\" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA3zTcKxQY9kNczVQ0igawe9PKuD8ZJ8bEQiSq8sAMerC4tz0coApZgpVY3n6SJ4o1AQEp4wDp4tSPAYLfXZMIh4SLV8MloVkKWKJueSs3z8Gaipjc5QIM7wvqHdUQX78yxo2/ceSxLktTArBQ6RN+yJreoIj8tgLj+jfBOPPuO+8= root@apsp0530" >> /.ssh/authorized_keys2
   else echo "   SSH keys to zuhl, zig, mgtp8013, mgtp8014, and apsp0530 already setup"
   fi

      INITTAB_SSH=`grep openssh /etc/inittab`
   if [ "${INITTAB_SSH}" == "" ] ; then
      echo "   Adding openssh to /etc/inittab"
      echo "openssh:2:wait:/etc/rc.openssh start" >> /etc/inittab
   else echo "   SSH already added it inittab"
   fi

   #Change "PermitRootLogin yes" to "PermitRootLogin without-password" in /etc/ssh/sshd_config
   PERMITROOTLOGIN=`grep "PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null`
   if [ "${PERMITROOTLOGIN}" != "" ] ; then
      echo "   Changing PermitRootLogin \"yes\" to \"without-password\" in /etc/ssh/sshd_config"
      cp /etc/ssh/sshd_config /etc/ssh/sshd_config.$DATE 2>/dev/null
      sed s/"PermitRootLogin yes"/"PermitRootLogin without-password"/ /etc/ssh/sshd_config.$DATE > /etc/ssh/sshd_config 2>/dev/null
   fi
   PERMITROOTLOGIN=`grep "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null`
   if [ "${PERMITROOTLOGIN}" != "" ] ; then
      echo "   Changing PermitRootLogin \"no\" to \"without-password\" in /etc/ssh/sshd_config"
      cp /etc/ssh/sshd_config /etc/ssh/sshd_config.$DATE 2>/dev/null
      sed s/"PermitRootLogin no"/"PermitRootLogin without-password"/ /etc/ssh/sshd_config.$DATE > /etc/ssh/sshd_config 2>/dev/null
   fi
}

#This function will remove the xdaily program from the VIO's inittab
function VIO_Setup_Remove_XLM {
   typeset INITTAB_XLM
   typeset DATE=`date +%m%d%y%H%M%S`

   INITTAB_XLM=`grep ^xmdaily /etc/inittab`
   if [ "${INITTAB_XLM}" != "" ] ; then
      echo "   Commenting out xmdaily from /etc/inittab"
      cp /etc/inittab /etc/inittab.$DATE
      sed s/^xmdaily/:xmdaily/g /etc/inittab.$DATE > /etc/inittab
      telinit q
   else echo "   xmdaily already removed for inittab"
   fi
}


#This function will mirror the rootvg of the VIO Server
function VIO_Setup_Mirror_Rootvg {
   typeset ROOTVG_HDISK_COUNT
   typeset HDISK
   typeset ROOTVG_EXTENDED_DISK
   typeset BACKING_DEVICE
   typeset ROOTVG_LV
   typeset LV
   typeset PP
   typeset DOUBLE_PP
   typeset FAIL=FALSE
   typeset CURRENT_BOOT_DEVICE
   typeset IFS
   typeset IFS_SAVED="${IFS}"
   typeset USED_PP
   typeset BOOTLIST

   #Find the second local disk to mirror rootvg to
   #Add another disk to rootvg if there is only one assigned.
   ROOTVG_HDISK_COUNT=`lspv|grep rootvg|wc -l|sed -e "s/ //g"`
   if [ "${ROOTVG_HDISK_COUNT}" == "1" ] ; then
      for HDISK in `lspv|grep None|awk '{print $1}'` ; do
          ROOTVG_EXTENDED_DISK=`lsdev|grep "${HDISK}"|egrep "SCSI|SAS"|awk '{print $1}'`
          #IF we found a disk, break out of the loop
          if [ "${ROOTVG_EXTENDED_DISK}" != "" ] ; then
             break
          fi
      done
      echo "   Extending rootvg onto ${ROOTVG_EXTENDED_DISK}"
      extendvg -f rootvg "${ROOTVG_EXTENDED_DISK}" 1>/dev/null 2>&1
   else echo "   rootvg already has more than one disk"
   fi

   #Check if the VIO server is already mirrored
   ROOTVG_LV=`lsvg -l rootvg | tail +3 | \
              grep -v sysdump |  awk '{print $3" "$4}'`

   IFS="
"
   for LV in ${ROOTVG_LV[@]} ; do
       LP=`echo ${LV} | awk '{print $1}'`
       PP=`echo ${LV} | awk '{print $2}'`
       DOUBLE_PP=$((2*${LP}))
       if [ "${PP}" != "${DOUBLE_PP}" ] ; then
          FAIL=TRUE
       fi
   done

   #If the VIO Server was not mirrored, see if we can mirror it.
   if [ "${FAIL}" == "TRUE" ] ; then
      #Check if an LUNS were already assigned to any of the vhosts.
      #If there is, we don't want to run mirrorios, since this will
      #reboot the VIO Server. If it is activally serving disks to
      #LPARS, this may cause corruption.
      BACKING_DEVICE=`/usr/ios/cli/ioscli lsmap -all | grep "Backing device"`
      if [ "${BACKING_DEVICE}" == "" ] ; then
         if [ "${ROOTVG_EXTENDED_DISK}" == "" ] ; then
            for HDISK in `lsvg -p rootvg | egrep -v "rootvg|PV_NAME" | awk '{print $1}'` ; do
		USED_PP=`lspv "${HDISK}" | grep "USED PPs" | awk '{print $3}'`
                if [ "${USED_PP}" == 0 ] ; then
                   ROOTVG_EXTENDED_DISK="${HDISK}"
                   break
                fi
            done
         fi
         echo "   Mirroring rootvg onto ${ROOTVG_EXTENDED_DISK}, and rebooting afterwards"
         /usr/sbin/mirrorvg rootvg "${ROOTVG_EXTENDED_DISK}" 1>/dev/null 2>/dev/null
         bosboot -a -d "${ROOTVG_EXTENDED_DISK}" 1>/dev/null
         BOOTLIST=`lsvg -p rootvg | egrep -v "rootvg|PV_NAME" | awk '{print $1}'`
         bootlist -m normal ${BOOTLIST} #1>/dev/null

         shutdown -r
      else
         echo "   This VIO Server has disks mapped to some vhosts."
         echo "   You will have to mirror the rootvg disk, which will reboot this server"
      fi
   else echo "   rootvg already mirrored"
   fi
}


#This function will check to see if SEA was setup
function VIO_Check_SEA {
   typeset SEA=`lsdev | grep "Shared Ethernet Adapter" | awk '{print $1}' | xargs`
   typeset WHO_AM_I=`who am i | awk '{print $2}'`

   #Check if etherchannel was already set up. We don't want to do it again.
   if [ `echo ${SEA} | wc -w` -ne 2 ] ; then
      #The function should only be ran on a console window, otherwise you'll
      #get kicked out of the lpar and the script will end prematurely
      if [ "${WHO_AM_I}" != "vty0" ] ; then
         echo "   You'll need to run this script from the console window, otherwise you'll get"
         echo "   kicked out of the VIO and the script will end prematurely."
         exit
      fi
   fi
}


#This function will setup SEA on the VIO Server
function VIO_Setup_SEA {
   typeset SEA=`lsdev | grep "Shared Ethernet Adapter" | awk '{print $1}' | xargs`
   typeset HOSTNAME
   typeset IP
   typeset GATEWAY
   typeset SLOT_FCS0
   typeset SLOT_FCS1
   typeset SLOT_FCS
   typeset NIMA_FOUND
   typeset INTERFACES
   typeset UHCCOM
   typeset DATE=`date +%m%d%y%H%M%S`

   if [ "${SEA}" != "" ] ; then
      echo "   SEA devices ${SEA} already created"
      return 0
   fi

   #Set up IP addresses
   echo "   Setting up IP addresses now"

   #Save the current hostname
   HOSTNAME=`hostname`
   HOSTNAME=`echo $HOSTNAME|sed s/.uhc.com//g`

   #Save the current IP address
   IP=`netstat -ni|grep en|grep -v link|head -1|awk '{print $4}'`

   #Quit if we can't get our own IP
   if [ "${IP}" == "" ] ; then
      echo "      Can't determine current IP address."
      echo "      Please IP this VIO and run this script again."
      return
   fi
   
   #Get the backup IP
   #See if we can reach the nameserver
   IPBU=`nslookup "$HOSTNAME"bu.uhc.com 10.117.7.30 2>/dev/null|grep Address|tail -1|awk '{print \$2}'|grep -v 10.117.7.30`

   #Save the current gateway
   GATEWAY=`/usr/ios/cli/ioscli netstat -routtable|grep default|awk '{print $2}'`
   #Get the VLAN ID. This is an improper way. If the server was built with UHT standard, the primary VIO will have HBAs in
   #slot P1. The secondary VIO will have HBAs in C4.

   #Get Slot info
   SLOT_FCS0=`lscfg -vl fcs0|head -1|awk '{print $2}'|awk 'FS="-" {print $3}'`
   SLOT_FCS1=`lscfg -vl fcs1|head -1|awk '{print $2}'|awk 'FS="-" {print $3}'`

   if [[ "${SLOT_FCS0}" == "" && "${SLOT_FCS1}" == "" ]] ; then
      echo "   No HBAs found on system. I can't determine if this is a primary or secondary VIO"
      echo "      As such, you will have to manually configure etherchannel, or add HBAs to this"
      echo "      VIO and run this script again."
      return
   fi

   #See if the slots are the same. If so, that's one more check this is a standard build
   if [ "{$SLOT_FCS0}" == "{$SLOT_FCS1}" ] ; then
      SLOT_FCS=$SLOT_FCS0
   else SLOT_FCS=""
   fi

   #Remove the current IP address
   echo "   Removing all ent devices"
   /usr/ios/cli/ioscli rmtcpip -f -all
  
   #Remove all interfaces
   #Get the number of interfaces
   INTERFACES=`lsdev | grep ent | awk '{print $1}' | cut -c 4- | xargs | rev`
   for I in $INTERFACES ; do
       rmdev -Rdl ent$I 1>/dev/null 2>/dev/null
       rmdev -Rdl en$I 1>/dev/null 2>/dev/null
       rmdev -Rdl et$I 1>/dev/null 2>/dev/null
   done
   /usr/ios/cli/ioscli cfgdev 1>/dev/null

   #For P5 Frames
   #If $SLOT_FCS=C1, then this is most likey the Primary VIO, assuming the standard placement of HBAs
   #If $SLOT_FCS=C4, then this is most likey the Seconday VIO, assuming the standard placement of HBAs
   #If $SLOT_FCS="", then this VIO Server is not standard and we can't determine if this is a Primary or Secondary VIO
   #For P6-550 frames
   MODELNAME=`lsattr -El sys0 -a modelname|awk '{print $2}'|awk 'FS="," {print $2}"'`

   typeset DEFAULTID_FIRST_VIO_PRIMARY="1"
   typeset DEFAULTID_FIRST_VIO_BACKUP="3"
   typeset DEFAULTID_SECOND_VIO_PRIMARY="2"
   typeset DEFAULTID_SECOND_VIO_BACKUP="4"

   typeset LPAR_ID=`/usr/ios/cli/ioscli lsmap -all -net|grep ent2|awk 'FS="-" {print $2}'`
   if [ "${LPAR_ID}" == "V102" ] ; then
      DEFAULTID_FIRST_VIO_PRIMARY="5"
      DEFAULTID_FIRST_VIO_BACKUP="7"
   elif [ "${LPAR_ID}" == "V103" ] ; then
      DEFAULTID_SECOND_VIO_PRIMARY="6"
      DEFAULTID_SECOND_VIO_BACKUP="8"
   fi

   #Primary VIO
   if [ "${MODELNAME}" == "8204-E8A" ] ; then 
      if [[ "${SLOT_FCS0}" == "C1" || "${SLOT_FCS0}" == "C02" ]] ; then
         echo "   Creating SEA interfaces for Primary VIO"
         /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|head -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -defaultid ${DEFAULTID_FIRST_VIO_PRIMARY} 1>/dev/null
        /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|tail -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -defaultid ${DEFAULTID_FIRST_VIO_BACKUP} 1>/dev/null
      elif [[ "${SLOT_FCS0}" == "C07" || "${SLOT_FCS0}" == "C3" ]] ; then
         echo "   Creatng SEA interfaces for Secondary VIO"
         /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|head -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -defaultid ${DEFAULTID_SECOND_VIO_PRIMARY} 1>/dev/null
         /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|tail -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -defaultid ${DEFAULTID_SECOND_VIO_BACKUP} 1>/dev/null
      fi
   elif [ "${MODELNAME}" == "9117-MMA" ] ; then
        if [[ "${SLOT_FCS0}" == "C4" ]] ; then
           echo "   Creating SEA interfaces for Primary VIO"
           /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|head -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -defaultid ${DEFAULTID_FIRST_VIO_PRIMARY} 1>/dev/null
          /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|tail -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -defaultid ${DEFAULTID_FIRST_VIO_BACKUP} 1>/dev/null
        elif [ "${SLOT_FCS}" == "C5" ] ; then
           echo "   Creatng SEA interfaces for Secondary VIO"
           /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|head -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -defaultid ${DEFAULTID_SECOND_VIO_PRIMARY} 1>/dev/null
           /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|tail -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -defaultid ${DEFAULTID_SECOND_VIO_BACKUP} 1>/dev/null
      fi
   elif [ "${SLOT_FCS}" == "C1" ] ; then
      echo "   Creating SEA interfaces for Primary VIO"
      /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|head -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -defaultid ${DEFAULTID_FIRST_VIO_PRIMARY} 1>/dev/null
      /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|tail -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -defaultid ${DEFAULTID_FIRST_VIO_BACKUP} 1>/dev/null

   #Secondary VIO
   elif [ "${SLOT_FCS}" == "C4" ] ; then
        echo "   Creatng SEA interfaces for Secondary VIO"
        /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|head -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C20|awk '{print \$1}'` -defaultid ${DEFAULTID_SECOND_VIO_PRIMARY} 1>/dev/null
        /usr/ios/cli/ioscli mkvdev -sea `lsdev|grep ^e|grep 2-Port|tail -1|awk '{print \$1}'` -vadapter `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -default `/usr/ios/cli/ioscli lsmap -all -net|grep C21|awk '{print \$1}'` -defaultid ${DEFAULTID_SECOND_VIO_BACKUP} 1>/dev/null
   
   else echo "   HBAs are not in the standard slots. Primary or Secondary VIO can not be determined."
        echo "   You will have to manually setup SEA."
   fi

   #IP the VIO
   echo "   Re-IPing the VIO"
#   if [ "${MODELNAME}" == "8204-E8A" ] ; then
      /usr/ios/cli/ioscli mktcpip -hostname $HOSTNAME -interface en`/usr/ios/cli/ioscli lsmap -all -net|grep C22|awk '{print $1}'|awk 'FS="t" {print $2}'` -netmask 255.255.252.0 -start -inetaddr $IP -gateway $GATEWAY
      if [ "${IPBU}" != "" ] ; then
         /usr/ios/cli/ioscli mktcpip -hostname $HOSTNAME -interface en`/usr/ios/cli/ioscli lsmap -all -net|grep C23|awk '{print $1}'|awk 'FS="t" {print $2}'` -netmask 255.255.252.0 -start -inetaddr $IPBU
      fi
#   else
#      /usr/ios/cli/ioscli mktcpip -hostname $HOSTNAME -interface en`/usr/ios/cli/ioscli lsmap -all -net|grep C22|awk '{print $1}'|awk 'FS="t" {print $2}'` -netmask 255.255.252.0 -start -inetaddr $IP -gateway $GATEWAY
#      if [ "${IPBU}" != "" ] ; then
#         /usr/ios/cli/ioscli mktcpip -hostname $HOSTNAME -interface en`/usr/ios/cli/ioscli lsmap -all -net|grep C23|awk '{print $1}'|awk 'FS="t" {print $2}'` -netmask 255.255.252.0 -start -inetaddr $IPBU
#      fi
#   fi

   #Add nima8001 to /etc/hosts
   NIMA_FOUND=`grep nima8001 /etc/hosts`
   if [ "${NIMA_FOUND}" == "" ] ; then
      echo "   Adding nima8001 to /etc/hosts"
      echo "10.115.176.60\tnima8001" >> /etc/hosts
   else echo "   nima8001 already in /etc/hosts"
   fi
 
   #Modify hostname.uhc.com to hostname in /etc/hosts
   echo "   Removing ".uhc.com" from hostname in /etc/hosts"
   DATE=`date +%m%d%y%H%M%S`
   cp /etc/hosts /etc/hosts.$DATE;sed s/.uhc.com//g /etc/hosts.$DATE > /etc/hosts
}

function VIO_Install_HDLM {
   #This function is to add the HDLM drivers after a VIO image is installed.
   #In previous images, the HDLM was pre installed and this caused some issues
   #with our new builds. Now, HLDM has been separated and we need to install it
   #manually.

   #Check if /home/padmin/hdlm exists. If so, continue. If not return.
   if [ -d /home/padmin/hdlm ] ; then
      #Check if DLManager.mpio.rte was already installed
      typeset RESULTS=`lslpp -cql DLManager.mpio.rte 2>/dev/null`
        if [ "${RESULTS}" = "" ] ; then 
           echo "   Installing HDLM & DLM"      
           cd /home/padmin/hdlm
           installp -a -cQX -d . ALL 1>/dev/null 2>/dev/null
           installp -a -cQX -d . ALL 1>/dev/null 2>/dev/null
        else
           echo "   HDLM & DLM Already installed"
        fi
   fi
   /usr/DynamicLinkManager/bin/dlnkmgr set -iem on -s 1>/dev/null 2>/dev/null
   /usr/DynamicLinkManager/bin/dlnkmgr set -afb on -intvl 10 -s 1>/dev/null 2>/dev/null
}

function VIO_Setup {
   #Enter into super user mode
   oem_setup_env 2>/dev/null

   #This function will check to see if SEA was setup
   VIO_Check_SEA

   #Set up the VIO HBAs with Fast Fail and Dynamic Tracking on
   VIO_Setup_FF_and_DT

   #This function will set up VIO SNMP
   VIO_Setup_SNMP

   #This function will be used to install the SSH client on the VIO server
   VIO_Install_SSH

   #This function will remove the xdaily program from the VIO's inittab
   VIO_Setup_Remove_XLM

   #This function will setup SEA on the VIO Server
   VIO_Setup_SEA

   #This function will setup HDLM for Version 1.5.2 and above
   VIO_Install_HDLM
   
   #This function will mirror the rootvg of the VIO Server
   VIO_Setup_Mirror_Rootvg
}

# MAIN
 Check_For_VIO_Server	#Check if client LPAR or VIO
 if [ "${OS_TYPE}" == "VIO" ] ; then 
    VIO_Setup
    exit
 fi
 Check_for_SSH 
 Setup_PATH
 Setup_Etherchannel     # set up etherchannel if conditions are right
 Setup_NS
 Remove_UHC_COM
 Setup_Hostnamebu
 Configure_PV_FSCSI_MPIO
 C30_C130
 C60_C160
 Setup_SSH
 #Update_bos_compat_links
 #Remove_bos_compat_links
 #Update_X11_msg_en_US_Dt_helpmin
 #Update_AIX535
 #Apply_EFIX
 #Setup_BOXDB
 Copy_Build_Script
 Copy_os_diag
 Clean_Up
 
exit
