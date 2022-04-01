from __future__ import print_function
import time
import py
import os
from subprocess import Popen, PIPE
import rpython
rpythondir = os.path.dirname(os.path.realpath(rpython.__file__))
rpythonroot = os.path.dirname(rpythondir)
default_retval = '?', '?'

def maywarn(err, repo_type='Mercurial'):
    if not err:
        return

    from rpython.tool.ansi_print import AnsiLogger
    log = AnsiLogger("version")
    log.WARNING('Errors getting %s information: %s' % (repo_type, err))

CACHED_RESULT = None
CACHED_ARGS = None

def get_repo_version_info(hgexe=None, root=rpythonroot):
    '''Obtain version information by invoking the 'hg' or 'git' commands.'''
    global CACHED_RESULT, CACHED_ARGS
    key = (hgexe, root)
    if CACHED_RESULT is not None and CACHED_ARGS == key:
        return CACHED_RESULT
    res = _get_repo_version_info(hgexe, root)
    CACHED_RESULT = res
    CACHED_ARGS = key
    return res

def _get_repo_version_info(hgexe, root):
    # Try to see if we can get info from Git if hgexe is not specified.
    if not hgexe:
        if os.path.isdir(os.path.join(root, '.git')):
            return _get_git_version(root)

    # Fallback to trying Mercurial.
    if hgexe is None:
        hgexe = py.path.local.sysfind('hg')

    if os.path.isfile(os.path.join(root, '.hg_archival.txt')):
        return _get_hg_archive_version(os.path.join(root, '.hg_archival.txt'))
    elif not os.path.isdir(os.path.join(root, '.hg')):
        maywarn('Not running from a Mercurial repository!')
        return default_retval
    elif not hgexe:
        maywarn('Cannot find Mercurial command!')
        return default_retval
    else:
        return _get_hg_version(hgexe, root)


def _get_hg_version(hgexe, root):
    env = dict(os.environ)
    # get Mercurial into scripting mode
    env['HGPLAIN'] = '1'
    # disable user configuration, extensions, etc.
    env['HGRCPATH'] = os.devnull

    try:
        p = Popen([str(hgexe), 'version', '-q'],
                  stdout=PIPE, stderr=PIPE, env=env, universal_newlines=True)
    except OSError as e:
        maywarn(e)
        return default_retval

    if not p.stdout.read().startswith('Mercurial Distributed SCM'):
        maywarn('command does not identify itself as Mercurial')
        return default_retval

    p = Popen([str(hgexe), 'id', '--template', r"{id}\n{tags}\n{branch}\n", root],
              stdout=PIPE, stderr=PIPE, env=env,
              universal_newlines=True)
    hgout = p.stdout.read().strip()
    if p.wait() != 0:
        maywarn(p.stderr.read())
        hgout = '?\n?\n?'
    hgid, hgtags, hgbranch = hgout.strip().split("\n", 3)
    hgtags = [t for t in hgtags.strip().split() if t != 'tip']

    if hgtags:
        return hgtags[0], hgid
    else:
        return hgbranch, hgid


def _get_hg_archive_version(path):
    with open(path) as fp:
        # reverse the order since there may be more than one tag
        # and the latest tag will be first, so make it last instead
        data = dict((x.split(': ', 1) for x in fp.read().splitlines()[::-1]))
    if 'tag' in data:
        return data['tag'], data['node']
    else:
        return data['branch'], data['node']


def _get_git_version(root):
    #XXX: this function is a untested hack,
    #     so the git mirror tav made will work
    gitexe = py.path.local.sysfind('git')
    if not gitexe:
        return default_retval

    try:
        p = Popen(
            [str(gitexe), 'rev-parse', 'HEAD'],
            stdout=PIPE, stderr=PIPE, cwd=root,
            universal_newlines=True,
            )
    except OSError as e:
        maywarn(e, 'Git')
        return default_retval
    if p.wait() != 0:
        maywarn(p.stderr.read(), 'Git')
        return default_retval
    revision_id = p.stdout.read().strip()[:12]
    p = Popen(
        [str(gitexe), 'describe', '--tags', '--exact-match'],
        stdout=PIPE, stderr=PIPE, cwd=root,
        universal_newlines=True,
        )
    if p.wait() != 0:
        p = Popen(
            [str(gitexe), 'branch'], stdout=PIPE, stderr=PIPE,
            cwd=root, universal_newlines=True,
            )
        if p.wait() != 0:
            maywarn(p.stderr.read(), 'Git')
            return '?', revision_id
        branch = '?'
        for line in p.stdout.read().strip().split('\n'):
            if line.startswith('* '):
                branch = line[1:].strip()
                if branch == '(no branch)':
                    branch = '?'
                break
        return branch, revision_id
    return p.stdout.read().strip(), revision_id


if __name__ == '__main__':
    print(get_repo_version_info())
