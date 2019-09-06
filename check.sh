#!/bin/bash


d=$(date --iso)
#检验证书有效期到期时间，目前还没做判断是否到期
CHECKURL='10.159.59.11:6423'
check_cert (){
  not_after=$(echo | openssl s_client -showcerts -connect $CHECKURL 2>/dev/null | openssl x509 -inform pem -noout -text 2>/dev/null | grep 'Not After')
  #echo | openssl s_client -showcerts -connect $CHECKURL 2>/dev/null | openssl x509 -inform pem -noout -text 2>/dev/null
  if [ $? -eq 0 ] ; then
    ts=$( echo $not_after | cut -f2- -d: | sed -e 's/^ \+//g' )
    echo $ts
    echo | openssl s_client -showcerts -connect $CHECKURL 2>/dev/null | openssl x509 -inform pem -noout -text 2>/dev/null | grep -i Issuer: | cut -f2- -d: | sed -e 's/^ \+//g'
  else
    echo Fatal: Failed to fetch certs for $CHECKURL 1>&2
  fi
}

TOMCAT_PATH='/apps/udsecb/udsecb-tomcat-6420/'
#把后面的斜杠取消
TOMCAT_PATH=$(echo ${TOMCAT_PATH%*/})
#检查进程是否存在，然后检查sslkey目录是否存在
check_path () {
  SIG=$(ps -ef | grep java | grep -v grep | grep "org.apache.catalina.startup.Bootstrap start" | grep $TOMCAT_PATH)
  if [ $? -eq 0 ] ; then
    if [ -d "${TOMCAT_PATH}/sslkey" ];then
       echo "存在${TOMCAT_PATH}/sslkey目录"
    else
       echo "不存在${TOMCAT_PATH}/sslkey目录,退出脚本"
       exit 1
    fi
  else
    echo '该tomcat进程不存在，退出'
    exit 1
  fi
}

install_newcert () {
  CERT_NAME=$(cat ${TOMCAT_PATH}/conf/server.xml | grep SSLCertificate | grep -v grep | grep -o "sslkey.*" | cut -d '/' -f 2 | cut -d '"' -f 1)
  if [ $? -eq 0 ] ; then
    echo 'tomcat配置文件存在ssl'
  else
    echo 'tomcat配置文件不存在ssl,退出'
    exit 1
  fi
  #cat ${TOMCAT_PATH}/conf/server.xml | grep SSLCertificate | grep -v grep
  #证书文件
  cert_file=$(cat ${TOMCAT_PATH}/conf/server.xml | grep SSLCertificateFile | grep -v grep | grep -o "sslkey.*" | cut -d '/' -f 2 | cut -d '"' -f 1)
  echo $cert_file
  #mv ${TOMCAT_PATH}/sslkey/$cert_file ${TOMCAT_PATH}/sslkey/$cert_file-$d
  #wget 证书下载地址 -O ${TOMCAT_PATH}/sslkey/$cert_file 
  #私钥文件
  key_file=$(cat ${TOMCAT_PATH}/conf/server.xml | grep SSLCertificateKeyFile | grep -v grep | grep -o "sslkey.*" | cut -d '/' -f 2 | cut -d '"' -f 1)
  #mv ${TOMCAT_PATH}/sslkey/$key_file ${TOMCAT_PATH}/sslkey/$key_file-$d
  #wget 私钥下载路径 -O ${TOMCAT_PATH}/sslkey/$key_file
  echo $key_file
  #中继证书
  chain_file=$(cat ${TOMCAT_PATH}/conf/server.xml | grep SSLCertificateChainFile | grep -v grep | grep -o "sslkey.*" | cut -d '/' -f 2 | cut -d '"' -f 1)
  if [ "$chain_file" =  "" ]
  then
    echo '中继证书不存在'
  else
    #mv ${TOMCAT_PATH}/sslkey/$chain_file ${TOMCAT_PATH}/sslkey/$chain_file-$d
    #wget  中继证书下载地址 -O ${TOMCAT_PATH}/sslkey/$chain_file
  fi
}

check_cert
check_path
install_newcert
