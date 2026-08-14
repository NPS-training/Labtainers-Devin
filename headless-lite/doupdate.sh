cd $LABTAINER_DIR/..
echo "doing update of labtainer $(date)" >/tmp/update.log
wget --quiet https://github.com/mfthomps/Labtainers/releases/latest/download/labtainer.tar -O labtainer.tar >>/tmp/update.log 2>&1
result=$?
if [[ $result -ne 0 ]];then
    echo "Failed retrieving labtainer.tar from github, see /tmp/update.log.  Network problems?  Maybe try again."
    exit 1
fi
sync
cd ..
if [[ ! -s labtainer/labtainer.tar ]]; then
    echo "The labtainer.tar file is missing or empty, see /tmp/update.log.  Please try the update again."
    exit 1
fi
tar tf labtainer/labtainer.tar >>/tmp/update.log 2>&1
result=$?
if [[ $result -ne 0 ]];then
    echo "The labtainer.tar file is not a valid tar, see /tmp/update.log.  The download may have"
    echo "been truncated.  Please try the update again."
    exit 1
fi
tar xf labtainer/labtainer.tar --keep-newer-files --warning=none >>/tmp/update.log 2>&1
sleep 1
