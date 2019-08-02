#!/bin/bash

#编辑开始
ZABBIX_REPO_VERSION='3.4'
#zabbix server
ZBX_SERVER='10.159.59.3'
ZABBIX_AGENT_VERSION='3.4.11'
#编辑结束

LOCALIP=$(ip a |grep -E "team0$|bond0$|eth0$|ens160$" |grep "inet" |awk '{print $2}' |awk -v FS="/" '{print $1}')
OS_VERSION=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`

配置repo源
config_repo (){
    wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX-A14FE591 https://mirrors.aliyun.com/zabbix/RPM-GPG-KEY-ZABBIX-A14FE591

    cat > /etc/yum.repos.d/zabbix.repo <<EOF
[zabbix]
name=Zabbix Official Repository - \$basearch
baseurl=https://mirrors.aliyun.com/zabbix/zabbix/xxx/rhel/---/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX-A14FE591
EOF

    sed -i "s/xxx/$ZABBIX_REPO_VERSION/g" /etc/yum.repos.d/zabbix.repo
    sed -i "s/---/$OS_VERSION/g" /etc/yum.repos.d/zabbix.repo
}

# remove zabbix-agent
remove_agent () {
    rpm -q zabbix-agent &>/dev/null && ZBXA=1 || ZBXA=0
    if [ $ZBXA == 1 ];then
        service zabbix-agent stop &>/dev/null
        yum -y remove zabbix-agent zabbix-sender &>/dev/null && echo "----zabbix-agent zabbix-sender remove seccessed.----" || echo "----zabbix-agent zabbix-sender remove failed.----"
        rm -f /var/log/zabbix/*
        rm -f /etc/zabbix/bin/*    
    else
        echo "---no zabbix-agent installed.---"
    fi
}


# install zabbix-agent
install_agent () {
    rpm -q zabbix-agent &>/dev/null && ZBXA=1 || ZBXA=0
    if [ $ZBXA == 0 ];then
        yum install zabbix-agent-$ZABBIX_AGENT_VERSION
    else
        echo -e "----$(rpm -q zabbix-agent) already installed.----"
    fi
}


# config zabbix-agent
config_agent () {
    mv /etc/zabbix/zabbix_agentd.conf{,.ori.$(date +%F)}
cat > /etc/zabbix/zabbix_agentd.conf <<EOF
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=1024
Server=$ZBX_SERVER
ServerActive=$ZBX_SERVER
Hostname=$LOCALIP
Timeout=10
Include=/etc/zabbix/zabbix_agentd.d/*.conf 
UnsafeUserParameters=1
EOF
    echo "----zabbix_agentd.conf update successed.-----"
}

# config zabbix-agent tcp status
config_tcp_status () {
    if [ ! -f $TCPCONF ];then
        wget --directory-prefix=/etc/zabbix/zabbix_agentd.d $TCPCONF &>/dev/nulll && echo "----userparameter_tcp.conf download successed.----" || echo "----userparameter_tcp.conf download failed.----"
    fi
}

# mkdir bin
mkdir_bin () {
    if [ ! -d /etc/zabbix/bin ];then
        mkdir /etc/zabbix/bin
    fi
}

# chmod
chmod_dir () {
    chown -R zabbix:zabbix /etc/zabbix
}

# start zabbix-agent
start_agent () {
    if [ $OS_VERSION == 7 ];then
        # start zabbix-agent
        systemctl restart zabbix-agent &>/dev/null && echo "----zabbix-agent start successed.----" ||echo "----zabbix-agent start failed.----"
        systemctl enable zabbix-agent &>/dev/null
    elif [ $OS_VERSION == 6 ];then
        # start zabbix-agent
        service zabbix-agent restart &>/dev/null && echo "----zabbix-agent start successed.----" ||echo "----zabbix-agent start failed.----"
        chkconfig zabbix-agent on &>/dev/null
    else
        echo "----OS not support! Exiting...----"
    fi    
}

# zabbix-agent crontab
config_crontab () {
    if [ ! -f /etc/zabbix/bin/zabbix-crontab.sh ];then
            wget --directory-prefix=/etc/zabbix/bin $ZCRON &>/dev/null && echo "----zabbix-crontab.sh download successed.----" || echo "----zabbix-crontab.sh download failed.----"
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
}


#main
echo "----Start.----"        

install_apps
remove_agent
install_agent
config_agent
config_tcp_status
chmod_dir
start_agent
mkdir_bin
config_crontab
chmod_dir

echo "----All Done.----"        
