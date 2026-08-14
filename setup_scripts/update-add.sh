#
# update-add.sh Migrate most update function here so that changes to this this file are updated
# before the script is sourced from the update-labtainer.sh script.
#
#
# Derive LABTAINER_DIR from the location of this script, which lives in
# <labtainer trunk>/setup_scripts, rather than assume a user or home directory.
#
if [ -z "$LABTAINER_DIR" ] || [ ! -d "$LABTAINER_DIR" ]; then
    if [ -n "${BASH_SOURCE[0]}" ]; then
        script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
        export LABTAINER_DIR=$(dirname "$script_dir")
    fi
fi
if [ -z "$LABTAINER_DIR" ] || [ ! -d "$LABTAINER_DIR/setup_scripts" ]; then
    echo "Unable to determine the labtainer directory.  Please set LABTAINER_DIR to"
    echo "the trunk directory of your Labtainers installation and try again."
    exit 1
fi
distrib=`cat /etc/*-release | grep "^DISTRIB_ID" | awk -F "=" '{print $2}'`
if [[ -z "$distrib" ]]; then
        # fedora gotta be different
        distrib=`cat /etc/*-release | grep "^NAME" | awk -F "=" '{print $2}'`
fi
RESULT=0
case "$distrib" in
    Ubuntu)
        echo is ubuntu
        release=`cat /etc/*-release | grep "^DISTRIB_RELEASE" | awk -F "=" '{print $2}'`
        #
        # Numeric comparison of the release, e.g., 18.04 becomes 1804.
        #
        release_major=$(echo "$release" | cut -d. -f1)
        release_minor=$(echo "$release" | cut -d. -f2)
        release_num=$((10#${release_major:-0} * 100 + 10#${release_minor:-0}))
        if [ $release_num -gt 1804 ] || [ $release_num -eq 0 ]; then
            source $LABTAINER_DIR/setup_scripts/update-add-new.sh
            RESULT=$?
        else
            #
            # Maintain old update hacks so old distributions (including VM image copies in horizon) still work.
            #
            source $LABTAINER_DIR/setup_scripts/update-ubuntu.sh
            RESULT=$?
        fi
        ;;
    *)
        #
        # Other distributions are not tested, but the generic update steps may work.
        #
        echo "Distribution \"$distrib\" is not tested with Labtainers, using generic update steps."
        source $LABTAINER_DIR/setup_scripts/update-add-new.sh
        RESULT=$?
        ;;
esac
if [ $RESULT -ne 0 ]; then
    echo "Distribution specific update steps failed, aborting the update."
    exit 1
fi

$LABTAINER_DIR/setup_scripts/pull-all.py $test_flag || exit 1
here=`pwd`
rm -fr labtainer/trunk/setup-scripts
cd labtainer/trunk/scripts/labtainer-student/bin
if [ ! -L update-designer.sh ]; then
    ln -s ../../../setup_scripts/update-designer.sh
fi
if [[ "$TEST_REGISTRY" != TRUE ]]; then
    mkdir -p $LABTAINER_DIR/MakepackUI/bin
    wget --quiet https://github.com/mfthomps/Labtainers/releases/latest/download/makepackui.jar -O $LABTAINER_DIR/MakepackUI/bin/makepackui.jar
fi
target=~/.bashrc
grep "lab-completion.bash" $target >>/dev/null
result=$?
if [[ $result -ne 0 ]];then
   echo 'source $LABTAINER_DIR/setup_scripts/lab-completion.bash' >> $target
fi
source $LABTAINER_DIR/setup_scripts/lab-completion.bash
cd $here
grep "^Distribution created:" labtainer/trunk/README.md | awk '{print "Updated to release of: ", $3, $4}'
grep "^Branch:" labtainer/trunk/README.md | awk '{print "branch: ", $2}'
grep "^Revision:" labtainer/trunk/README.md | awk '{print "Revision: ", $2}'
grep "^Commit:" labtainer/trunk/README.md | awk '{print "Commit: ", $2}'
