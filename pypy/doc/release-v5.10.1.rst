===========
PyPy 5.10.1
===========

We have released a bugfix PyPy3.5-v5.10.1
due to the following issues:

  * Fix ``time.sleep(float('nan')`` which would hang on windows

  * Fix missing ``errno`` constants on windows

  * Fix issue 2718_ for the REPL on linux

  * Fix an overflow in converting 3 secs to nanosecs (issue 2717_ )

  * Flag kwarg to ``os.setxattr`` had no effect

  * Fix the winreg module for unicode entries in the registry on windows

Note that many of these fixes are for our new beta verison of PyPy3.5 on
windows. There may be more unicode problems in the windows beta version
especially around the subject of directory- and file-names with non-ascii
characters.

Our downloads are available now. On macos, we recommend you wait for the
Homebrew_ package.

Thanks to those who reported the issues.

.. _2718: https://bitbucket.org/pypy/pypy/issues/2718
.. _2717: https://bitbucket.org/pypy/pypy/issues/2717
.. _Homebrew: https://brewformulas.org/Pypy

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7 and CPython 3.5. It's fast (`PyPy and CPython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

This PyPy 3.5 release supports: 

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

