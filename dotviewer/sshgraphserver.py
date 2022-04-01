#! /usr/bin/env python
"""This script displays locally the graphs that are built by dotviewer
on remote machines.

Usage:
    sshgraphserver.py  hostname  [more args for ssh...]
    sshgraphserver.py  LOCAL

This logs in to 'hostname' by passing the arguments on the command-line
to ssh.  No further configuration is required: it works for all programs
using the dotviewer library as long as they run on 'hostname' under the
same username as the one sshgraphserver logs as.

If 'hostname' is the string 'LOCAL', then it starts locally without ssh.
"""

from __future__ import print_function, absolute_import

import os, sys

PARENTDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# make dotviewer importable
sys.path.insert(0, PARENTDIR)

from dotviewer import graphserver
from dotviewer.strunicode import forcestr

import socket, subprocess, random


def ssh_graph_server(sshargs):
    s1 = socket.socket()
    s1.bind(('127.0.0.1', socket.INADDR_ANY))
    localhost, localport = s1.getsockname()

    if sshargs[0] != 'LOCAL':
        remoteport = random.randrange(10000, 20000)
        #  ^^^ and just hope there is no conflict

        args = ['ssh', '-S', 'none', '-C', '-R%d:127.0.0.1:%d' % (
            remoteport, localport)]
        args = args + sshargs + ['python -u -c "exec input()"']
    else:
        remoteport = localport
        args = ['python', '-u', '-c', 'exec input()']

    print(' '.join(args))
    p = subprocess.Popen(args, bufsize=0,
                         stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE)
    p.stdin.write(forcestr(repr('port=%d\n%s' % (remoteport, REMOTE_SOURCE)) + '\n'))
    line = p.stdout.readline()
    assert line == 'OK\n'

    graphserver.listen_server(None, s1=s1)


REMOTE_SOURCE = r"""
import tempfile, getpass, os, sys

def main(port):
    tmpdir = tempfile.gettempdir()
    user = getpass.getuser()
    fn = os.path.join(tmpdir, 'dotviewer-sshgraphsrv-%s' % user)
    try:
        os.unlink(fn)
    except OSError:
        pass
    f = open(fn, 'w')
    f.write("%s\n" % port)
    f.close()
    try:
        sys.stdout.write('OK\n')
        # just wait for the loss of the remote link, ignoring any data
        while sys.stdin.read(1024):
            pass
    finally:
        try:
            os.unlink(fn)
        except OSError:
            pass

main(port)
"""


if __name__ == '__main__':
    import sys
    if len(sys.argv) <= 1:
        print(__doc__)
        sys.exit(2)
    ssh_graph_server(sys.argv[1:])
