#   Copyright 2000-2004 Michael Hudson-Doyle <micahel@gmail.com>
#
#                        All Rights Reserved
#
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose is hereby granted without fee,
# provided that the above copyright notice appear in all copies and
# that both that copyright notice and this permission notice appear in
# supporting documentation.
#
# THE AUTHOR MICHAEL HUDSON DISCLAIMS ALL WARRANTIES WITH REGARD TO
# THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS, IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL,
# INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
# RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
# CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

import os, sys

# for the completion support.
# this is all quite nastily written.
_packages = {}

def _make_module_list_dir(dir, suffs, prefix=''):
    l = []
    for fname in os.listdir(dir):
        file = os.path.join(dir, fname)
        if os.path.isfile(file):
            for suff in suffs:
                if fname.endswith(suff):
                    l.append( prefix + fname[:-len(suff)] )
                    break
        elif os.path.isdir(file) \
             and os.path.exists(os.path.join(file, "__init__.py")):
            l.append( prefix + fname )
            _packages[prefix + fname] = _make_module_list_dir(
                file, suffs, prefix + fname + '.' )
    return sorted(set(l))

def _make_module_list():
    import importlib.machinery
    suffs = [x for x in importlib.machinery.all_suffixes() if x != '.pyc']
    suffs.sort(reverse=True)
    _packages[''] = list(sys.builtin_module_names)
    for dir in sys.path:
        if dir == '':
            dir = '.'
        if os.path.isdir(dir):
            _packages[''] += _make_module_list_dir(dir, suffs)
    _packages[''].sort()

def find_modules(stem):
    l = stem.split('.')
    pack = '.'.join(l[:-1])
    try:
        mods = _packages[pack]
    except KeyError:
        raise ImportError("can't find \"%s\" package" % pack)
    return [mod for mod in mods if mod.startswith(stem)]
