#!/bin/bash
# desc: CentOS initialization
# Author: SuperC25
# Mail: superchao25@gmail.com
# Last Update: 2019.05.08
#=================================================================

#-------*****************-------
#--1--此脚本需要root用户执行
#--2--需要有/apps 和 /export 目录
#--3--而且/apps jdk放在此目录中
#--4--并且确认yum不要有什么后台进程在运行
#--5--ifconfig和wget命令可以使用
#--6--最好先确定有没有安装openjdk的rpm包
#-------*****************-------


cat << EOF
 +--------------------------------------------------------------+  
 |              === Welcome to  System init ===                 |  
 +--------------------------------------------------------------+  
EOF

echo -e "\033[31m 这个是Centos系统初始化脚本，请慎重运行！ press ctrl+C to cancel \033[0m"

##############从此处开始需要编辑###########

#统一使用生产资源服务器下的jdk和tomcat，默认初始化jdk1.7.0_60，jdk使用的jdk1.8.0_172
JDK7_PATH='http://39.106.253.153/ziyuan/file/jenkins/jdk1.7.tar.gz'
JDK8_PATH='https://resource.haier.net/download/init/java/jdk1.8.tar.gz'

#DNS设置
DNS1="10.159.32.205"
DNS2="10.159.32.203"
#DNS1='114.114.114.114'
#DNS2='8.8.8.8'
DNS3='192.168.100.1'
DNS4='192.168.100.2'

#salt master地址
SALT_MASTER='10.159.32.200'

#主机名
HOSTNAME="node-01"

##############从此处开始停止编辑###########

#判断是否为root用，platform是否为X64
if  [ $(id -u) -gt 0 ]; then
    echo "please use root run the script!"
    exit 1
fi
platform=`uname -i`
osversion=`cat /etc/redhat-release | awk '{print $1}'`
if [[ $platform != "x86_64" ||  $osversion != "CentOS" ]];then
    echo "Error this script is only for 64bit and CentOS Operating System !"
    exit 1
fi
    echo "The platform is ok"

sleep 3

#判断是否存在/apps和/export/apps目录，没有的话退出
if [[ -d /apps && -d /export ]]
then
	echo "OK /apps and /export is fine"
else
	echo 'Sorry. you do not have a /apps and /export directory'
	exit 1
fi

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
	ipaddr=`/sbin/ifconfig | grep 'inet ' | awk '{print $2}' | sed -e '/127\.0\.0\.1/d' | head -n 1`
  fi
echo "服务器IP地址：$ipaddr"

#
function hostname_config() {
	#hostnamectl set-hostname aaa
	if [ "$HOSTNAME" == "" ];then
		echo "The host name is empty."
		exit 1
	else     
        echo "HostName is $HOSTNAME"
        hostnamectl set-hostname $HOSTNAME
	fi
	sleep 3
	echo "-------计算机名修改完成-------"
}

function firewall_config() {
    # 禁用selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
	
	sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
	
    # 请根据具体情况来决定是否关闭防火墙
    if [ $v -eq 6 ];then
		echo "-------修改Centos 6 防火墙策略-------"
		/sbin/iptables -F
		service iptables start
		chkconfig iptables on
		#调整默认策略（默认拒绝所有访问，改成允许所有访问）
		iptables -P INPUT ACCEPT
		#iptables -P OUTPUT ACCEPT
		/etc/init.d/sshd  restart
	fi

	if [ $v -eq 7 ];then
		echo "-------修改Centos 7 防火墙策略-------"
		#systemctl restart firewalld.service
		#systemctl enable firewalld.service
		#调整默认策略（默认拒绝所有访问，改成允许所有访问）：
		#firewall-cmd --permanent --zone=public --set-target=ACCEPT
		#firewall-cmd --reload
		#systemctl restart sshd
		systemctl stop firewalld
		systemctl disable firewalld
	fi
	echo "-------防火墙初始化完成-------"
}

function yum_config() {
    #cd /etc/yum.repos.d/ && mkdir bak && mv -f *.repo bak/
    #wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    #wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
    #yum clean all && yum makecache
    #yum -y install iotop iftop net-tools lrzsz gcc gcc-c++ make cmake libxml2-devel openssl-devel curl curl-devel unzip sudo ntp libaio-devel wget vim ncurses-devel autoconf automake zlib-devel  python-devel bash-completion
    
    MIRROR="http://mirrors.aliyun.com"
    #更换yum源为阿里源
    cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    sed -i "s/#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-Base.repo
    sed -i "s/mirrorlist=http/#mirrorlist=http/g" /etc/yum.repos.d/CentOS-Base.repo
    sed -i "s@baseurl=.*/centos@baseurl=$MIRROR/centos@g" /etc/yum.repos.d/CentOS-Base.repo
	yum clean all
    yum makecache

    #同步时间
	timedatectl set-local-rtc 1 && timedatectl set-timezone Asia/Shanghai
        yum install -y ntpdate
	ntpdate ntp1.aliyun.com
	hwclock -w

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
	yum install -y vim telnet unzip tcpdump sysstat gcc gdb wget iotop iftop traceroute tomcat-native cronolog lrzsz apr lsof nmap
	
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
*           soft   nofile       102400
*           hard   nofile       102400
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
        NEWUSER="uplus"
	PASS="rOXFJZhiaACE"
	id $NEWUSER
	if [ $? -eq 0 ] ; then
		echo "$NEWUSER账户已存在，无法创建!"
	else
		useradd $NEWUSER
		echo $PASS | passwd --stdin $NEWUSER
		if [ $? -eq 0 ] ; then
			echo "$NEWUSER账户创建成功！"
			sed -i "/^root/a$NEWUSER\tALL=(ALL)\tNOPASSWD: ALL" /etc/sudoers
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

	echo "-------系统用户、目录初始化完成-------"
}

#关闭图形界面
close_gui(){
    systemctl set-default multi-user.target
}

function dns_config() {
	#请根据各环境进行配置
	cat > /etc/resolv.conf <<EOF
nameserver $DNS1
nameserver $DNS2
nameserver $DNS3
nameserver $DNS4
EOF
	echo "dns初始化配置完成"
}

#安装jdk和tomcat
function install_jdk_and_tomcat() {
    rpm -qa | grep openjdk | xargs yum remove -y
	#统一使用生产资源服务器下的jdk和tomcat，默认初始化jdk1.7.0_60，jdk使用的jdk1.8.0_172

    cd /apps
    wget -O /apps/jdk1.7.tar.gz $JDK7_PATH
    wget -O /apps/jdk1.8.tar.gz $JDK8_PATH
    #wget https://resource.haier.net/download/java/tomcat8.5.tar.gz
    #curl @jenkins-res.uhome.haier.net:60021/ops/deploy_tomcat.sh">ftp://ftpuser:RwtgwZPj@jenkins-res.uhome.haier.net:60021/ops/deploy_tomcat.sh | bash /dev/stdin 750"
    #curl @jenkins-res.uhome.haier.net:60021/ops/deploy_tomcat8.sh">ftp://ftpuser:RwtgwZPj@jenkins-res.uhome.haier.net:60021/ops/deploy_tomcat8.sh | bash /dev/stdin 750"
    tar -xf /apps/jdk1.7.tar.gz -C /apps/
    tar -xf /apps/jdk1.8.tar.gz -C /apps/
    chown -hR cloud-user:cloud-user /apps/jdk1.7.0_60
    chown -hR cloud-user:cloud-user /apps/jdk1.8
			cat >> /etc/profile << EOF
export JAVA_HOME=/apps/jdk1.7.0_60
export PATH=\$JAVA_HOME/bin:\$PATH
export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar
EOF

    source /etc/profile
    rm -f /apps/jdk1.7.tar.gz /apps/jdk1.8.tar.gz
    echo "-------JDK、TOMCAT初始化完成-------"
}

#安装salt-minion 2019-02最新版本
function install_salt_minion() {
	#服务端域名：salt.haier.net
	if [ $v -eq 6 ];then
	    echo "-------执行Centos6 salt安装-------"
		yum install -y https://repo.saltstack.com/yum/redhat/salt-repo-latest.el6.noarch.rpm
		sed -i "s/repo.saltstack.com/mirrors.aliyun.com\/saltstack/g" /etc/yum.repos.d/salt-latest.repo
		yum install -y salt-minion-2019.2.0
		sed -i 's/^master.*/#&/' /etc/salt/minion
		sed -i 's/^id.*/#&/' /etc/salt/minion
		sleep 5
		cat >> /etc/salt/minion << EOF
master: $SALT_MASTER
id: $ipaddr
EOF
		chkconfig salt-minion on
		service salt-minion 
	fi
	
	if [ $v -eq 7 ];then
		echo "-------执行Centos7 salt安装-------"
		yum install -y https://repo.saltstack.com/yum/redhat/salt-repo-latest.el7.noarch.rpm
		sed -i "s/repo.saltstack.com/mirrors.aliyun.com\/saltstack/g" /etc/yum.repos.d/salt-latest.repo
		yum install -y salt-minion-2019.2.0
		sed -i 's/^master.*/#&/' /etc/salt/minion
		sed -i 's/^id.*/#&/' /etc/salt/minion
		sleep 5
		cat >> /etc/salt/minion << EOF
master: $SALT_MASTER
id: $ipaddr
EOF
		systemctl enable salt-minion
		systemctl restart salt-minion
	fi
	echo "-------Saltstack Minion初始化完成-------"
}

#关闭图形界面
function dirblong(){
    chown cloud-user.cloud-user /apps
    chown cloud-user.cloud-user /export
    chmod 777 /apps
    chmod 777 /export
}

#所有的配置
#    hostname_config
#    firewall_config
#    yum_config
#    kernel_config
#    dns_config
#    user_add
#    close_gui
#    install_jdk_and_tomcat
#    install_salt_minion

main(){
    user_add
    firewall_config
    yum_config
    kernel_config
    install_jdk_and_tomcat
    install_salt_minion
    dirblong
    dns_config
}
main

cat << EOF
 +--------------------------------------------------------------+  
 |                === System init Finished ===                  |  
 +--------------------------------------------------------------+  
EOF
sleep 3
echo "Please reboot your system!"
