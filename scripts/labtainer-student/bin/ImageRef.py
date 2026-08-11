#!/opt/labtainer/venv/bin/python3
'''
This software was created by United States Government employees at 
The Center for Cybersecurity and Cyber Operations (C3O) 
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
'''
import re
import subprocess
'''
Validation of docker image references, registry names, tags and digests, along
with helpers to run docker and curl without use of a shell.  Image names, labels
(e.g., "base") and tags read from a registry are attacker-controlled values, thus
they are confined to these patterns before being used in a command or a URL.
'''
''' a registry host or a path component, e.g. "testregistry", "dmz-example.inner_gw.student" '''
COMPONENT = r'[a-zA-Z0-9_][a-zA-Z0-9._-]*'
IMAGE_REF = re.compile(r'^%s(:[0-9]+)?(/%s)*(:%s)?$' % (COMPONENT, COMPONENT, COMPONENT))
TAG_REF = re.compile(r'^%s$' % COMPONENT)
DIGEST_REF = re.compile(r'^[a-zA-Z0-9]+:[a-fA-F0-9]+$')
TOKEN_REF = re.compile(r'^[a-zA-Z0-9._~+/=-]+$')

def validImage(image):
    ''' true if image is a registry-qualified image reference and nothing more '''
    return image is not None and IMAGE_REF.match(image) is not None

def validTag(tag):
    return tag is not None and TAG_REF.match(tag) is not None

def validDigest(digest):
    return digest is not None and DIGEST_REF.match(digest) is not None

def validToken(token):
    return token is not None and TOKEN_REF.match(token) is not None

def dockerPull(image, lgr=None):
    ''' pull the given image, refusing anything that is not a plain image reference '''
    if not validImage(image):
        if lgr is not None:
            lgr.error('dockerPull refused invalid image %s' % image)
        print('Refusing to pull invalid image name %s' % image)
        return None
    return subprocess.call(['docker', 'pull', image])

def curl(args):
    ''' run curl with the given argument list, i.e., without a shell '''
    ps = subprocess.Popen(['curl'] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return ps.communicate()
