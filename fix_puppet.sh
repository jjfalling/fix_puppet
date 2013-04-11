#!/usr/bin/env bash

#Used to fix puppet issues with certs, etc.
#Lets cross some fingers and hope this works :)

puppetMaster="puppetmaster01"
domain="subdomain.domain.tld"

HOST=$1

if [ -z $HOST ]; then
        echo "Usage: fix_puppet.sh [non-fqdn hostname]"
        echo ""
        exit

fi


echo ""
echo "Attempt to fix puppet on $HOST.$domain?"
echo ""
echo "Press enter to continue or CTRL+C to exit..."
read -e null_var

echo ""
echo "Starting to fix puppet, please stand by..."
echo ""

#check to see if the host is vaid, if not exit
validHost=`dig $HOST.$domain +short`
if [ -z "$validHost" ]
then
        #host was not valid, give error and exit
        echo "There is no dns record for the host $HOST.$domain, exiting... "
        echo ""
        exit 1
fi

#if the drive filled up or there was a puppet issue then there may be an empty cert in the temp dir, lets kill it
if [ -f /var/lib/puppet/ssl/certs/$HOST.$domain.pem ]
then
        echo "Temp ssl file found for $HOST. This means something might have gone wrong with the previous sigining. Deleting temp file..."
        rm /var/lib/puppet/ssl/certs/$HOST.$domain.pem
fi

#stop pupppet on client
echo "Stopping puppet"
ssh -o StrictHostKeyChecking=no $HOST service puppet stop

#make ssl dir on client
echo "Creating ssl dir on client"
ssh -o StrictHostKeyChecking=no $HOST mkdir -p /var/lib/puppet/ssl
ssh -o StrictHostKeyChecking=no $HOST rm -rf /var/lib/puppet/ssl
ssh -o StrictHostKeyChecking=no $HOST mkdir -p /var/lib/puppet/ssl

#have puppet clean the certs for the client
echo "Running puppetca --clean for $HOST"
/usr/sbin/puppetca --clean $HOST.$domain

#prepare keys and sign them
#configuring client and signing ssl"
ssh -o StrictHostKeyChecking=no $HOST puppetd --no-daemonize --test --server $puppetMaster.$domain
/usr/sbin/puppetca --sign $HOST.$domain
ssh -o StrictHostKeyChecking=no $HOST puppetd --no-daemonize --test --server $puppetMaster.$domain

#restart puppet, this tends to be needed...
echo "Restarting puppet"
ssh -o StrictHostKeyChecking=no $HOST service puppet restart

#added the following to see if puppet is enabled on boot, we dont do anything with this other then tell the user
echo ""
echo "Here are the levels puppet will auto start on:"

ssh -o StrictHostKeyChecking=no $HOST chkconfig puppet --list
echo ""
echo ""
echo "Done fixing puppet...."
echo ""
