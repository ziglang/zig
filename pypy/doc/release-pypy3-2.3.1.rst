=====================
PyPy3 2.3.1 - Fulcrum
=====================

We're pleased to announce the first stable release of PyPy3. PyPy3
targets Python 3 (3.2.5) compatibility.

We would like to thank all of the people who donated_ to the `py3k proposal`_
for supporting the work that went into this.

You can download the PyPy3 2.3.1 release here:

    https://pypy.org/download.html#pypy3-2-3-1

Highlights
==========

* The first stable release of PyPy3: support for Python 3!

* The stdlib has been updated to Python 3.2.5

* Additional support for the u'unicode' syntax (`PEP 414`_) from Python 3.3

* Updates from the default branch, such as incremental GC and various JIT
  improvements

* Resolved some notable JIT performance regressions from PyPy2:

 - Re-enabled the previously disabled collection (list/dict/set) strategies

 - Resolved performance of iteration over range objects

 - Resolved handling of Python 3's exception __context__ unnecessarily forcing
   frame object overhead

.. _`PEP 414`: https://legacy.python.org/dev/peps/pep-0414/

What is PyPy?
==============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7.6 or 3.2.5. It's fast due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64, Windows,
and OpenBSD,
as well as newer ARM hardware (ARMv6 or ARMv7, with VFPv3) running Linux.

While we support 32 bit python on Windows, work on the native Windows 64
bit python is still stalling, we would welcome a volunteer
to `handle that`_.

.. _`handle that`: https://doc.pypy.org/en/latest/windows.html#what-is-missing-for-a-full-64-bit-translation

How to use PyPy?
=================

We suggest using PyPy from a `virtualenv`_. Once you have a virtualenv
installed, you can follow instructions from `pypy documentation`_ on how
to proceed. This document also covers other `installation schemes`_.

.. _donated: https://morepypy.blogspot.com/2012/01/py3k-and-numpy-first-stage-thanks-to.html
.. _`py3k proposal`: https://pypy.org/py3donate.html
.. _`pypy documentation`: https://doc.pypy.org/en/latest/getting-started.html#installing-using-virtualenv
.. _`virtualenv`: https://www.virtualenv.org/en/latest/
.. _`installation schemes`: https://doc.pypy.org/en/latest/getting-started.html#installing-pypy


Cheers,
the PyPy team
