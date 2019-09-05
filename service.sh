#!/bin/sh
# Description: 
# parameters:
usage() {
	ERROR_INFO=$@
	USAGE_LINE="Usage: `basename $0` { command [option] }"
	
	echo ""
	echo "${ERROR_INFO}"
	echo ""
	echo "${USAGE_LINE}"
	echo ""
	echo "Supported command and option are: "

	cat << !EOF

   Option:
      start             - start the ${APP_NAME} specified by deployment file
      stop              - stop the ${APP_NAME} specified by deployment file
      restart           - restart the ${APP_NAME} specified by deployment file
      status            - display the state of the ${APP_NAME} on current server
   E.g.
      ${PROGNAME} start
      ${PROGNAME} stop
      ${PROGNAME} restart
      ${PROGNAME} status
!EOF
}




printLog() {
	str="`date +'%a %b %e %T %Z %Y'`\t$1\t$2\n"
	if [ "$STDOUT_LOG" != "" ];  then
		printf "$str" >> "${STDOUT_LOG}"
	fi
}
logInfo() {
	printLog "INFO" "$1";
}

logError() {
	printLog "ERROR" "$1";
}

echoLog() {
	echo "$1"
	logInfo "$1"
}

#
# Description: Check if processes are running and print which process is running
# return 1 if process is running, 0 no process running
isAppRunning() {
	retValue=0
	$PS_CMD | grep $APP_MAIN_CLASS | grep $PROCESS_ID | grep -vw grep >> /dev/null
	if [ $? -eq 0 ]; then
		retValue=1
	else
		retValue=0
	fi
	
	return $retValue
}

#
# Description: This function handle the start command 
# parameters:
# 1) option - the node deployment file
#
handle_start_command() {
	NODE_DEPLOYMENT=$1
	isAppRunning 2>&1 >> ${STDOUT_LOG}
	if [ $? -eq 1 ]; then
		echoLog "$APP_NAME is already running!"
		return;
	fi

	echoLog "Starting $APP_NAME services..."
	
	"$JAVA_CMD" $OPTIONS -cp $JAR_FILES $APP_MAIN_CLASS $ARGS > $APP_HOME/log/main_thread_$PROCESS_ID.log 2>&1 &

	# Capture process pid. do we need to check
	APP_PROCESS_PID=$!
	sleep 5
	isAppRunning 2>&1 >> ${STDOUT_LOG}
	if [ $? -eq 1 ]; then
		echoLog "$APP_NAME services started!"
		return;
	fi
}

#
# Description: This function handle the stop command 
# parameters: NA
#
handle_stop_command() {
	isAppRunning 2>&1 >> ${STDOUT_LOG}
	if [ $? -eq 0 ]; then
		echoLog "$APP_NAME is not running"
		return;
	fi
	
	echoLog "Stopping $APP_NAME services..."
	# kill services processes. There may be multiple service processes
	list=""
	#for pid in `$PS_CMD | grep '$APP_MAIN_CLASS' | grep -v grep | $AWK_CMD '{print $2}'`
	for pid in `$PS_CMD | grep $APP_MAIN_CLASS | grep $PROCESS_ID | grep -v grep | $AWK_CMD '{print $2}'`
	do
		list="${list} ${pid}"
	done
	#kill -9 $list 2>/dev/null
	kill $list 2>/dev/null
	echoLog "$APP_NAME services stopped!"
}

#
# Description: print out sca processes 
#
handle_status_command() {
	echoLog "Checking $APP_NAME status..."
	isAppRunning
	if [ $? -eq 0 ]; then
		echoLog "$APP_NAME is not running"
	else
		echoLog "$APP_NAME is running"
	fi
}


###############################################################################
# MAIN starts here.
#
# This script is used to start and stop the processes as well as 
# get status and version number information.
#
###############################################################################
APP_NAME="CD Server"
PROGNAME=`basename $0`

# Get JAVA execution environment
JAVA_CMD=$JAVA_HOME/bin/java
if [ "$JAVA_HOME" = "" ]; then
  logInfo "Please set the JAVA_HOME environment variable to the JDK directory"
  logInfo "For example %JAVA_HOME=/usr/java;export JAVA_HOME"
  logInfo "WARNING: default java will be used"
  JAVA_CMD=java
fi

# Resolve links - $0 may be a softlink
PRG="$0"
logInfo "Start to execute $PRG"
while [ -h "$PRG" ]; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '.*-> \(.*\)$'`
    if expr "$link" : '.*/.*' > /dev/null; then
      PRG="$link"
    else
      PRG=`dirname "$PRG"`/"$link"
    fi
done
APP_HOME=`dirname "$PRG"`
cd "$APP_HOME/.."
APP_HOME=`pwd`
logInfo "The application directory is $APP_HOME"



#Get the user who is executing the appliation
#INVOKER=`id | awk '{ split($opt, a, "("); split(a[2], b, ")"); print b[1] }'`
INVOKER=`whoami`
logInfo "User $INVOKER is executing application."

APP_MAIN_CLASS="com.hshbic.cloud.coreapplication.ServerApplication"
LOG_CONFIG=logback.xml
APP_CONFIG=app-spring-dubbo.xml

PS_CMD="/bin/ps -ef"
AWK_CMD="awk"

#check if it's not in design env. If WINDOWNS is true, it's development enviroment.


OS_CYGWIN=false;
OS_MINGW=false;
OS_SOLARIS=false;
OS_LINUX=false;

case "`uname`" in
CYGWIN*) OS_CYGWIN=true;;
MINGW32_NT*) OS_MINGW=true;;
SunOS) OS_SOLARIS=true;;
Linux) OS_LINUX=true;;
esac
# by pass the user validation on Windows.
if $OS_CYGWIN -o $OS_MINGW; then
	logInfo "The application is running on Windows."
fi

if $OS_SOLARIS; then
	logInfo "The application is running on SunOS."
	PS_CMD="/usr/ucb/ps -auxwww"
	AWK_CMD="/usr/xpg4/bin/awk"
fi

if $OS_LINUX; then
	logInfo "The application is running on Linux."
fi


#check if the file exists. if exists, check the write and read permission
logInfo "Checking if ${APP_NAME} is installed properly."
if [ ! -d "$APP_HOME/cfg" ]; then
    echoLog "ERROR: The directory $APP_HOME/cfg does not exist."
    exit 1
fi

if [ ! -d "$APP_HOME/lib" ]; then
    echoLog "ERROR: The directory $APP_HOME/lib does not exist."
    exit 1
fi

if [ ! -d "$APP_HOME/log" ]; then
    echoLog "ERROR: The directory $APP_HOME/log does not exist."
    # echoLog "Continue to execute the application. Logs will not be stored on disk."
    exit 1
fi

if [ ! -w "$APP_HOME/log" ]; then
    echoLog "WARN: The user $INVOKER has no write permission on the directory $APP_HOME/log."
    # logInfo "Continue to execute the application. Logs will not be stored on disk."
    exit 1
fi
logInfo "The log directory location is $APP_HOME/log."


JAR_FILES=$APP_HOME:$APP_HOME/lib/*

CLASSPATH=$APP_HOME
for file in $APP_HOME/lib/*.jar; do
    CLASSPATH=$CLASSPATH:$file
done


#Verify paramters passed in to the script
if [ $# -lt 1 ]; then
	usage "ERROR: One parameter is required as follows:"
	exit 1
fi

COMMAND=$1

CFG_FILE="$APP_HOME/dport.txt"
if [ ! -r "$CFG_FILE" ]; then
    echoLog "ERROR: The important file $CFG_FILE does not exist."
    exit 1
fi

APP_DUBBO_PORT=`cat $CFG_FILE | grep dubbo.port | awk -F= '{print $2}'`
if [ ! "$APP_DUBBO_PORT" ]; then
    echoLog "ERROR: The $CFG_FILE does not has the key of dubbo.port as dubbo service port."
    exit 1
fi
expr $APP_DUBBO_PORT+1 &>/dev/null
TEST_PORT=$?
if [ ! $TEST_PORT -eq 0 ]; then
    echoLog "ERROR: The dubbo.port:$APP_DUBBO_PORT must be a number."
    exit 1
fi

SPRING_PROFILE=`cat $CFG_FILE | grep coredata.profiles | awk -F= '{print $2}'`
if [ ! "$SPRING_PROFILE" ]; then
    echoLog "ERROR: The $CFG_FILE does not has the key of coredata.profiles as coredata services profiles."
    exit 1
fi

PROCESS_ID="CD$APP_DUBBO_PORT"
ARGS="PROCESS_ID=$PROCESS_ID"

#OPTIONS="$OPTIONS -XX:+UseParallelGC -XX:+UseAdaptiveSizePolicy"
OPTIONS="$OPTIONS -XX:+UseConcMarkSweepGC -XX:+UseCMSCompactAtFullCollection -XX:CMSFullGCsBeforeCompaction=1"
OPTIONS="$OPTIONS -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$APP_HOME/log/coreDataHeapDump.hprof"
OPTIONS="$OPTIONS -server -Xms2048m -Xmx2048m -XX:PermSize=128m -XX:MaxPermSize=320m"
OPTIONS="$OPTIONS -DAPP_HOME=$APP_HOME -DLOG_CONFIG=$LOG_CONFIG -DAPP_CONFIG=$APP_CONFIG -DAPP_PROCESS_ID=$PROCESS_ID -Dspring.profiles.active=$SPRING_PROFILE -Ddubbo.port=$APP_DUBBO_PORT"
#OPTIONS="$OPTIONS -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=17166"
OPTIONS="$OPTIONS -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:$APP_HOME/log/cd_gc_$PROCESS_ID.log"


# print standout to the txt file for debug
TIME_NOW=`date '+%y%m%d%H%M%S'`
STDOUT_LOG="$APP_HOME/log/debug.$PROGNAME.$$.${TIME_NOW}.stdout_$PROCESS_ID.log"

logInfo "CONFIG=$LOG_CONFIG . HOME=$APP_HOME . CONFIG=$APP_CONFIG . PROCESS_ID=$PROCESS_ID . port=$APP_DUBBO_PORT"

logInfo "java $OPTIONS -cp $JAR_FILES $APP_MAIN_CLASS $ARGS > $APP_HOME/log/main_thread_$PROCESS_ID.log"

case $COMMAND in
	"start" )
		handle_start_command $OPTION
		;;
	"stop" )
		handle_stop_command $OPTION
		;;
	"restart" )
		handle_stop_command $OPTION
		sleep 5
		handle_start_command $OPTION
		;;
	"status" )
		handle_status_command
		;;
	* )
		# shoul not get here
		usage "ERROR: Invalid command option."
		;;
esac
