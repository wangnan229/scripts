#!/bin/bash
#write by zhenghanchao 20190630

########################
#yum install ftp -y
########################
# Edit Below This Line #
########################

backup_path="/usr/local/openresty/"
tar_path="/export/nginx_backup/"
filename="60.3-nginx"

# FTP Login Data
USERNAME="ftpuser"
PASSWORD="cEUD5r7QbD"
SERVER="10.199.97.43"
PORT="21"


#Remote directory where the backup will be placed
REMOTEDIR="./nginx/60.3and60.4/"

##############################
# Don't Edit Below This Line #
##############################
if [ -d "$backup_path" ];then
	echo "nginx config is exist"
else
	echo "$backup_path is not exist"
	echo "now quit"
	exit 1
fi

if [ -d "$tar_path" ];then
	echo "$tar_path is already exist"
else
	echo "$tar_path is not exist"
	echo "create $tar_path"
	mkdir $tar_path
fi

d=$(date --iso)
FILE=$tar_path$filename-$d.tar.gz
cd $backup_path
tar -zcf $FILE ./*



ftp -n -i $SERVER $PORT << EOF
user $USERNAME $PASSWORD
binary
lcd $tar_path
cd $REMOTEDIR
mput $filename-$d.tar.gz
quit
EOF

rm -f $FILE
echo 'Local Backup Removed'
echo 'Remote Backup Complete'
#END
