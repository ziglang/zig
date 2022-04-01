=======================================
PyPy 2.2.1 - Incrementalism.1
=======================================

We're pleased to announce PyPy 2.2.1, which targets version 2.7.3 of the Python
language. This is a bugfix release over 2.2.

You can download the PyPy 2.2.1 release here:

    https://pypy.org/download.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy 2.2 and cpython 2.7.2`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64, Windows
32, or ARM (ARMv6 or ARMv7, with VFPv3).

Work on the native Windows 64 is still stalling, we would welcome a volunteer
to handle that.

.. _`pypy 2.2 and cpython 2.7.2`: https://speed.pypy.org

Highlights
==========

This is a bugfix release.  The most important bugs fixed are:

* an issue in sockets' reference counting emulation, showing up
  notably when using the ssl module and calling ``makefile()``.

* Tkinter support on Windows.

* If sys.maxunicode==65535 (on Windows and maybe OS/X), the json
  decoder incorrectly decoded surrogate pairs.

* some FreeBSD fixes.

Note that CFFI 0.8.1 was released.  Both versions 0.8 and 0.8.1 are
compatible with both PyPy 2.2 and 2.2.1.


Cheers,
Armin Rigo & everybody
