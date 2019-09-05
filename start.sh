#!/bin/bash
source /etc/profile
date=$(date +%Y%m%d_%H%M | awk '{print $1}')
dir=$( find $1 -name 'coredata-206*' -type d)
warfile=$1
bakup=$1/backup



        for file in ${dir}
        do
                ps -ef | grep ${file} | grep -v grep | awk '{print $2}' | while read pid
                 do
                        echo "进程号为:${pid}"
                        kill -9 ${pid}
                        echo "${file}进程已停"
                done

                unzip -o  ${warfile}/install/coredata-App.zip -d ${file}
                sleep 3

               sh ${file}/bin/service.sh  start
              echo "${file}启动完成"
#


        done

        mv ${warfile}/install/coredata-App.zip ${bakup}/coredata-App.zip_${date}
        echo "coredata 备份完成"

