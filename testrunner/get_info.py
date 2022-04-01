#!/usr/bin/env python
"""
Dump some translation information to stdout as JSON. Used by buildbot.
"""
from __future__ import print_function
import sys
import os
import json
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from pypy.module.sys.version import CPYTHON_VERSION

BASE_DIR = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
if sys.platform.startswith('win'):
    TARGET_NAME = r'pypy%d.%d-c.exe' % CPYTHON_VERSION[:2]
    VENV_TARGET = 'pypy3.exe'
    TARGET_DIR = 'Scripts'
else:
    TARGET_NAME = 'pypy%d.%d-c' % CPYTHON_VERSION[:2]
    VENV_TARGET = 'pypy3'  # virtualenv does not create pypy3.9
    TARGET_DIR = 'bin'
VENV_DIR = 'pypy-venv'

def make_info_dict():
    target_path = os.path.join(BASE_DIR, 'pypy', 'goal', TARGET_NAME)
    return {'target_path': target_path,
            'virt_pypy': os.path.join(VENV_DIR, TARGET_DIR, VENV_TARGET),
            'venv_dir': VENV_DIR,
            'project': 'PyPy%d.%d' % CPYTHON_VERSION[:2], # for benchmarks
           }

def dump_info():
    return json.dumps(make_info_dict())

if __name__ == '__main__':
    print(dump_info())
