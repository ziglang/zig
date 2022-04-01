#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
This should be run under PyPy.
"""

import os
import platform
import subprocess
import tempfile
import webbrowser
from collections import OrderedDict

import jinja2

from .kinds import KINDS


class SearchableSet(object):
    def __init__(self, items=()):
        self._items = {}
        for item in items:
            self.add(item)

    def __iter__(self):
        return iter(self._items)

    def __contains__(self, other):
        return other in self._items

    def __getitem__(self, idx):
        return self._items[idx]

    def add(self, item):
        self._items[item] = item

    def __len__(self):
        return len(self._items)

class Item(object):
    def __init__(self, name, kind, subitems=[]):
        self.name = name
        self.kind = kind
        self.subitems = subitems

    def __hash__(self):
        return hash(self.name)

    def __eq__(self, other):
        if isinstance(other, str):
            return self.name == other
        return self.name == other.name


class ItemStatus(object):
    def __init__(self, name, pypy_exists):
        self.name = name
        self.cls = 'exists' if pypy_exists else ''
        self.symbol = u"✔" if pypy_exists else u'✖'

    def __lt__(self, other):
        return self.name < other.name

def find_numpy_items(python, modname="numpy", attr=None):
    args = [
        python, os.path.join(os.path.dirname(__file__), "search.py"), modname
    ]
    if attr is not None:
        args.append(attr)
    lines = subprocess.check_output(args).splitlines()
    items = SearchableSet()
    for line in lines:
        # since calling a function in "search.py" may have printed side effects,
        # make sure the line begins with '[UT] : '
        if not (line[:1] in KINDS.values() and line[1:4] == ' : '):
            continue
        kind, name = line.split(" : ", 1)
        subitems = []
        if kind == KINDS["TYPE"] and name in SPECIAL_NAMES and attr is None:
            subitems = find_numpy_items(python, modname, name)
        items.add(Item(name, kind, subitems))
    return items

def get_version_str(python):
    args = [python, '-c', 'import sys; print sys.version']
    lines = subprocess.check_output(args).splitlines()
    return lines[0]

def split(lst):
    SPLIT = 5
    lgt = len(lst) // SPLIT + 1
    l = [[] for i in range(lgt)]
    for i in range(lgt):
        for k in range(SPLIT):
            if k * lgt + i < len(lst):
                l[i].append(lst[k * lgt + i])
    return l

SPECIAL_NAMES = ["ndarray", "dtype", "generic", "flatiter", "ufunc",
                 "nditer"]

def main(argv):
    if 'help' in argv[1]:
        print '\nusage: python', os.path.dirname(__file__), '<path-to-pypy> [<outfile.html>] [<path-to-cpython-with-numpy>]'
        print '       path-to-cpython-with-numpy defaults to "/usr/bin/python"\n'
        return 
    if len(argv) < 4:
        cpython = '/usr/bin/python'
    else:
        cpython = argv[3]
    cpy_items = find_numpy_items(cpython)
    pypy_items = find_numpy_items(argv[1])
    ver = get_version_str(argv[1])
    all_items = []

    msg = "{:d}/{:d} names".format(len(pypy_items), len(cpy_items)) + " "
    msg += ", ".join(
        "{:d}/{:d} {} attributes".format(
            len(pypy_items[name].subitems), len(cpy_items[name].subitems), name
        )
        for name in SPECIAL_NAMES
    )
    for item in cpy_items:
        pypy_exists = item in pypy_items
        if item.subitems:
            for sub in item.subitems:
                all_items.append(
                    ItemStatus(item.name + "." + sub.name, pypy_exists=pypy_exists and pypy_items[item].subitems and sub in pypy_items[item].subitems)
                )
        all_items.append(ItemStatus(item.name, pypy_exists=item in pypy_items))
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(os.path.dirname(__file__))
    )
    html = env.get_template("page.html").render(all_items=split(sorted(all_items)),
             msg=msg, ver=ver)
    if len(argv) > 2:
        with open(argv[2], 'w') as f:
            f.write(html.encode("utf-8"))
    else:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".html") as f:
            f.write(html.encode("utf-8"))
        print "Saved in: %s" % f.name
