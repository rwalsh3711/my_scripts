#!/bin/ksh
# -- This is my generic "be safe" script

export DATE=`date +%Y%m%d`
export HOST=`hostname`

# Start backing up the good stuff

	cp /etc/filesystems /etc/filesystems.$DATE
	cp /etc/group /etc/group.$DATE
	cp /etc/hosts /etc/hosts.$DATE
	cp /etc/inetd.conf /etc/inetd.conf.$DATE
	cp /etc/inittab /etc/inittab.$DATE
	cp /etc/netsvc.conf /etc/netsvc.conf.$DATE
	cp /etc/passwd /etc/passwd.$DATE
	cp /etc/security/group /etc/security/group.$DATE
	cp /etc/security/passwd /etc/security/passwd.$DATE
	cp /etc/mail/sendmail.cf /etc/mail/sendmail.cf.$DATE
        cp /var/adm/cron/cron.allow /var/adm/cron/cron.allow.$DATE

# Copy directory contents
mkdir /.ssh/bak
cp -R /.ssh/* /.ssh/bak/

mkdir /usr/lpp/save.config.bak
cp -R /usr/lpp/save.config/* /usr/lpp/save.config.bak/

cp /etc/niminfo /etc/niminfo.sav

echo "10.115.176.60 nima8001 nima8001.uhc.com" >> /etc/hosts
echo "10.216.48.41 nima8002 nima8002.uhc.com" >> /etc/hosts
echo "10.221.48.51 nima8003 nima8003.uhc.com" >> /etc/hosts
echo "10.221.48.52 nima8004 nima8004.uhc.com" >> /etc/hosts
