==========
PyPy 5.1.1
==========

We have released a bugfix for PyPy 5.1, due to a regression_ in
installing third-party packages dependant on numpy (using our numpy fork
available at https://bitbucket.org/pypy/numpy ).

Thanks to those who reported the issue. We also fixed a regression in
translating PyPy which increased the memory required to translate. Improvement
will be noticed by downstream packagers and those who translate rather than
download pre-built binaries.

.. _regression: https://bitbucket.org/pypy/pypy/issues/2282

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`PyPy and CPython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

We also welcome developers of other
`dynamic languages`_ to see what RPython can do for them.

This release supports:

  * **x86** machines on most common operating systems
    (Linux 32/64, Mac OS X 64, Windows 32, OpenBSD, FreeBSD),

  * newer **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux,

  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://pypyjs.org

Please update, and continue to help us make PyPy better.

Cheers

The PyPy Team

