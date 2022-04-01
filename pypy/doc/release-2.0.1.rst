==============================
PyPy 2.0.1 - Bohr Smørrebrød
==============================

We're pleased to announce PyPy 2.0.1.  This is a stable bugfix release
over `2.0`_.  You can download it here:
  
    https://pypy.org/download.html

The fixes are mainly about fatal errors or crashes in our stdlib.  See
below for more details.

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

- fix an occasional crash in the JIT that ends in `RPython Fatal error:
  NotImplementedError`__.

- `id(x)` is now always a positive number (except on int/float/long/complex).
  This fixes an issue in ``_sqlite.py`` (mostly for 32-bit Linux).

- fix crashes of callback-from-C-functions (with cffi) when used together
  with Stackless features, on asmgcc (i.e. Linux only).  Now `gevent should
  work better`__.

- work around an eventlet issue with `socket._decref_socketios()`__.

.. __: https://bugs.pypy.org/issue1482
.. __: https://mail.python.org/pipermail/pypy-dev/2013-May/011362.html
.. __: https://bugs.pypy.org/issue1468
.. _2.0: release-2.0.0.html

Cheers,
arigo et. al. for the PyPy team
