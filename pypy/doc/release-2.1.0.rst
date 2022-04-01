============================
PyPy 2.1 - Considered ARMful
============================

We're pleased to announce PyPy 2.1, which targets version 2.7.3 of the Python
language. This is the first release with official support for ARM processors in the JIT.
This release also contains several bugfixes and performance improvements. 

You can download the PyPy 2.1 release here:

    https://pypy.org/download.html

We would like to thank the `Raspberry Pi Foundation`_ for supporting the work
to finish PyPy's ARM support.

.. _`Raspberry Pi Foundation`: https://www.raspberrypi.org

The first beta of PyPy3 2.1, targeting version 3 of the Python language, was
just released, more details can be found `here`_.

.. _`here`: https://morepypy.blogspot.com/2013/07/pypy3-21-beta-1.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy 2.1 and cpython 2.7.2`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64 or Windows
32. This release also supports ARM machines running Linux 32bit - anything with
``ARMv6`` (like the Raspberry Pi) or ``ARMv7`` (like the Beagleboard,
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

.. _`pypy 2.1 and cpython 2.7.2`: https://speed.pypy.org

Highlights
==========

* JIT support for ARM, architecture versions 6 and 7, hard- and soft-float ABI

* Stacklet support for ARM

* Support for os.statvfs and os.fstatvfs on unix systems

* Improved logging performance

* Faster sets for objects

* Interpreter improvements

* During packaging, compile the CFFI based TK extension

* Pickling of numpy arrays and dtypes 

* Subarrays for numpy

* Bugfixes to numpy

* Bugfixes to cffi and ctypes

* Bugfixes to the x86 stacklet support

* Fixed issue `1533`_: fix an RPython-level OverflowError for space.float_w(w_big_long_number). 

* Fixed issue `1552`_: GreenletExit should inherit from BaseException.

* Fixed issue `1537`_: numpypy __array_interface__
  
* Fixed issue `1238`_: Writing to an SSL socket in PyPy sometimes failed with a "bad write retry" message.

.. _`1533`: https://bugs.pypy.org/issue1533
.. _`1552`: https://bugs.pypy.org/issue1552
.. _`1537`: https://bugs.pypy.org/issue1537
.. _`1238`: https://bugs.pypy.org/issue1238

Cheers,

David Schneider for the PyPy team.
