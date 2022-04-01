==========
PyPy 5.0.1
==========

We have released a bugfix for PyPy 5.0, after reports that the newly released
`lxml 3.6.0`_, which now supports PyPy 5.0 +, can `crash on large files`_.
Thanks to those who reported the crash. Please update, downloads are available
at pypy.org/download.html

.. _`lxml 3.6.0`: https://pypi.python.org/pypi/lxml/3.6.0
.. _`crash on large files`: https://bitbucket.org/pypy/pypy/issues/2260

The changes between PyPy 5.0 and 5.0.1 are only two bug fixes: one in
cpyext, which fixes notably (but not only) lxml; and another for a
corner case of the JIT.

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`PyPy and CPython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

We also welcome developers of other
`dynamic languages`_ to see what RPython can do for them.

This release supports **x86** machines on most common operating systems
(Linux 32/64, Mac OS X 64, Windows 32, OpenBSD, FreeBSD),
newer **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux, and the
big- and little-endian variants of **PPC64** running Linux.

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://pypyjs.org

Please update, and continue to help us make PyPy better.

Cheers

The PyPy Team

