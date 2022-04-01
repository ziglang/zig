#!/usr/bin/env python
from __future__ import print_function
import sys
import os
import subprocess
import tempfile

TAR_OPTIONS = '-x -v --strip-components=2'
TAR = 'tar {options} -f {tarfile} {files}'

def untar(tarfile, files):
    cmd = TAR.format(options=TAR_OPTIONS, tarfile=tarfile, files=files)
    os.system(cmd)

if sys.platform.startswith('linux'):
    arch = 'linux'
    cmd = 'wget "%s"'
    TAR_OPTIONS += ' --wildcards'
    binfiles = "'*/bin/pypy3*' '*/bin/libpypy3-c.so*'"
    if os.uname()[-1].startswith('arm'):
        arch += '-armhf-raspbian'
elif sys.platform.startswith('darwin'):
    arch = 'osx'
    cmd = 'curl -O "%s"'
    binfiles = "'*/bin/pypy3'"
else:
    print('Cannot determine the platform, please update this script')
    sys.exit(1)

if sys.maxsize == 2**63 - 1:
    arch += '64'

branch = subprocess.check_output(['hg', 'branch']).strip().decode('utf-8')
if branch == 'default':
    branch = 'trunk'

if '--nojit' in sys.argv:
    kind = 'nojit'
else:
    kind = 'jit'

filename = 'pypy-c-%s-latest-%s.tar.bz2' % (kind, arch)
url = 'http://buildbot.pypy.org/nightly/%s/%s' % (branch, filename)
tmp = tempfile.mkdtemp()
pypy_latest = os.path.join(tmp, filename)
olddir = os.getcwd()
mydir = os.chdir(tmp)
print('Downloading pypy to', tmp)
if os.system(cmd % url) != 0:
    sys.exit(1)

mydir = os.path.dirname(__file__)
print('Extracting pypy binary')
os.chdir(mydir)
untar(pypy_latest, binfiles)
include_dir = os.path.join(mydir, '..', '..', 'include')
lib_dir = os.path.join(mydir, '..', 'lib')
if os.path.isdir(include_dir):
    os.chdir(include_dir)
    untar(pypy_latest, '*/include/*')
else:
    print('WARNING: could not find the include/ dir')
os.chdir(olddir)
if not os.path.exists(lib_dir):
    os.mkdir(lib_dir)
os.chdir(lib_dir)
untar(pypy_latest, '*/lib/*')
os.chdir(olddir)

