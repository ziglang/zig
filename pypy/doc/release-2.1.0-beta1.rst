===============
PyPy 2.1 beta 1
===============

We're pleased to announce the first beta of the upcoming 2.1 release of PyPy.
This beta contains many bugfixes and improvements, numerous improvements to the
numpy in pypy effort. The main feature being that the ARM processor support is
not longer considered alpha level. We would like to thank the `Raspberry Pi
Foundation`_ for supporting the work to finish PyPy's ARM support.

You can download the PyPy 2.1 beta 1 release here:

    https://pypy.org/download.html 

.. _`Raspberry Pi Foundation`: https://www.raspberrypi.org

Highlights
==========

* Bugfixes to the ARM JIT backend, so that ARM is now an officially
  supported processor architecture

* Stacklet support on ARM

* Interpreter improvements

* Various numpy improvements

* Bugfixes to cffi and ctypes

* Bugfixes to the stacklet support

* Improved logging performance

* Faster sets for objects

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7.3. It's fast due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64 or Windows
32. Also this release supports ARM machines running Linux 32bit - anything with
``ARMv6`` (like the Raspberry Pi) or ``ARMv7`` (like Beagleboard,
Chromebook, Cubieboard, etc.) that supports ``VFPv3`` should work. Both
hard-float ``armhf/gnueabihf`` and soft-float ``armel/gnueabi`` builds are
provided. ``armhf`` builds for Raspbian are created using the Raspberry Pi
`custom cross-compilation toolchain <https://github.com/raspberrypi>`_
based on ``gcc-arm-linux-gnueabihf`` and should work on ``ARMv6`` and
``ARMv7`` devices running Debian or Raspbian. ``armel`` builds are built
using the ``gcc-arm-linux-gnuebi`` toolchain provided by Ubuntu and
currently target ``ARMv7``.

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
the PyPy team
