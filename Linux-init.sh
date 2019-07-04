#!/bin/bash
# desc: CentOS initialization
# curl https://yiyingcanfeng.github.io/centos-init.sh | bash
# 可选参数base kernel python php nodejs cmd_game jdk mysql mongodb docker
# 比如：curl https://yiyingcanfeng.github.io/centos-init.sh | bash -s base

echo -e "\033[31m 这个是Centos系统初始化脚本，请慎重运行！ press ctrl+C to cancel \033[0m"
sleep 5

v=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
 
if [ $v -eq 6 ]; then
 
    echo "系统版本：Centos 6"
 
fi
 
if [ $v -eq 7 ]; then
 
    echo "系统版本：Centos 7"
 
fi

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

function hostname_config() {
	#hostnamectl set-hostname aaa
	if [ "$1" == "" ];then
		echo "The host name is empty."
		exit 1
	else     
        echo "HostName is $1"
        hostnamectl set-hostname $1
	fi
	sleep 3
	echo "-------计算机名修改完成-------"
}

function firewall_config() {
    # 禁用selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
    # 请根据具体情况来决定是否关闭防火墙
    if [ $v -eq 6 ];then
		echo "-------修改Centos 6 防火墙策略-------"
		/sbin/iptables -F
		service iptables start
		chkconfig iptables on
		#调整默认策略（默认拒绝所有访问，改成允许所有访问）
		iptables -P INPUT ACCEPT
		#iptables -P OUTPUT ACCEPT
	fi

	if [ $v -eq 7 ];then
		echo "-------修改Centos 7 防火墙策略-------"
		systemctl restart firewalld.service
		systemctl enable firewalld.service
		#调整默认策略（默认拒绝所有访问，改成允许所有访问）：
		firewall-cmd --permanent --zone=public --set-target=ACCEPT
		firewall-cmd --reload
	fi
	echo "-------防火墙初始化完成-------"
}

function config_mirror_and_update() {
    MIRROR="http://mirrors.aliyun.com"
    #更换yum源为阿里源
    cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    #curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    sed -i "s/#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-Base.repo
    sed -i "s/mirrorlist=http/#mirrorlist=http/g" /etc/yum.repos.d/CentOS-Base.repo
    sed -i "s@baseurl=.*/centos@baseurl=$MIRROR/centos@g" /etc/yum.repos.d/CentOS-Base.repo
	yum clean all
    yum makecache

    #同步时间
	[ -f /etc/localtime ] && rm -rf /etc/localtime
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    yum install -y ntpdate
	ntpdate ntp1.aliyun.com

    #配置EPEL源
    #EPEL (Extra Packages for Enterprise Linux) 是由 Fedora Special Interest Group 为企业 Linux 创建、维护和管理的一个高质量附加包集合，适用于但不仅限于 Red Hat Enterprise Linux (RHEL), CentOS, Scientific Linux (SL), Oracle Linux (OL)
    yum install -y epel-release
    cp /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.backup
    mv /etc/yum.repos.d/epel-testing.repo /etc/yum.repos.d/epel-testing.repo.backup
    # curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
    sed -i "s/#baseurl/baseurl/g" /etc/yum.repos.d/epel.repo
    sed -i "s/metalink/#metalink/g" /etc/yum.repos.d/epel.repo
    sed -i "s@baseurl=.*/epel@baseurl=$MIRROR/epel@g" /etc/yum.repos.d/epel.repo

    yum makecache
    #yum update -y
	#初始化安装服务
	yum install -y vim telnet unzip tcpdump sysstat gcc gdb wget iotop iftop ntpd traceroute tomcat-native cronolog lrzsz apr lsof
	
	#增加普通用户的软件执行权限
	chmod u+s /usr/sbin/tcpdump
	chmod u+s /usr/sbin/iftop
	
	echo "-------YUM源和应用服务初始化完成-------"
}

# 内核优化
function kernel_config() {
	#文件句柄数优化
    cp /etc/security/limits.conf /etc/security/limits.conf.bak
	cat >> /etc/security/limits.conf << EOF
 *           soft   nofile       65535
 *           hard   nofile       65535
@cloud-user      hard    core            0
@cloud-user      soft    core            0
@cloud-user      hard    nproc           400000
@cloud-user      soft    nproc           300000
@cloud-user      hard    nofile          400000
@cloud-user      soft    nofile          300000
EOF

	cp /etc/security/limits.d/20-nproc.conf /etc/security/limits.d/20-nproc.conf.bak
	cat > /etc/security/limits.d/20-nproc.conf << EOF
 # Default limit for number of user's processes to prevent
 # accidental fork bombs.
 # See rhbz #432903 for reasoning.
 
 *          soft    nproc     102400
 root       soft    nproc     unlimited
EOF

	#内核参数优化
	cp /etc/sysctl.conf /etc/sysctl.conf.bak
	cat >> /etc/sysctl.conf << EOF
# U+ General Optimize Configuration
fs.file-max = 3260334
vm.swappiness=0
net.core.somaxconn = 8192
net.core.netdev_max_backlog = 2000 
net.core.rmem_default = 131072 
net.core.wmem_default = 131072 
net.core.rmem_max = 131072 
net.core.wmem_max = 131072 
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304 
net.ipv4.tcp_mem = 6180960 8241280 12361920
net.ipv4.ip_local_port_range = 10000 50000
net.ipv4.tcp_fin_timeout = 15 
net.ipv4.tcp_tw_reuse = 1 
net.ipv4.tcp_tw_recycle = 1 
net.ipv4.tcp_max_syn_backlog = 8192 
net.ipv4.tcp_max_orphans = 2048
net.ipv4.tcp_syncookies = 1
net.nf_conntrack_max = 655350
EOF
/sbin/sysctl -p
    echo "-------limit、sysctl初始化完成-------"
}

function user_add() {
	#创建haieradmin，并允许其用sudo命令时不需要输入密码
    NEWUSER="haieradmin"
	PASS="rOXFJZhiaACE"
	id $NEWUSER
	if [ $? -eq 0 ] ; then
		echo "$NEWUSER账户已存在，无法创建!"
	else
		useradd $NEWUSER
		echo $PASS | passwd --stdin $NEWUSER
		if [ $? -eq 0 ] ; then
			echo "$NEWUSER账户创建成功！"
			sed -i "/^root/a\$NEWUSER\tALL=(ALL)\tNOPASSWD: ALL" /etc/sudoers
		else
			echo "$NEWUSER账户创建失败！"
		fi
	fi
	
	NEWUSER2="cloud-user"
	PASS2="clouduser!@#"
	id $NEWUSER2
	if [ $? -eq 0 ] ; then
		echo "$NEWUSER2账户已存在，无法创建!"
	else
		useradd $NEWUSER2
		echo $PASS2 | passwd --stdin $NEWUSER2
		if [ $? -eq 0 ] ; then
			echo "$NEWUSER2账户创建成功！"
		else
			echo "$NEWUSER账户创建失败！"
		fi
	fi
	
	#创建标准目录
	rootdir=`df -h / | sed -n 2p | awk '{print $2}' |awk -FG '{print $1}'`
	echo $rootdir
	if [ $rootdir -lt 100 ] ;
	then
		[ ! -d /export ] && mkdir -p /export
		[ ! -d /apps ] && mkdir -p /apps
	else
		[ ! -d /export ] && mkdir -p /export/apps
		ln -s /export/apps /apps
	fi
	chown -hR cloud-user:cloud-user /apps /export

	echo "-------系统用户、目录初始化完成-------"
}

function dns_config() {
	#请根据各环境进行配置
    > /etc/resolv.conf
	cat >> /etc/resolv.conf <<EOF
nameserver $DNS1
nameserver $DNS2
nameserver $DNS3
EOF
	echo "dns初始化配置完成"
}

#安装jdk和tomcat
function install_jdk_and_tomcat() {
	#统一使用生产资源服务器下的jdk和tomcat，默认初始化jdk1.7.0_60，jdk使用的jdk1.8.0_172
    if [ ! -d "/apps/jdk1.7.0_60" ]; then
		cd /apps
		wget https://resource.haier.net/download/init/java/jdk1.7.tar.gz
		wget https://resource.haier.net/download/init/java/jdk1.8.tar.gz
		#wget https://resource.haier.net/download/java/tomcat8.5.tar.gz
		#curl @jenkins-res.uhome.haier.net:60021/ops/deploy_tomcat.sh">ftp://ftpuser:RwtgwZPj@jenkins-res.uhome.haier.net:60021/ops/deploy_tomcat.sh | bash /dev/stdin 750"
		#curl @jenkins-res.uhome.haier.net:60021/ops/deploy_tomcat8.sh">ftp://ftpuser:RwtgwZPj@jenkins-res.uhome.haier.net:60021/ops/deploy_tomcat8.sh | bash /dev/stdin 750"
		tar zxvf /apps/jdk1.7.tar.gz /apps/
		chown -hR cloud-user:cloud-user /apps/jdk1.7
		if [ ! -d "/apps/jdk1.7" ]; then
			cat >> /etc/profile << EOF
export JAVA_HOME=/apps/jdk1.7
export PATH=$JAVA_HOME/bin:\$PATH
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
EOF
		fi
		source /etc/profile
		rm -f /apps/jdk1.7.tar.gz jdk1.8.tar.gz
	fi
	
	echo "-------JDK、TOMCAT初始化完成-------"
}

#安装salt-minion 2019最新版本
function install_salt_minion() {
	#服务端域名：salt.haier.net
	if [ $v -eq 6 ];then
	    echo "-------执行Centos6 salt安装-------"
		yum install -y https://repo.saltstack.com/yum/redhat/salt-repo-latest.el6.noarch.rpm 
		yum install -y salt-minion
		sleep 5
		cat >> /etc/salt/minion << EOF
master: salt.haier.net
id: $ipaddr
EOF
		chkconfig salt-minion on
		service salt-minion 
	fi
	
	if [ $v -eq 7 ];then
		echo "-------执行Centos7 salt安装-------"
		yum install -y https://repo.saltstack.com/yum/redhat/salt-repo-latest.el7.noarch.rpm 
		yum install -y salt-minion
		sleep 5
		cat >> /etc/salt/minion << EOF
master: salt.haier.net
id: $ipaddr
EOF
		systemctl enable salt-minion
		systemctl restart salt-minion
	fi
	echo "-------Saltstack Minion初始化完成-------"
}

#安装zabbix agent
function install_zabbix_agent() {
	#安装zabbix-agent初始化,不同环境使用注意配置DNS zabbix.haier.net服务端映射
	
	#zabbix server
	ZBX_SERVER=zabbix.haier.net
	
	#zabbix-agent
	FTPROOT=ftp://$FTP/upload/software/zabbix
	ZCONF="https://resource.haier.net/download/init/zabbix/zabbix_agentd.conf"
	ZCRON="https://resource.haier.net/download/init/zabbix/crontab/zabbix-crontab.sh"
	TCPCONF="https://resource.haier.net/download/init/zabbix/zabbix_agentd.d/userparameter_tcp.conf"
	
	# install zabbix-agent
	rpm -q zabbix-agent &>/dev/null && ZBXA=1 || ZBXA=0
	if [ $ZBXA == 0 ];then
			if [ $OS == 3 ]  ;then
					OSVER=7
					echo "----OSVER: $OSVER----"
					FTPPATH=$FTPROOT/3.4.11/$OSVER
					ZAGT="zabbix-agent-3.4.11-1.el7.x86_64.rpm"
					ZSDR="zabbix-sender-3.4.11-1.el7.x86_64.rpm"

					# install zabbix-agent
					wget --ftp-user=$FTPUSER --ftp-password=$FTPPASSWD --directory-prefix=$LOCALPATH $FTPPATH/$ZAGT &>/dev/null && echo "----zabbix-agent download successed.----" || echo "----zabbix-agent download failed.----"
					wget --ftp-user=$FTPUSER --ftp-password=$FTPPASSWD --directory-prefix=$LOCALPATH $FTPPATH/$ZSDR &>/dev/null && echo "----zabbix-sender download successed.----" ||echo "----zabbix-sender download failed.----"
					yum -y install $LOCALPATH/$ZAGT $LOCALPATH/$ZSDR &>/dev/null && echo "----zabbix-agent zabbix-sender install seccessed.----"

					# remove rpm file
					rm -f $LOCALPATH/zabbix-agent*.rpm $LOCALPATH/zabbix-sender*.rpm

			elif [ $OS == 2 ];then
					OSVER=6
					echo "----OSVER: $OSVER----"
					FTPPATH=$FTPROOT/3.4.11/$OSVER
					ZAGT="zabbix-agent-3.4.11-1.el6.x86_64.rpm"
					ZSDR="zabbix-sender-3.4.11-1.el6.x86_64.rpm"

					# install zabbix-agent
					wget --ftp-user=$FTPUSER --ftp-password=$FTPPASSWD --directory-prefix=$LOCALPATH $FTPPATH/$ZAGT &>/dev/null && echo "----zabbix-agent download successed.----" || echo "----zabbix-agent download failed.----"
					wget --ftp-user=$FTPUSER --ftp-password=$FTPPASSWD --directory-prefix=$LOCALPATH $FTPPATH/$ZSDR &>/dev/null && echo "----zabbix-sender download successed.----" ||echo "----zabbix-sender download failed.----"
					yum -y install $LOCALPATH/$ZAGT $LOCALPATH/$ZSDR &>/dev/null && echo "----zabbix-agent zabbix-sender install seccessed.----"

					# remove rpm file
					rm -f $LOCALPATH/zabbix-agent*.rpm $LOCALPATH/zabbix-sender*.rpm


			else 
					echo "----OS not support! Exiting...----"
			fi

	else
			echo -e "----$(rpm -q zabbix-agent) already installed.----"
	fi


	# config zabbix-agent
	mv /etc/zabbix/zabbix_agentd.conf{,.ori.$(date +%F)}
	wget --ftp-user=$FTPUSER --ftp-password=$FTPPASSWD --directory-prefix=/etc/zabbix $ZCONF &>/dev/nulll && echo "----zabbix_agentd.conf download successed.----" || echo "----zabbix_agentd.conf download failed.----"
	sed -i "s/^Server=.*$/Server=$ZBX_SERVER/" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/^ServerActive=.*$/ServerActive=$ZBX_SERVER/" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/^Hostname=.*$/Hostname=$LOCALIP/" /etc/zabbix/zabbix_agentd.conf
	echo "----zabbix_agentd.conf update successed.-----"


	# config zabbix-agent tcp status
	if [ ! -f $TCPCONF ];then
			wget --ftp-user=$FTPUSER --ftp-password=$FTPPASSWD --directory-prefix=/etc/zabbix/zabbix_agentd.d $TCPCONF &>/dev/nulll && echo "----userparameter_tcp.conf download successed.----" || echo "----userparameter_tcp.conf download failed.----"
	fi

	# chmod
	chown -R zabbix:zabbix /etc/zabbix



	# start zabbix-agent
	if [ $OS == 3 ];then
			# start zabbix-agent
			systemctl restart zabbix-agent &>/dev/null && echo "----zabbix-agent start successed.----" ||echo "----zabbix-agent start failed.----"
			systemctl enable zabbix-agent &>/dev/null
	elif [ $OS == 2 ];then
			# start zabbix-agent
			service zabbix-agent restart &>/dev/null && echo "----zabbix-agent start successed.----" ||echo "----zabbix-agent start failed.----"
			chkconfig zabbix-agent on &>/dev/null
	else
			echo "----OS not support! Exiting...----"
	fi


	# mkdir bin
	if [ ! -d /etc/zabbix/bin ];then
			mkdir /etc/zabbix/bin
	fi

	# zabbix-agent crontab	
	if [ ! -f /etc/zabbix/bin/zabbix-crontab.sh ];then
			wget --ftp-user=$FTPUSER --ftp-password=$FTPPASSWD --directory-prefix=/etc/zabbix/bin $ZCRON &>/dev/null && echo "----zabbix-crontab.sh download successed.----" || echo "----zabbix-crontab.sh download failed.----" 
			chmod +x /etc/zabbix/bin/zabbix-crontab.sh
			chown -R zabbix:zabbix /etc/zabbix
	fi

	grep "/etc/zabbix/bin/zabbix-crontab.sh" /var/spool/cron/root &>/dev/null && ZC=1 || ZC=0
	if [ $ZC == 0 ];then
			echo '* * * * * /etc/zabbix/bin/zabbix-crontab.sh' >>/var/spool/cron/root
			echo "----zabbix-agent crontab config successed.----"
	else
			echo "----zabbix-agent crontab already exist.----"
	fi

	echo "-------Zabbix agent初始化完成-------"
}


#安装mysql5.7 http://mirrors.tuna.tsinghua.edu.cn/mysql,使用清华大学的源
function install_mysql_and_config() {
    cat > /etc/yum.repos.d/mysql-community.repo <<- "EOF"
[mysql-connectors-community]
name=MySQL Connectors Community
baseurl=http://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql-connectors-community-el7
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

[mysql-tools-community]
name=MySQL Tools Community
baseurl=http://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql-tools-community-el7
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

[mysql57-community]
name=MySQL 5.7 Community Server
baseurl=http://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql57-community-el7
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

[mysql80-community]
name=MySQL 8.0 Community Server
baseurl=http://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql80-community-el7
enabled=0
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

EOF

    yum install mysql-community-server -y
    #mysql配置
    if [[ "${MYSQL_PASSWORD}" == "" ]];then
    #root用户密码
    MYSQL_PASSWORD=mysql0828
    fi
    systemctl start mysqld
    systemctl enable mysqld
    passlog=$(grep 'temporary password'  /var/log/mysqld.log)
    pass=${passlog:${#passlog}-12:${#passlog}}
    mysql -uroot -p"${pass}" -e"alter user root@localhost identified by 'QQQqqq111...' " --connect-expired-password
    pass=QQQqqq111...
    mysql -uroot -p"${pass}" -e"set global validate_password_policy=0;" --connect-expired-password
    mysql -uroot -p"${pass}" -e"set global validate_password_length=4;" --connect-expired-password
    mysql -uroot -p"${pass}" -e"set global validate_password_mixed_case_count=0;" --connect-expired-password
    mysql -uroot -p"${pass}" -e"set global validate_password_number_count=0;" --connect-expired-password
    #echo 'enter your mysql password'
    #read password
    mysql -uroot -p"${pass}" -e"set password=password('${MYSQL_PASSWORD}');" --connect-expired-password
    mysql -uroot -p"${MYSQL_PASSWORD}" -e"update mysql.user set host='%' where user='root';" --connect-expired-password
    mysql -uroot -p"${MYSQL_PASSWORD}" -e"flush privileges;" --connect-expired-password

	echo "-------Mysql5.7 初始化安装完成-------"
}

#安装mongodb,使用清华大学的源
function install_mongodb() {
    echo "" > /etc/yum.repos.d/mongodb.repo
    for version in "3.0" "3.2" "3.4" "3.6" "4.0"; do
    cat >> /etc/yum.repos.d/mongodb.repo <<- EOF
[mongodb-org-$version]
name=MongoDB Repository
baseurl=https://mirrors.tuna.tsinghua.edu.cn/mongodb/yum/el7-$version/
gpgcheck=0
enabled=1

EOF
    done
    yum makecache
    yum install mongodb-org -y

	echo "-------mongodb初始化安装完成-------"
}

#安装docker
function install_docker() {
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sed -i "s@https://download.docker.com@https://mirrors.aliyun.com/docker-ce@g"  /etc/yum.repos.d/docker-ce.repo
    yum install docker-ce -y
    systemctl start docker
	#配置国内docker加速器
	cat > /etc/docker/daemon.json <<- "EOF"
{
  "registry-mirrors": ["https://registry.docker-cn.com"]
}
EOF
	systemctl enable docker
    systemctl restart docker
	
	echo "-------docker初始化安装完成-------"
}


# 如果不指定参数，则执行默认功能模块
if [[ -z $* ]]; then
    firewall_config
    config_mirror_and_update
    kernel_config
    user_add
    install_jdk_and_tomcat
    install_salt_minion
fi

for arg in $* ; do
    case ${arg} in
    hostname)
    hostname_config
    ;;
	firewall)
    firewall_config
    ;;
    kernel)
    config_mirror_and_update
    kernel_config
    ;;
    user)
    user_add
    ;;
    dns)
    dns_config
    ;;
    java)
    install_jdk_and_tomcat
    ;;
    salt)
    install_salt_minion
    ;;
    zabbix)
    install_zabbix_agent
    ;;
    mysql)
    install_mysql_and_config
    ;;
    mongodb)
    install_mongodb
    ;;
    docker)
    install_docker
    ;;
    esac
done
