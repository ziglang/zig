#!/usr/bin/python

"""
Force the PyPy buildmaster to run a builds on all builders that produce
nightly builds for a particular branch.

Taken from http://twistedmatrix.com/trac/browser/sandbox/exarkun/force-builds.py

modified by PyPy team
"""
from __future__ import absolute_import, division, print_function

import os, sys, subprocess
try:
    from urllib2 import quote
except ImportError:
    from urllib.request import quote

from twisted.internet import reactor, defer
from twisted.python import log
from twisted.web import client
from twisted.web.error import PageRedirect

OWN_BUILDERS = [
    'own-linux-x86-32',
    'own-linux-x86-64',
#    'own-linux-armhf',
#    'own-win-x86-32',
    'own-win-x86-64',
    'own-linux-s390x',
#    'own-macosx-x86-32',
    'own-linux-aarch64',
]
JIT_BUILDERS = [
    'pypy-c-jit-linux-x86-32',
    'pypy-c-jit-linux-x86-64',
#    'pypy-c-jit-freebsd-9-x86-64',
    'pypy-c-jit-macosx-x86-64',
#    'pypy-c-jit-win-x86-32',
    'pypy-c-jit-win-x86-64',
    'pypy-c-jit-linux-s390x',
#    'build-pypy-c-jit-linux-armhf-raspbian',
#    'build-pypy-c-jit-linux-armel',
    'pypy-c-jit-linux-aarch64',
]
RPYTHON_BUILDERS = [
    'rpython-linux-x86-32',
    'rpython-linux-x86-64',
#    'rpython-win-x86-32'
    'rpython-win-x86-64'
]

def get_user():
    if sys.platform == 'win32':
        return os.environ['USERNAME']
    else:
        import pwd
        return pwd.getpwuid(os.getuid())[0]

def main(options):
    #XXX: handle release tags
    #XXX: handle validity checks
    lock = defer.DeferredLock()
    requests = []
    def ebList(err):
        if err.check(PageRedirect) is not None:
            return None
        log.err(err, "Build force failure")

    if options.minimal:
        builders = JIT_BUILDERS
    else:
        builders = RPYTHON_BUILDERS + OWN_BUILDERS + JIT_BUILDERS

    for builder in builders:
        print('Forcing', builder, '...')
        url = "http://" + options.server + "/builders/" + builder + "/force"
        args = [
            ('username', options.user),
            ('revision', ''),
            ('forcescheduler', 'Force Build'),
            ('branch', options.branch),
            ('reason', options.reason)]
        url = url + '?' + '&'.join([k + '=' + quote(v) for (k, v) in args])
        requests.append(
            lock.run(client.getPage, url.encode('utf-8'), followRedirect=False).addErrback(ebList))

    d = defer.gatherResults(requests)
    d.addErrback(log.err)
    d.addCallback(lambda ign: reactor.stop())
    reactor.run()
    print('See http://buildbot.pypy.org/summary after a while')

if __name__ == '__main__':
    log.startLogging(sys.stdout)
    import optparse
    parser = optparse.OptionParser()
    parser.add_option("-b", "--branch", help="branch to build", default='')
    parser.add_option("-s", "--server", help="buildbot server", default="buildbot.pypy.org")
    parser.add_option("-u", "--user", help="user name to report", default=get_user())
    parser.add_option("-m", "--minimal", action="store_true", default=False,
                      help="minimal: trigger pypy-c-jit only")
    parser.add_option("-r", "--reason", help="reason for force",
                      default='Forced by command line script')
    (options, args) = parser.parse_args()
    if  not options.branch:
        parser.error("branch option required")
    try:
        subprocess.check_call(['hg','id','-r', options.branch])
    except subprocess.CalledProcessError:
        print('branch',  options.branch, 'could not be found in local repository')
        sys.exit(-1) 
    if options.branch.startswith('release') and not '-v' in options.branch:
        print('release branches must be of the form "release.*-v.*')
        sys.exit(-1) 
    main(options)
