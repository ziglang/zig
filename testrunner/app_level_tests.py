#!/usr/bin/env python
"""
This is what the buildbot runs to execute the app-level tests
on top of pypy-c.
"""

import sys, os
import subprocess

rootdir = os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[0])))
os.environ['PYTHONPATH'] = rootdir
os.environ['PYTEST_PLUGINS'] = ''

popen = subprocess.Popen(
    [sys.executable, "testrunner/runner.py",
     "--logfile=pytest-A.log",
     "--config=pypy/pytest-A.cfg",
     "--config=pypy/pytest-A.py",
     "--config=~/machine-A_cfg.py",
     "--root=pypy", "--timeout=3600",
     ] + sys.argv[1:],
    cwd=rootdir)

try:
    ret = popen.wait()
except KeyboardInterrupt:
    popen.kill()
    print "\ninterrupted"
    ret = 1

sys.exit(ret)
