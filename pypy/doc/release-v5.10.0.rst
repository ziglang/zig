======================================
PyPy2.7 and PyPy3.5 v5.10 dual release
======================================

The PyPy team is proud to release both PyPy2.7 v5.10 (an interpreter supporting
Python 2.7 syntax), and a final PyPy3.5 v5.10 (an interpreter for Python
3.5 syntax). The two releases are both based on much the same codebase, thus
the dual release.

This release is an incremental release with very few new features, the main
feature being the final PyPy3.5 release that works on linux and OS X with beta
windows support. It also includes fixes for `vmprof`_ cooperation with greenlets.

Compared to 5.9, the 5.10 release contains mostly bugfixes and small improvements.
We have in the pipeline big new features coming for PyPy 6.0 that did not make
the release cut and should be available within the next couple months.

As always, this release is 100% compatible with the previous one and fixed
several issues and bugs raised by the growing community of PyPy users.
As always, we strongly recommend updating.

There are quite a few important changes that are in the pipeline that did not
make it into the 5.10 release. Most important are speed improvements to cpyext
(which will make numpy and pandas a bit faster) and utf8 branch that changes
internal representation of unicode to utf8, which should help especially the
Python 3.5 version of PyPy.

This release concludes the Mozilla Open Source `grant`_ for having a compatible
PyPy 3.5 release and we're very grateful for that.  Of course, we will continue
to improve PyPy 3.5 and probably move to 3.6 during the course of 2018.

You can download the v5.10 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project.

We would also like to thank our contributors and
encourage new people to join the project. PyPy has many
layers and we need help with all of them: `PyPy`_ and `RPython`_ documentation
improvements, tweaking popular `modules`_ to run on pypy, or general `help`_
with making RPython's JIT even better.

.. _vmprof: https://vmprof.readthedocs.io
.. _grant: https://morepypy.blogspot.com/2016/08/pypy-gets-funding-from-mozilla-for.html
.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`modules`: project-ideas.html#make-more-python-modules-pypy-friendly
.. _`help`: project-ideas.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7 and CPython 3.5. It's fast (`PyPy and CPython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

The PyPy release supports: 

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 32 bits, OpenBSD, FreeBSD)
  
  * newer **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux,
  
  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

Changelog
=========

* improve ssl handling on windows for pypy3 (makes pip work)
* improve unicode handling in various error reporters
* fix vmprof cooperation with greenlets
* fix some things in cpyext
* test and document the cmp(nan, nan) == 0 behaviour
* don't crash when calling sleep with inf or nan
* fix bugs in _io module
* inspect.isbuiltin() now returns True for functions implemented in C
* allow the sequences future-import, docstring, future-import for CPython bug compatibility
* Issue #2699: non-ascii messages in warnings
* posix.lockf
* fixes for FreeBSD platform
* add .debug files, so builds contain debugging info, instead of being stripped
* improvements to cppyy
* issue #2677 copy pure c PyBuffer_{From,To}Contiguous from cpython
* issue #2682, split firstword on any whitespace in sqlite3
* ctypes: allow ptr[0] = foo when ptr is a pointer to struct
* matplotlib will work with tkagg backend once `matplotlib pr #9356`_ is merged
* improvements to utf32 surrogate handling
* cffi version bump to 1.11.2

.. _`matplotlib pr #9356`: https://github.com/matplotlib/matplotlib/pull/9356
