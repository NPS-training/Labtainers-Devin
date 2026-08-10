#!/usr/bin/env python3
import os
import re
import shlex
import socket
import subprocess
'''
Listen for vboxmanage requests and run a strictly limited set of
vboxmanage subcommands.  Received data is never passed to a shell.
'''

# Allowed vboxmanage subcommands, mapped to the fixed argument
# sequences that may follow them.
ALLOWED_COMMANDS = {
    ('list', 'runningvms'): 0,
    ('list', 'vms'): 0,
    ('startvm',): 1,
    ('controlvm',): 2,
}
ALLOWED_CONTROLVM_ACTIONS = ['reset', 'poweroff', 'acpipowerbutton', 'savestate', 'pause', 'resume']
VM_NAME = re.compile(r'^[A-Za-z0-9._-]{1,64}$')

def parseCommand(cmd):
    '''
    Return an argv list for vboxmanage, or None if the request is not allowed.
    '''
    try:
        words = shlex.split(cmd)
    except ValueError:
        return None
    for prefix, num_args in ALLOWED_COMMANDS.items():
        if tuple(words[:len(prefix)]) != prefix:
            continue
        args = words[len(prefix):]
        if len(args) != num_args:
            return None
        if prefix == ('controlvm',):
            if not VM_NAME.match(args[0]) or args[1] not in ALLOWED_CONTROLVM_ACTIONS:
                return None
        elif prefix == ('startvm',):
            if not VM_NAME.match(args[0]):
                return None
        return ['vboxmanage'] + list(prefix) + args
    return None

def doCommand(cmd, log):
    argv = parseCommand(cmd)
    if argv is None:
        log.write('rejected command: %s\n' % cmd)
        log.flush()
        return 'command not permitted\n'
    ps = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output = ps.communicate()
    retval = ''
    for line in output[0].decode('utf-8').splitlines():
        log.write(line+'\n')
        retval += line+'\n'
    for line in output[1].decode('utf-8').splitlines():
        log.write(line+'\n')
        retval += line+'\n'
    return retval

if __name__ == '__main__':
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    bind_addr = os.getenv('VBOXSERVER_ADDR', '127.0.0.1')
    bind_port = int(os.getenv('VBOXSERVER_PORT', '6000'))
    server_addr = (bind_addr, bind_port)
    logfile='/tmp/vboxserver.log'
    log = open(logfile,'w')
    log.write('do bind'+'\n')
    sock.bind(server_addr)
    while True:
        got, addr = sock.recvfrom(4096)
        if got is None or len(got) == 0:
            log.write('got zilch, quit'+'\n')
            exit(0)
        got = got.decode()
        log.write('got %s\n' % got) 
        result = doCommand(got, log)
        sock.sendto(result.encode(), addr)
