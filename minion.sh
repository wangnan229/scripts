#!/bin/bash

rpm -qa | grep salt-minion-2019
if [ $? -eq 0 ]
then
    echo "已经安装salt-minion-2019现在退出"
    exit 1
else
    echo "开始安装"
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
    ipaddr=`/sbin/ifconfig | grep 'inet ' | awk '{print $2}' | sed -e '/127\.0\.0\.1/d'`
fi
echo "服务器IP地址：$ipaddr"



if [ $v -eq 6 ];then
    echo "-------执行Centos6 salt安装-------"
	yum clean all
	wget -O /etc/yum.repos.d/salt.repo wget http://resource.haier.net/download/init/salt/salt6.repo
	wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo
	wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-6.repo
	yum makecache
	yum install -y salt-minion
	sed -i 's/^master.*/#&/' /etc/salt/minion
	sed -i 's/^id.*/#&/' /etc/salt/minion
	rm -f  /etc/salt/pki/minion/*
	cat >> /etc/salt/minion << EOF
master: 10.159.32.200
id: $ipaddr
EOF
	chkconfig salt-minion on
	echo "重启salt-minion"
	service salt-minion restart
fi

if [ $v -eq 7 ];then
	echo "-------执行Centos7 salt安装-------"
	yum clean all
	wget -O /etc/yum.repos.d/salt.repo wget http://resource.haier.net/download/init/salt/salt7.repo
	wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
	wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
	yum makecache
	yum install -y python2-certifi
	yum install -y salt-minion
    sed -i 's/^master.*/#&/' /etc/salt/minion
    sed -i 's/^id.*/#&/' /etc/salt/minion
    rm -f  /etc/salt/pki/minion/*
    cat >> /etc/salt/minion << EOF
master: 10.159.32.200
id: $ipaddr
EOF
	systemctl enable salt-minion
	echo "重启salt-minion"
	systemctl restart salt-minion
fi
echo "-------Saltstack Minion初始化完成-------"
