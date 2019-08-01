
#############################################################
# Zabbix LDD for Flume Instances via HTTP
#############################################################
# Author Valeriy Soloviov <weldpua2008@gmail.com> 
#  - 3.1.2018
#############################################################
if [[ " ${ARGS[@]} " =~ " debug " ]]; then
    set -x
fi
get_vmemory_consumption_instance() {
     echo $(ps --pid $1 -o pcpu,rss,vsize 2> /dev/null | awk '{ total += $3; count++ } END { printf("%.0f\n",total*1024) }')
}
get_memory_consumption_instance() {
     echo $(ps --pid $1 -o pcpu,rss,vsize 2> /dev/null | awk '{ total += $2; count++ } END { printf("%.0f\n",total*1024) }')
}
echo -n '{"data":['
for PID in $(ps --no-headers -eo "%p %c %a"|grep '[f]lume.monitoring.port'|grep -v grep | awk '{print $1}');do
    METRICS_PORT=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'flume.monitoring.port=[0-9]+' | grep -Eo '[0-9]+')
    [[ "${METRICS_PORT}" = "" ]] && continue
    INSTANCE=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'name [a-Z]+'|grep -Eo '[a-Z]+$')
    [[ "${INSTANCE}" = "" ]] && continue 
    CONF=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'conf-file [^ ]+'|grep -Eo '[^ ]+$')
    MONITORING_TYPE=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'flume.monitoring.type[^ ]+'|grep -Eo '[^= ]+$'|tr '[A-Z]' '[a-z]')
    METRICS_HOST="localhost"
    METRICS_URI='/metrics'
    echo -n '{'
    echo -n '"{#FLUME_INSTANCE}":"'$INSTANCE'",'
    echo -n '"{#FLUME_METRICS_HOST}":"'$METRICS_HOST'",'
    echo -n '"{#FLUME_METRICS_URI}":"'$METRICS_URI'",'  
    echo -n '"{#FLUME_METRICS_PORT}":"'$METRICS_PORT'",'  
    echo -n '"{#FLUME_CONF}":"'$CONF'",'
    echo -n '"{#FLUME_MONITORING_TYPE}":"'$MONITORING_TYPE'",'
    echo -n '"{#FLUME_INSTANCE_PID}":"'$PID'"'  
    echo -n '},'  
done| sed -e 's:\},$:\}:'
echo -n ']}'
echo ''

#获取本机ip地址
IPADDR=`ifconfig |grep team0 -A 1|grep inet|awk '{print $2}'`
if [ "$IPADDR" =  "" ]
then
    IPADDR=`ifconfig |grep bond0 -A 1|grep inet|awk '{print $2}'|awk -F':' '{print $2}'`
fi
if  [ "$IPADDR" =  "" ]
then
    IPADDR=`/sbin/ifconfig | grep 'inet ' | awk '{print $2}' | sed -e '/127\.0\.0\.1/d' | head -n 1`
fi
echo "服务器IP地址：$IPADDR"
echo "------------------------"

#统计tomcat进程
#ps -ef | grep java | grep -v grep | grep "org.apache.catalina.startup.Bootstrap start" | grep -o "Dcatalina.home.*" | awk '{print substr($1,16)}'
TOMCAT_NUMBER=`ps -ef | grep java | grep -v grep | grep "org.apache.catalina.startup.Bootstrap start" | grep -o "Dcatalina.home.*" | awk '{print substr($1,16)}' | wc -l`


display_status (){
	for TOMCAT_PATH in $(ps -ef | grep java | grep -v grep | grep "org.apache.catalina.startup.Bootstrap start" | grep -o "Dcatalina.home.*" | awk '{print substr($1,16)}');do
        echo  $TOMCAT_PATH
        if [ -d "${TOMCAT_PATH}/sslkey" ];then
          echo "存在${TOMCAT_PATH}/sslkey目录"
          ls -al ${TOMCAT_PATH}/sslkey
          md5sum  ${TOMCAT_PATH}/sslkey/haiernet.crt | awk '{print $1}'
          md5sum  ${TOMCAT_PATH}/sslkey/haiernet.key | awk '{print $1}'
          md5sum  ${TOMCAT_PATH}/sslkey/haiernet-chain.crt | awk '{print $1}'
        else
          echo "不存在${TOMCAT_PATH}/sslkey目录"
        fi
    echo -e '\n'
    done
    echo "------------------------"
    echo "$tomcat_number个tomcat进程"
}



install_certbot () {
    if [[ ! -f /usr/local/bin/certbot-auto ]]; then
        wget https://dl.eff.org/certbot-auto -P /usr/local/bin
        chmod a+x $CERTBOT_BIN
    fi
}


#替换ssl证书
renew_ssl () {
    ${CERTBOT_BIN} renew  > /tmp/crt.txt
    cat /tmp/crt.txt | grep "No renewals

#重启tomcat
restart_tomcat () {

}
