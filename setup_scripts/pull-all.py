#!/opt/labtainer/venv/bin/python3
import os
import sys
import argparse
import calendar
from dateutil.parser import parse

def getLabtainerDir():
    ''' The labtainer trunk directory, derived from the location of this
        script if LABTAINER_DIR is not usable. '''
    labtainer_dir = os.getenv('LABTAINER_DIR')
    if labtainer_dir is not None and os.path.isdir(labtainer_dir):
        return labtainer_dir
    here = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    if os.path.isdir(os.path.join(here, 'scripts', 'labtainer-student', 'bin')):
        ''' other modules, e.g., registry, expect LABTAINER_DIR in the environment '''
        os.environ['LABTAINER_DIR'] = here
        return here
    print('Unable to determine the labtainer directory.  Please set LABTAINER_DIR')
    print('to the trunk directory of your Labtainers installation and try again.')
    exit(1)

labtainer_dir = getLabtainerDir()
sys.path.append(os.path.join(labtainer_dir, 'scripts/labtainer-student/bin'))
import labutils
import ParseLabtainerConfig
import LabtainerLogging
import InspectLocalReg
import InspectRemoteReg
import registry

def getBaseImages(fname, groups):
    ''' Read the base image manifest, returning the image names, sans registry
        and "labtainer." prefix, belonging to any of the given groups. '''
    if not os.path.isfile(fname):
        print('Missing base image manifest %s' % fname)
        exit(1)
    retval = []
    with open(fname) as fh:
        for line in fh:
            line = line.strip()
            if len(line) == 0 or line.startswith('#'):
                continue
            parts = line.split()
            group = parts[1].lower() if len(parts) > 1 else 'default'
            if group in groups:
                retval.append(parts[0])
    return retval

def createdTime(created):
    ''' Seconds since the epoch of a docker image creation timestamp. '''
    if created is None:
        return None
    try:
        return calendar.timegm(parse(created.split('.')[0]).timetuple())
    except ValueError:
        logger.debug('pull-all unable to parse image timestamp <%s>' % created)
        return None

def pullImage(image_name):
    cmd = 'docker pull %s' % image_name
    print(cmd)
    if os.system(cmd) != 0:
        print('Failed to pull %s' % image_name)
        return False
    return True

parser = argparse.ArgumentParser(description='Pull all base images if they do not yet exist, or if the registry has a newer image')
parser.add_argument('-f', '--force', action='store_true', default=False, help='always pull latest')
parser.add_argument('-t', '--test_registry', action='store_true', default=False, help='pull all Labtainer base images')
parser.add_argument('-m', '--metasploit', action='store_true', default=False, help='include metasploitable and kali images')
args = parser.parse_args()

lab_config_file = os.path.join(labtainer_dir,'config', 'labtainer.config')
labutils.logger = LabtainerLogging.LabtainerLogging("pull.log", 'pull-all', lab_config_file)
logger = labutils.logger
labtainer_config = ParseLabtainerConfig.ParseLabtainerConfig(lab_config_file, logger)
test_registry = False
if not args.test_registry:
    env = os.getenv('TEST_REGISTRY')
    if env is not None and env.lower() == 'true':
        test_registry = True
if args.test_registry or test_registry:
    test_registry = True
    branch, use_registry = registry.getBranchRegistry()
else:
    use_registry = labtainer_config.default_registry
print('registry is: %s' % use_registry)
groups = ['default']
if args.metasploit:
    groups.append('metasploit')
base_images_file = os.path.join(labtainer_dir, 'config', 'base_images.config')
config_list = getBaseImages(base_images_file, groups)
failed = []
for config in config_list:
    image_name = 'labtainer.%s' % config
    full_name = '%s/%s' % (use_registry, image_name)
    local_created, local_user, local_version = labutils.inspectImage(full_name)
    if args.force or local_created is None:
        if not pullImage(full_name):
            failed.append(full_name)
        continue
    ''' image is present locally, refresh it if the registry has a newer one '''
    if test_registry:
        reg_created, reg_user, reg_version, reg_tag, reg_base = InspectLocalReg.inspectLocal(image_name,
                          logger, use_registry, no_pull=True)
    else:
        reg_created, reg_user, reg_version, reg_tag = InspectRemoteReg.inspectRemote(full_name,
                          logger, no_pull=True)
    local_ts = createdTime(local_created)
    reg_ts = createdTime(reg_created)
    if local_ts is None or reg_ts is None:
        logger.debug('pull-all no timestamp comparison for %s, local: %s registry: %s' % (full_name,
                     local_created, reg_created))
        continue
    if local_ts < reg_ts:
        print('%s is newer in the registry' % full_name)
        if not pullImage(full_name):
            failed.append(full_name)
if len(failed) > 0:
    print('Failed to pull these images: %s' % ' '.join(failed))
    exit(1)
