#!/bin/bash
: <<'END'
This software was created by United States Government employees at 
The Center for the Information Systems Studies and Research (CISR) 
at the Naval Postgraduate School NPS.  Please note that within the 
United States, copyright protection is not available for any works 
created  by United States Government employees, pursuant to Title 17 
United States Code Section 105.   This software is in the public 
domain and is not subject to copyright. 
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

END
#
#  Update a labtainers installation to use the latest tar and fetch the
#  latest baseline images
#
if [ "$#" -eq 1 ]; then
   if [ "$1" == "-t" ]; then
      export TEST_REGISTRY=TRUE
   else
      echo "update-labtainers [-t]"
      echo "   use -t to pull tar from /media/sf_SEED"
      echo "   and pull images from the test registry"
      exit
   fi
elif [ "$#" -ne 0 ]; then
   echo "update-labtainers [-t]"
   echo "   use -t to pull tar from /media/sf_SEED"
   echo "   and pull images from the test registry"
   exit
fi
#
# figure out where we are executing from and go to the labtainer directory
#
here=`pwd`
if [[ $here == */labtainer ]]; then
   echo is at top >> /dev/null
elif [[ $here == */labtainer-student ]]; then
   #echo is in student
   real=`realpath ./`
   cd $real
   cd ../../..
elif [[ $here == */setup_scripts ]]; then
   cd ../../
else
   echo "Please run this script from the labtainer or labtainer-student directory"
   exit
fi
rm -f update-labtainer.sh
ln -s trunk/setup_scripts/update-labtainer.sh
full=`realpath trunk/setup_scripts/update-labtainer.sh`
ln -sf $full trunk/scripts/labtainer-student/bin/update-labtainer.sh
HOSTNAME=`hostname`
test_flag=""
update_log=/tmp/update.log
release_url=https://github.com/mfthomps/Labtainers/releases/latest/download
echo "doing update of labtainer $(date)" > $update_log
if [[ "$TEST_REGISTRY" != TRUE ]]; then
   #wget https://my.nps.edu/documents/107523844/109121513/labtainer.tar/6fc80410-e87d-4e47-ae24-cbb60c7619fa -O labtainer.tar
   #wget --quiet https://nps.box.com/shared/static/afz87ok8ezr0vtyo2qtlqbfmc28zk08j.tar -O labtainer.tar
   #wget --quiet https://github.com/mfthomps/Labtainers/raw/master/distrib/release/labtainer.tar -O labtainer.tar
   wget --quiet $release_url/labtainer.tar -O labtainer.tar >>$update_log 2>&1
   result=$?
   if [[ $result -ne 0 ]];then
      echo "Failed retrieving labtainer.tar from github, see $update_log.  Network problems?  Maybe try again."
      exit 1
   fi
   sync
   #
   #  Verify the download against a published checksum, if there is one.
   #
   wget --quiet $release_url/labtainer.tar.sha256 -O /tmp/labtainer.tar.sha256 >>$update_log 2>&1
   if [[ $? -eq 0 && -s /tmp/labtainer.tar.sha256 ]]; then
      expected=$(awk '{print $1}' /tmp/labtainer.tar.sha256)
      actual=$(sha256sum labtainer.tar | awk '{print $1}')
      if [[ "$expected" != "$actual" ]]; then
         echo "Checksum of the downloaded labtainer.tar does not match the published checksum."
         echo "Expected $expected, got $actual.  Please try the update again."
         exit 1
      fi
      echo "labtainer.tar checksum verified" >>$update_log
   else
      echo "No published checksum for labtainer.tar, skipping checksum verification" >>$update_log
   fi
else
   cp /media/sf_SEED/test_vms/$HOSTNAME/labtainer.tar .
   echo "USING SHARED FILE TAR, NOT PULLING FROM WEB"
   test_flag="-t"
fi
cd ..
#
# Confirm we have a complete tar prior to extracting over the installation.
#
if [[ ! -s labtainer/labtainer.tar ]]; then
   echo "The labtainer.tar file is missing or empty, see $update_log.  Please try the update again."
   exit 1
fi
tar tf labtainer/labtainer.tar >>$update_log 2>&1
result=$?
if [[ $result -ne 0 ]];then
   echo "The labtainer.tar file is not a valid tar, see $update_log.  The download may have been"
   echo "truncated.  Please try the update again."
   exit 1
fi
# tar is broken, spews error messages, but extracts ok
tar xf labtainer/labtainer.tar --keep-newer-files --warning=none >>$update_log 2>&1
#
# ensure labtainer paths in .bashrc
#
target=~/.bashrc
grep ":./bin:" $target >>/dev/null
result=$?
if [[ $result -ne 0 ]];then
   cat <<EOT >>$target
   if [[ ":\$PATH:" != *":./bin:"* ]]; then 
      export PATH="\${PATH}:./bin"
   fi
EOT
fi

grep "Labtainer Aliases" $target >>/dev/null
result=$?
if [[ $result -ne 0 ]];then
   here=`realpath ../`
   cat <<EOT >>$target
   #
   # Labtainer Aliases
   alias vncstart="vncserver -local :1"
   alias vncstop="vncserver -kill :1"
   alias vncrestart="vncstop && vncstart"
   alias dex="sudo docker exec -it"
   alias cdlab="cd $LABTAINER_DIR/scripts/labtainer-student/"
EOT
fi

# fix broken LABTAINER_DIR
isbroken=$(grep LABTAINER_DIR=/trunk ~/.bashrc)
if [[ ! -z $isbroken ]]; then
   sed -i '/LABTAINER_DIR=\/trunk/d' ~/.bashrc
   echo 'export LABTAINER_DIR=$HOME/labtainer/trunk' >> ~/.bashrc
   export LABTAINER_DIR=$HOME/labtainer/trunk
fi

add_script=labtainer/trunk/setup_scripts/update-add.sh
if [[ -f $add_script ]]; then
   source $add_script
fi
labtainer/trunk/scripts/labtainer-student/bin/imodule -u
