#! /bin/sh -e
### BEGIN INIT INFO
# hyperboria.sh - An init script (/etc/init.d/) for cjdns
# Provides:          cjdroute
# Required-Start:    $remote_fs $network
# Required-Stop:     $remote_fs $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Cjdns router
# Description:       A routing engine designed for security, scalability, speed and ease of use.
# cjdns git repo:    https://github.com/cjdelisle/cjdns/blob/a7350a4d6ec064f71eeb026dd4a83b235b299512/README.md
### END INIT INFO


#### NOTES:
# This is a modified version of (https://gist.github.com/3030662).
# I fixed a bunch of errors, added some commons sense, and an uninstall function.
# Download this script, edit if necessary and save it to your computer.
# You can run the script
# sh hyperboria.sh (start|stop|restart|status|flush|update|install|delete)
# Suggested script install:
# I recommend that you create a soft link in your /etc/init.d/ folder, for example run:
#
# sudo ln -s /path/to/script/hyperboria.sh /etc/init.d/cjdns
#
# Then you can run the following in terminal with one of the choices below:
#
# sudo /etc/init.d/cjdns (start|stop|restart|status|flush|update|install|delete)
#
# Install cjdns (download hyperboria.sh)
# Run in terminal:
# sudo ln -s /path/to/script/hyperboria.sh /etc/init.d/cjdns
# chmod +x /etc/init.d/cjdns
# sudo /etc/init.d/cjdns install
#
# Add peers when prompted (optional) and save.
# To start cjdns:
# sudo /etc/init.d/cjdns start
####

#### Notes by plambe:
# This script copies itself in /etc/init.d and runs "update-rc.d cjdns defaults". 
# Also, it uses the init-functions. 
####

PROG="cjdroute"
PROC="cjdns"
GIT_PATH="/opt/cjdns"
CJDNS_CONFIG="/etc/cjdroute.conf"
CJDNS_LOGFOLDER="/var/log/cjdns"           #if you are using /dev/null, dont change this to /dev/ or /dev/null
CJDNS_LOG="/var/log/cjdns/cjdroute.log"    # use /dev/null here if you do not want any logs. You d not need to change $CJDNS_LOGFOLDER when using /dev/null
CJDNS_USER="root"                          #see wiki about changing this user to a service user.
HYPERBORIA_PATH=`pwd`

. /lib/init/vars.sh
. /lib/lsb/init-functions

start() {
    # Start it up with the user cjdns
    log_daemon_msg "Starting cjdns router" "cjdroute"
    if [ $(pgrep $PROG | wc -l) != 0 ]; then
        log_failure_msg "Cjdns is already running. Doing nothing. "
    else
        flush
        sleep 2
        $GIT_PATH/$PROG < $CJDNS_CONFIG > $CJDNS_LOG 2>&1
        ES=$?

        # Create the PID files
        FIRST_PID=`pgrep -x $PROG | sed -n 1p`
        SEC_PID=`pgrep -x $PROG | sed -n 2p`
        FIRST_PID_NAME=`ps uh -p $(pgrep -d, -x $PROG) | awk '{print $12}' | sed -n 1p`
        SEC_PID_NAME=`ps uh -p $(pgrep -d, -x $PROG) | awk '{print $12}' | sed -n 2p`

        echo $FIRST_PID > /var/run/cjdns-$FIRST_PID_NAME.pid;
        echo $SEC_PID > /var/run/cjdns-$SEC_PID_NAME.pid;

        [ "$VERBOSE" != no ] && log_progress_msg "Started with PIDS $FIRST_PID and $SEC_PID"
        log_end_msg $ES
    fi
}

stop() {

    if [ $(pgrep $PROG | wc -l) != 2 ]; then
        log_failure_msg "Cjdns isn't running."
    else
        log_daemon_msg "Stopping cjdns router" "cjdroute"
        kill `cat /var/run/cjdns-angel.pid`
        ES1=$?
        kill `cat /var/run/cjdns-core.pid`
        ES2=$?
        if [ $ES1 != 0 ]
        then
            log_end_msg $ES1
        elif [ $ES2 != 0 ]
        then
            log_end_msg $ES2
        else
            log_end_msg 0
        fi
    fi
}

flush() {
    if [ "$(dirname $CJDNS_LOG)" = "$CJDNS_LOGFOLDER" ]; then
        [ "$VERBOSE" != no ] && log_progress_msg "Cleaning log file, leaving last 100 rows\n"
        tail -100 $CJDNS_LOG > .tmp_cjdns_log && mv .tmp_cjdns_log $CJDNS_LOG
    else
        log_progress_msg "Your log file, $(basename $CJDNS_LOG), is not in $CJDNS_LOGFOLDER, nothing will be flushed."
        log_progress_msg "If you are using /dev/null as a log file, to avoid logging, this is normal."
        log_progress_msg "If you are trying to log, please check CJDNS_LOGFOLDER and CJDNS_LOGFOLDER"
        log_progress_msg "in the script."
    fi
}

status() {
    if [ $(pgrep $PROG | wc -l) != 0 ]; then
        log_success_msg "cjdns is running"
    else
        log_success_msg "cjdns is not running"
    fi
}


update() {
    cd $GIT_PATH
    echo "Updating..."
    git pull
    echo "Building..."
    ./do
    sleep 1

}

setup() {
    echo "Create cjdns installation folder if it does not exist: $GIT_PATH."
    mkdir -p $GIT_PATH
    echo "Ensuring you have the required software: cmake make git build-essential nano"
    apt-get install -y cmake make git build-essential
    #If you dont want nano, you can delete "nano" above but you must then change "nano" below to your prefered text editor.
    echo "Cloning from github..."
    cd $GIT_PATH/../
    git clone https://github.com/cjdelisle/cjdns.git
    echo "doing it, compiling software..."
    cd $GIT_PATH
    ./do

    if [ -f $CJDNS_CONFIG ]; then #check if config file already exists.

        echo
        echo "Config file ($CJDNS_CONFIG) already exists."
        echo "To generate a new config file run:"
        echo "~:$ /opt/cjdns/cjdroute --genconf > $CJDNS_CONFIG"
        echo
        else
        echo
        echo "Could not find config file ($CJDNS_CONFIG). "
        echo "**Generating a config file ($CJDNS_CONFIG)..."
        echo
        build/cjdroute --genconf > $CJDNS_CONFIG
        echo
        echo "Configuration generated in $CJDNS_CONFIG"
     fi

    echo "Making a log dir ($CJDNS_LOGFOLDER)"
    mkdir -p $CJDNS_LOGFOLDER
    echo
    echo "You have compiled \o/! add peers to $CJDNS_CONFIG"
    echo
    cp $HYPERBORIA_PATH/hyperboria.sh /etc/init.d/cjdns
    chmod +x /etc/init.d/cjdns
    update-rc.d cjdns defaults
}

delete() {
    echo
    echo "[**WARNING**]"
    read -p "Are you SURE your want to DELETE cjdns from this system? NOTE: this will not delete the config file($CJDNS_CONFIG): (Y|y|N|n). " choice
    case "$choice" in
      y|Y )
        echo "**Stopping cjdns..."
        stop #stop cjdns
        sleep 3
        echo
        echo "**Deleting cjdns files from your system ($GIT_PATH, $CJDNS_LOGFOLDER)  "
        sleep 2
        rm -rf $GIT_PATH $CJDNS_LOGFOLDER
        echo
        echo "Your configuration file ($CJDNS_CONFIG) still exists."
        echo "You many want to keep this for later use.  You can also"
        echo "delete the soft link if you created one i.e., /etc/init.d/cjdns."
        echo
        ;;
      n|N )
        echo "**Exiting uninstall of cjdns. You have done nothing :)..."
        ;;
      * ) echo "**Invalid response. You have done nothing :)..."
        ;;
    esac

}

 ## Check to see if we are running as root first.
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

case $1 in
    start)
        start
        exit 0
    ;;
    stop)
        stop
        exit 0
    ;;
    reload|restart|force-reload)
        stop
        sleep 1
        start
        exit 0
    ;;
    status)
        status
        exit 0
    ;;
    flush)
        flush
        exit 0
    ;;
    update|upgrade)
        stop
        echo "shutting down cjdns" 1>&2
        sleep 5
        update
        sleep 5
        start
        exit 0
    ;;
    install|setup)
        setup
    ;;
    delete)
        delete
    ;;
    **)
        echo "Usage: $0 (start|stop|restart|status|flush|update|install|delete)" 1>&2
        exit 1
    ;;
esac

