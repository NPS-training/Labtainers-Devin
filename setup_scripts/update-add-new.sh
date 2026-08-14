#
# All non-Ubuntu 18 update logic should go here.  Sourced from update-add.sh, which
# then performs the update steps that are common to all distributions, e.g., pulling
# base images and reporting the installed release.
#
if [ -z "$LABTAINER_DIR" ] || [ ! -d "$LABTAINER_DIR/setup_scripts" ]; then
    echo "Unable to determine the labtainer directory.  Please set LABTAINER_DIR to"
    echo "the trunk directory of your Labtainers installation and try again."
    return 1
fi
#
# Distributions other than Ubuntu 18 are expected to provide the python
# environment used by the Labtainer scripts.
#
if [ ! -d /opt/labtainer/venv/bin ]; then
    echo "The /opt/labtainer/venv python environment is missing, the Labtainer scripts"
    echo "will not run.  See the Labtainers documentation for installation instructions."
    return 1
fi
