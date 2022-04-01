#
# Common entry point to access a temporary directory (for testing, etc.)
# This uses the py lib's logic to create numbered directories.  The last
# three temporary directories are kept.
#
# The udir is created with the following name:
#
#    $PYPY_USESSION_DIR/usession-$PYPY_USESSION_BASENAME-N
#
# where N is a small number.  If supported, a symlink is created for
# convenience too, pointing to (the most recent) udir:
#
#    $PYPY_USESSION_DIR/usession-$PYPY_USESSION_BASENAME-$USER
#
# The default value for $PYPY_USESSION_DIR is the system's tmp.
# The default value for $PYPY_USESSION_BASENAME is the name
# of the current Mercurial branch.
#

import os
import sys

from rpython.tool.version import get_repo_version_info
from py.path import local 

PYPY_KEEP = int(os.environ.get('PYPY_USESSION_KEEP', '3'))

def make_udir(dir=None, basename=None):
    if dir is not None:
        dir = local(dir)
    if basename is None:
        info = get_repo_version_info()
        if info:
            hgtag, hgid = info
            basename = hgtag
            if basename == '?':
                basename = 'unknown' # directories with ? are not fun
                # especially on windows
        else:
            basename = ''
    basename = basename.replace('/', '--')
    if not basename.startswith('-'):
        basename = '-' + basename
    if not basename.endswith('-'):
        basename = basename + '-'
    return local.make_numbered_dir(rootdir = dir,
                                   prefix = 'usession' + basename,
                                   keep = PYPY_KEEP)

udir = make_udir(dir      = os.environ.get('PYPY_USESSION_DIR'),
                 basename = os.environ.get('PYPY_USESSION_BASENAME'))
