#!/bin/bash

#usage:
#put the mysql tar package under /root
#the default datadir=/data/mysql/mysql${port},if you want a different,change it at line 146
#the default basedir=/apps/${mysql_version},if you want a different,change it at line 147

dt=`date`
c_date=`date '+%Y%m%d%H%M' '-d-0 day'`
host=`hostname`

echo "$dt"

# Check if user is root
if [ $(id -u) != "0" ]; then
        echo "Error: You must be root to run this script, please use root to install"
        exit 1
fi

clear
echo "====================================================================================="
echo "A tool to auto-compile & install MySQL 5.7.16 or later version on Redhat/CentOS Linux "
echo -e "=====================================================================================\n"
cur_dir=$(pwd)


#set mysql port
echo "===========================Set Mysql Port============================="
port="3306"
read -p "Set Mysql port (Press Enter for Default port: 3306):" port

if [ "${port}" = "" ]; then
        port="3306"
fi

CMD0="ps -efl | grep -i "port=${port}" | grep -v grep"
sh -c "$CMD0" > /tmp/tmp_ps_mysql${port}.txt

while [ -s "/tmp/tmp_ps_mysql${port}.txt" ];do
   read -p "A running MySQL process has already used port ${port}, please choose another one:" port
    if [ "${port}" = "" ]; then
            port="3306"
    fi
      CMD0="ps -efl | grep -i "port=${port}" | grep -v grep"
      sh -c "$CMD0" > /tmp/tmp_ps_mysql${port}.txt
done

rm -f /tmp/tmp_ps_mysql${port}.txt
echo -e "MySQL port: ${port}\n"


#set mysql server_id
echo "=========================Set Mysql Server-id=========================="
read -p "mysql server_id (Press enter to generate a random server_id):" server_id

if test "${server_id}" = "" ;then
        server_id=$RANDOM
fi

CMD1="ps -efl | grep "mysqld" | grep -v grep"
sh -c "$CMD1" > /tmp/tmp_ps_mysql_serverid.txt

cat /tmp/tmp_ps_mysql_serverid.txt | sed -r 's/.*defaults-file=(.*).cnf.*/\1/' > /tmp/tmp1_ps_mysql_serverid.txt
touch /tmp/exsists_server_id.txt

while read mycnf
do
        cat $mycnf.cnf | grep -i server-id | awk 'BEGIN{FS="="}{print $2}' >> /tmp/exsists_server_id.txt
done < /tmp/tmp1_ps_mysql_serverid.txt

for line in `cat /tmp/exsists_server_id.txt`
do
        if test "$line" = "$server_id" ;then
                 read -p "this server_id has been used by an running mysql, Please choose another server_id: " server_id
                if test "$line" = "$server_id" ;then
                         read -p "this server_id has been used by an running mysql, Please choose another server_id: " server_id
                        if test "$line" = "$server_id" ;then
                                 server_id=$RANDOM
                                 echo "Exsist again, I lost my patience, generate a random server_id: $server_id"
                        fi
                fi
        fi
done

rm -f /tmp/tmp_ps_mysql_serverid.txt /tmp/tmp1_ps_mysql_serverid.txt /tmp/exsists_server_id.txt
echo -e "MySQL server_id: ${server_id}\n"


#set mysql root password
echo "=======================Set Mysql Root Password========================"
mysqlrootpwd="mysql0828"
read -p "Set Mysql Root Password (Press Enter for Default password: mysql0828):" mysqlrootpwd
if [ "${mysqlrootpwd}" = "" ]; then
        mysqlrootpwd="mysql0828"
fi
echo -e "MySQL root password:${mysqlrootpwd}\n"


#which MySQL Version do you want to install?
echo "========================Check MySQL Version==========================="
cd /root/
myversion=`ls mysql-5.7.*linux*.tar.gz`
mysql_version=`expr substr $myversion 7 6`

isinstallmysql57="n"
echo "Install MySQL ${mysql_version}, Please input：y"
echo "If Not This Version, Please input：n"
read -p "Please input y , n (Press Enter for Version ${mysql_version}):" isinstallmysql57

case "$isinstallmysql57" in
y|Y|Yes|YES|yes|yES|yEs|YeS|yeS|"")
echo "You will install MySQL ${mysql_version}"
isinstallmysql57="y"
;;
*)
echo "INPUT error,You will exit install MySQL ${mysql_version}"
isinstallmysql57="n"
exit
esac


#Initialize the installation related content
echo -e "\n==============Initialize the installation related content============="
echo -e "OS version:"
uname -r

MemTotal=`free -m | grep Mem | awk '{print $2}'`
echo -e "\nMemory is: $MemTotal MB "

#echo -e "\nDelete Old Mysql program"
#rpm -qa|grep mysql
#rpm -e mysql

echo -e "\nDisable SeLinux"
if [ -s /etc/selinux/config ]; then
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
fi
setenforce 0

cd $cur_dir

cat >>/etc/security/limits.conf<<EOF
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
EOF


#Install MySQL
echo -e "\n========================Install MySQL ${mysql_version}=========================="

#mysql data directory
echo "=======================Set Mysql data directory========================"
mydatadir='/export/mysqldata1'
read -p "Set Mysql data directory (Press Enter for Default directory: /export/mysqldata1):" mydatadir
if [ "${mydatadir}" = "" ]; then
        mydatadir="/export/mysqldata1"
fi
echo -e "MySQL data directory:${mydatadir}\n"

datadir=${mydatadir}/mydata
basedir='/usr/local/mysql'

#mysql directory configuration
echo -e "unzip $myversion\nThis may take a few minutes!"

if [ -d /usr/local/mysql-${mysql_version}-linux*x86_64 ]; then
  echo -e "\nDirectory /usr/local/mysql-${mysql_version}-linux*x86_64 already Exsists!\nSkipped unzip, Continue the next step...\n"
else
  if [ -d /root/mysql-${mysql_version}-linux*x86_64 ]; then
    echo "Tar package already unziped! Continue the next step"
    if [ ! -d /root/mysql${mysql_version} ]; then
      mv /root/mysql-${mysql_version}-linux*x86_64 /usr/local/
    fi
  elif [ -d /root/mysql${mysql_version} ]; then
    echo -e "\nDirectory /root/mysql${mysql_version} already Exsists!\nSkipped unzip, Continue the next step...\n"
  else
    cd /root
    tar xf /root/$myversion -C /root/
    echo -e "unzip completed!\n"
    mv /root/mysql-${mysql_version}-linux*x86_64 /usr/local/
  fi
fi


##Create Mysql user
id mysql
if [ $? -ne 0 ]; then
  echo -e "Create Mysql user ..."
  groupadd mysql -g 512
  useradd -u 512 -g mysql -s /sbin/nologin -d /home/mysql mysql
else
  echo -e "Mysql user has bean created by other one!\n"
fi


#mysql directory configuration
if [ -d /data/mysql/mysql${port} ]; then
 if [ "`ls -A /data/mysql/mysql${port}`" != "" ]; then
  echo "/data/mysql/mysql${port} exsists and is not empty"
  echo "Please drop or empty it and run the script again!"
  exit 0
 else
  echo "/data/mysql/mysql${port} created by other one!"
 fi
else
  echo -e "Create data directory ${mydatadir}...\n"
  mkdir -p ${mydatadir}
  echo -e "Create mysql directories binlog  innodb_log  innodb_ts  log  mydata  relaylog  sock  tmpdir...\n"
  cd ${mydatadir}
  mkdir -p binlog  innodb_log  innodb_ts  log  mydata  relaylog  sock  tmpdir
fi

echo -e "Link ${basedir} to /usr/local/mysql..."
if [ -L /usr/local/mysql ];then
  echo "/usr/local/mysql already been linked, skiped! Continue..."
  else
ln -s /usr/local/mysql-${mysql_version}-linux*x86_64 /usr/local/mysql
fi

echo -e "\n"

chown -R mysql:mysql /usr/local/mysql
chown -R mysql:mysql ${mydatadir}

#server_id=`ifconfig eth0 | grep "inet addr" | awk '{ print $2}'| awk -F. '{ print $3$4}'`

#set parameter innodb_buffer_pool_size
echo "=======================Set Mysql innodb_buffer_pool_size========================"
innodb_buffer_pool_size="512M"
read -p "Set parameter innodb_buffer_pool_size (Press Enter for Default innodb_buffer_pool_size: 512M):" innodb_buffer_pool_size
if [ "${innodb_buffer_pool_size}" = "" ]; then
        innodb_buffer_pool_size="512M"
fi
echo -e "MySQL innodb_buffer_pool_size:${innodb_buffer_pool_size}\n"

#generate mysql.cnf file
cat >/etc/my_${port}.cnf<< EOF
[client]
loose_default-character-set=utf8
user=zabbix
password=zabbix123

[mysqld_multi]
mysqld=${basedir}/bin/mysqld_safe
mysqladmin=${basedir}/bin/mysqladmin

[mysqld]
default-storage-engine=INNODB
character_set_server=utf8
character_sets_dir=${basedir}/share/charsets/
lc-messages-dir=${basedir}/share/english
secure_file_priv=''


user=mysql
port=${port}
socket=${mydatadir}/sock/mysql.sock
pid-file=${mydatadir}/sock/mysql.pid
datadir=${mydatadir}/mydata
tmpdir=${mydatadir}/tmpdir

#skip-locking
skip-name-resolve
skip_external_locking

large-pages
lower_case_table_names=0
event_scheduler=1
back_log=100

max_connections=3000
max_connect_errors=99999
max_allowed_packet=64M
max_heap_table_size=256M
max_length_for_sort_data=16k

wait_timeout=3600
interactive_timeout=7200
table_open_cache=512
thread_cache_size=128

net_buffer_length=8K
read_buffer_size=2M
read_rnd_buffer_size=512K
sort_buffer_size=2M
join_buffer_size=4M

thread_cache_size=512
tmp_table_size=128M

log-error=${mydatadir}/log/error.log
#log_long_format
long_query_time=1
slow_query_log
slow_query_log_file=${mydatadir}/log/slow-query.log
log_warnings
log-bin=${mydatadir}/binlog/mysql-bin
relay-log=${mydatadir}/relaylog/mysql-relay-bin
binlog_cache_size=2M
max_binlog_size=512M
binlog-format=ROW
sync_binlog=0
expire_logs_days=30

server-id=${server_id}
slave-skip-errors=1022,1032,1062
log_slave_updates=1
log_bin_trust_function_creators=1
auto_increment_increment=2
auto_increment_offset=1

key_buffer_size=32M
bulk_insert_buffer_size=16M
myisam_sort_buffer_size=64M
myisam_max_sort_file_size=10G
myisam_repair_threads=1

innodb_file_per_table
innodb_buffer_pool_size=${innodb_buffer_pool_size}
innodb_data_home_dir=${mydatadir}/innodb_ts
innodb_data_file_path=ibdata1:200M:autoextend
innodb_thread_concurrency=0
innodb_flush_log_at_trx_commit=2
innodb_fast_shutdown=1
innodb_log_buffer_size=8M
innodb_log_file_size=1024M
innodb_log_files_in_group=3
innodb_log_group_home_dir=${mydatadir}/innodb_log
innodb_max_dirty_pages_pct=75
innodb_lock_wait_timeout=120
innodb_rollback_on_timeout=1
innodb_flush_method=O_DIRECT
innodb_support_xa=OFF
transaction_isolation=READ-COMMITTED
# innodb plugin
innodb_read_io_threads=4
innodb_write_io_threads=16
innodb_file_format=barracuda
innodb_file_format_check=ON
innodb_strict_mode=1
master_info_repository = TABLE
relay_log_info_repository = TABLE
gtid_mode = on
enforce_gtid_consistency = 1
log_slave_updates=1
#rpl_semi_sync_master_enabled = 1
#rpl_semi_sync_slave_enabled = 1
#rpl_semi_sync_master_timeout = 5000
relay_log_recovery = 1
slave_skip_errors = ddl_exist_errors

[mysqldump]
quick
max_allowed_packet=2G
default-character-set=utf8

[mysql]
no-auto-rehash
show-warnings
prompt="\\u@\\h : \\d \\r:\\m:\\s> "
default-character-set=utf8

[myisamchk]
key_buffer=512M
sort_buffer_size=512M
read_buffer=8M
write_buffer=8M

[mysqlhotcopy]
interactive-timeout

[mysqld_safe]
user=mysql
open-files-limit=8192
#ledir=/usr/local/mysql/bin/

EOF

 
#Initialize Data
echo -e "\n===========================Initialize Data============================"

${basedir}/bin/mysqld --defaults-file=/etc/my_${port}.cnf --user=mysql --datadir=${datadir} --basedir=${basedir} --initialize-insecure > /dev/null 2>&1

echo -e "Completed!" 

#Configure ssl
echo -e "\n===========================Configure ssl==============================="

${basedir}/bin/mysql_ssl_rsa_setup --datadir=${datadir} > /dev/null 2>&1

echo -e "Completed!" 


cp ${basedir}/support-files/mysql.server /etc/init.d/mysqld
chmod 700 /etc/init.d/mysqld
chkconfig --add mysqld
chkconfig --level 2345 mysqld on
  
cat >> /etc/ld.so.conf.d/mysql-x86_64.conf<<EOF
/usr/local/mysql/lib

EOF

ldconfig
  
if [ -d "/proc/vz" ];then
  ulimit -s unlimited
fi

  
#Start Mysql Database
echo -e "\n=========================Start Mysql Database=========================" 
nohup ${basedir}/bin/mysqld_safe --defaults-file=/etc/my_${port}.cnf & > /dev/null 2>&1
sleep 5s
sleep 5s
echo -e "Completed!\n" 
sleep 10s


#Check the install    
echo "============================Check install============================="
echo "Check mysql process"
#rm -f /tmp/mysql_${port}.sock.lock nohup.out
CMD1="ps -efl | grep -i "port=${port}" | grep -v grep"
sh -c "$CMD1" > /tmp/ps_mysql${port}.txt


if [ -s "/tmp/ps_mysql${port}.txt" ]; 
then 
    echo -e "\ninstallation success!\nlog located at ${mydatadir}/log/error.log\n"
    rm -f /tmp/ps_mysql${port}.txt
else
    echo -e "\ninstall failed!\ncheck the err log: ${mydatadir}/log/error.log\n"
    exit 0
fi


#Set The Environmental variables
cat >> /etc/profile <<EOF
export PATH=$PATH:${basedir}/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${basedir}/lib
EOF

source /etc/profile
 
#cat >> ~/.bashrc <<EOF
#alias mysql${port}='${basedir}/bin/mysql -uroot -p -S /tmp/mysql_${port}.sock'
#EOF
#source ~/.bashrc


#change mysql root password
echo "=====================change mysql root password======================="
cat > /tmp/mysql_sec_script.sql<<EOF
use mysql;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${mysqlrootpwd}');
grant all privileges on *.* to root@'%' identified by '${mysqlrootpwd}';
flush privileges;
EOF

${basedir}/bin/mysql -u root -S ${mydatadir}/sock/mysql.sock < /tmp/mysql_sec_script.sql

echo -e "mysql root password changed!\n"

rm -f /tmp/mysql_sec_script.sql

#configure mysql semi sync
echo "=====================configure mysql semi sync======================="
cat > /tmp/mysql_semi_sync.sql<<EOF
install plugin rpl_semi_sync_master SONAME 'semisync_master.so';
install plugin rpl_semi_sync_slave SONAME 'semisync_slave.so';
set global rpl_semi_sync_master_enabled=1;
set global rpl_semi_sync_slave_enabled=1;
set global rpl_semi_sync_master_timeout=5000;
EOF

${basedir}/bin/mysql -u root -p${mysqlrootpwd} -S ${mydatadir}/sock/mysql.sock < /tmp/mysql_semi_sync.sql

echo -e "mysql semi sync changed!\n"

rm -f /tmp/mysql_semi_sync.sql

#configure parameter file mysql semi sync

echo "=====================configure parameter file mysql semi sync======================="

sed -ri 's/#(rpl*)/\1/' /etc/my_${port}.cnf

echo -e "configure parameter file mysql semi sync changed!\n"

echo -e "Execute this command first: source ~/.bashrc\nThen you can enter your mysql database using alias mysql${port}!\n"
echo -e "${dt}\n"
