======================
What's new in PyPy 2.3
======================

.. this is a revision shortly after release-2.3
.. startrev: 394146e9bb67

Move builtin ``struct`` module to ``_struct`` to allow ``pypy "-m idlelib.idle"``

Support compilation with gcc-4.9

Added support for the stdlib gdbm module via cffi

Annotator cleanups

.. branch: release-2.3.x

.. branch: unify-call-ops

.. branch: packaging

Use argparse for packaging.py, and add third-party components to LICENSE file.
Also mention that gdbm is GPL.
Do not crash the packaging process on failure in CFFI or license-building,
rather complete the build step and return -1.
