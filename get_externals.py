'''Get external dependencies for building PyPy
they will end up in the platform.host().basepath, something like repo-root/external
'''

from __future__ import print_function

import argparse
import os
import zipfile
from subprocess import Popen, PIPE
from rpython.translator.platform import host

def runcmd(cmd, verbose):
    stdout = stderr = ''
    report = False
    try:
        p = Popen(cmd, stdout=PIPE, stderr=PIPE)
        stdout, stderr = p.communicate()
        if p.wait() != 0 or verbose:
            report = True
    except Exception as e:
        stderr = str(e) + '\n' + stderr
        report = True
    if report:
        print('running "%s" returned\n%s\n%s' % (' '.join(cmd), stdout, stderr))
    if stderr:
        raise RuntimeError(stderr)

def checkout_repo(dest='externals', org='pypy', branch='default', verbose=False):
    url = 'https://foss.heptapod.net/{}/externals'.format(org)
    if os.path.exists(dest):
        cmd = ['hg', '-R', dest, 'pull', url]
    else:
        cmd = ['hg','clone',url, dest]
    runcmd(cmd, verbose)
    cmd = ['hg','-R', dest, 'update',branch]
    runcmd(cmd, verbose)

def extract_zip(externals_dir, zip_path):
    with zipfile.ZipFile(os.fspath(zip_path)) as zf:
        zf.extractall(os.fspath(externals_dir))
        return externals_dir / zf.namelist()[0].split('/')[0]

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('-v', '--verbose', action='store_true')
    p.add_argument('-O', '--organization',
                   help='Organization owning the deps repos', default='pypy')
    p.add_argument('-e', '--externals', default=host.externals,
                   help='directory in which to store dependencies',
                   )
    p.add_argument('-b', '--branch', default=host.externals_branch,
                   help='branch to check out',
                   )
    p.add_argument('-p', '--platform', default=None,
                   help='someday support cross-compilation, ignore for now',
                   )
    return p.parse_args()


def main():
    args = parse_args()
    checkout_repo(
        dest=args.externals,
        org=args.organization,
        branch=args.branch,
        verbose=args.verbose,
    )

if __name__ == '__main__':
    main()
