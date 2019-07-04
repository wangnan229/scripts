#/bin/bash

#获取本机ip地址
ipaddr=`ifconfig |grep team0 -A 1|grep inet|awk '{print $2}'`
if [ "$ipaddr" =  "" ]
then
    ipaddr=`ifconfig |grep bond0 -A 1|grep inet|awk '{print $2}'|awk -F':' '{print $2}'`
fi
if  [ "$ipaddr" =  "" ]
then
    ipaddr=`/sbin/ifconfig | grep 'inet ' | awk '{print $2}' | sed -e '/127\.0\.0\.1/d'`
fi
echo "服务器IP地址：$ipaddr"


back_path="/export/backup/war_backup/"
text_path="/export/backup/tomcat.text"
#ipaddr="10.159.32.173"
d=$(date --iso)

# FTP Login Data
USERNAME="ftpuser"
PASSWORD="cEUD5r7QbD"
SERVER="10.199.97.43"
PORT="21"

REMOTEDIR="./shengtaiquan/$ipaddr/"

#开始打包
cat $text_path | while read line
do
    filename=`echo $line | awk -F\/ '{print $NF}'`
    cd  $line
    echo "$back_path$ipaddr-$filename-$d.tar.gz"
    tar -zcf $back_path$ipaddr-$filename-$d.tar.gz  ./*
done

#上传到ftp服务器
ls -l $back_path | grep -v total | while read line2
do
    filename2=`echo $line2 | awk '{print $NF}'`
    ftp -n -i $SERVER $PORT << EOF
user $USERNAME $PASSWORD
binary
lcd  $back_path
cd $REMOTEDIR
mput $filename2
quit
EOF
done

rm -f $back_path* 
