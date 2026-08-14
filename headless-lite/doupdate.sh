#!/bin/bash
#
# Runs in an xterm that closes when this script exits, so pause after reporting
# a failure to leave the reason on the screen.
#
update_failed() {
    echo "$@"
    sleep 60
    exit 1
}
cd $LABTAINER_DIR/..
echo "doing update of labtainer $(date)" >/tmp/update.log
wget --quiet https://github.com/mfthomps/Labtainers/releases/latest/download/labtainer.tar -O labtainer.tar >>/tmp/update.log 2>&1
result=$?
if [[ $result -ne 0 ]];then
    update_failed "Failed retrieving labtainer.tar from github, see /tmp/update.log.  Network problems?  Maybe try again."
fi
sync
cd ..
if [[ ! -s labtainer/labtainer.tar ]]; then
    update_failed "The labtainer.tar file is missing or empty, see /tmp/update.log.  Please try the update again."
fi
tar tf labtainer/labtainer.tar >>/tmp/update.log 2>&1
result=$?
if [[ $result -ne 0 ]];then
    update_failed "The labtainer.tar file is not a valid tar, see /tmp/update.log.  The download may have been truncated.  Please try the update again."
fi
tar xf labtainer/labtainer.tar --keep-newer-files --warning=none >>/tmp/update.log 2>&1
sleep 1
