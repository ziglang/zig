===============
PyPy 2.1 beta 2
===============

We're pleased to announce the second beta of the upcoming 2.1 release of PyPy.
This beta adds one new feature to the 2.1 release and contains several bugfixes listed below.

You can download the PyPy 2.1 beta 1 release here:

    https://pypy.org/download.html

Highlights
==========

* Support for os.statvfs and os.fstatvfs on unix systems.

* Fixed issue `1533`_: fix an RPython-level OverflowError for space.float_w(w_big_long_number). 

* Fixed issue `1552`_: GreenletExit should inherit from BaseException.

* Fixed issue `1537`_: numpypy __array_interface__
  
* Fixed issue `1238`_: Writing to an SSL socket in pypy sometimes failed with a "bad write retry" message.

* `distutils`_: copy CPython's implementation of customize_compiler, dont call
  split on environment variables, honour CFLAGS, CPPFLAGS, LDSHARED and
  LDFLAGS.

* During packaging, compile the CFFI tk extension.

.. _`1533`: https://bugs.pypy.org/issue1533
.. _`1552`: https://bugs.pypy.org/issue1552
.. _`1537`: https://bugs.pypy.org/issue1537
.. _`1238`: https://bugs.pypy.org/issue1238
.. _`distutils`: https://bitbucket.org/pypy/pypy/src/0c6eeae0316c11146f47fcf83e21e24f11378be1/?at=distutils-cppldflags


What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7.3. It's fast due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64 or Windows
32. Also this release supports ARM machines running Linux 32bit - anything with
``ARMv6`` (like the Raspberry Pi) or ``ARMv7`` (like Beagleboard,
Chromebook, Cubieboard, etc.) that supports ``VFPv3`` should work.

Windows 64 work is still stalling, we would welcome a volunteer
to handle that.

How to use PyPy?
================

We suggest using PyPy from a `virtualenv`_. Once you have a virtualenv
installed, you can follow instructions from `pypy documentation`_ on how
to proceed. This document also covers other `installation schemes`_.

.. _`pypy documentation`: https://doc.pypy.org/en/latest/getting-started.html#installing-using-virtualenv
.. _`virtualenv`: https://www.virtualenv.org/en/latest/
.. _`installation schemes`: https://doc.pypy.org/en/latest/getting-started.html#installing-pypy
.. _`PyPy and pip`: https://doc.pypy.org/en/latest/getting-started.html#installing-pypy


Cheers,
The PyPy Team.
