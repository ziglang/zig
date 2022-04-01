==========
PyPy 5.7.1
==========

We have released a bugfix PyPy2.7-v5.7.1 and PyPy3.5-v5.7.1 beta (Linux 64bit),
due to the following issues:

  * correctly handle an edge case in dict.pop (issue 2508_)

  * fix a regression to correctly handle multiple inheritance in a C-API type
    where the second base is an app-level class with a ``__new__`` function

  * fix a regression to fill a C-API type's ``tp_getattr`` slot from a
    ``__getattr__`` method (issue 2523_)

Thanks to those who reported the issues.

.. _2508: https://bitbucket.org/pypy/pypy/issues/2508
.. _2523: https://bitbucket.org/pypy/pypy/issues/2523

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7 and CPython 3.5. It's fast (`PyPy and CPython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

The PyPy 2.7 release supports: 

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 32 bits, OpenBSD, FreeBSD)
  
  * newer **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux,
  
  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

Please update, and continue to help us make PyPy better.

Cheers

The PyPy Team

