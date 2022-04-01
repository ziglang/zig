==========
PyPy 5.4.1
==========

We have released a bugfix for PyPy2.7-v5.4.0, released last week,
due to the following issues:

  * Update list of contributors in documentation and LICENSE file,
    this was unfortunately left out of 5.4.0. My apologies to the new
    contributors

  * Allow tests run with ``-A`` to find ``libm.so`` even if it is a script not a
    dynamically loadable file

  * Bump ``sys.setrecursionlimit()`` when translating PyPy, for translating with CPython

  * Tweak a float comparison with 0 in ``backendopt.inline`` to avoid rounding errors

  * Fix for an issue for translating the sandbox

  * Fix for and issue where ``unicode.decode('utf8', 'custom_replace')`` messed up
    the last byte of a unicode string sometimes

  * Update built-in cffi_ to version 1.8.1

  * Explicitly detect that we found as-yet-unsupported OpenSSL 1.1, and crash
    translation with a message asking for help porting it

  * Fix a regression where a PyBytesObject was forced (converted to a RPython
    object) when not required, reported as issue #2395

Thanks to those who reported the issues.

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

.. _cffi: https://cffi.readthedocs.io
.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://pypyjs.org

Please update, and continue to help us make PyPy better.

Cheers

The PyPy Team

