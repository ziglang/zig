=========================
PyPy 2.0.2 - Fermi Panini
=========================

We're pleased to announce PyPy 2.0.2.  This is a stable bugfix release
over `2.0`_ and `2.0.1`_.  You can download it here:

    https://pypy.org/download.html

It fixes a crash in the JIT when calling external C functions (with
ctypes/cffi) in a multithreaded context.

.. _2.0: release-2.0.0.html
.. _2.0.1: release-2.0.1.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy 2.0 and cpython 2.7.3`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64 or
Windows 32.  Support for ARM is progressing but not bug-free yet.

.. _`pypy 2.0 and cpython 2.7.3`: https://speed.pypy.org

Highlights
==========

This release contains only the fix described above.  A crash (or wrong
results) used to occur if all these conditions were true:

- your program is multithreaded;

- it runs on a single-core machine or a heavily-loaded multi-core one;

- it uses ctypes or cffi to issue external calls to C functions.

This was fixed in the branch `emit-call-x86`__ (see the example file
``bug1.py``).

.. __: https://bitbucket.org/pypy/pypy/commits/7c80121abbf4

Cheers,
arigo et. al. for the PyPy team
