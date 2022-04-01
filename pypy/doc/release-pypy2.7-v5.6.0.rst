============
PyPy2.7 v5.6
============

We have released PyPy2.7 v5.6, about two months after PyPy2.7 v5.4.
This new PyPy2.7 release includes the upstream stdlib version 2.7.12.

We continue to make incremental improvements to our C-API
compatibility layer (cpyext). We pass all but a few of the tests in the
upstream numpy test suite. 

Work proceeds at a good pace on the PyPy3.5
version due to a grant_ from the Mozilla Foundation, and some of those
changes have been backported to PyPy2.7 where relevant.

The PowerPC and s390x backend have been enhanced_ with the capability use SIMD instructions
 for micronumpy loops.

We changed ``timeit`` to now report average +- standard deviation, which is
better than the misleading minimum value reported in CPython.

We now support building PyPy with OpenSSL 1.1 in our built-in _ssl module, as
well as maintaining support for previous versions.

CFFI_ has been updated to 1.9, improving an already great package for
interfacing with C.

As always, this release fixed many issues and bugs raised by the
growing community of PyPy users. We strongly recommend updating.

You can download the PyPy2.7 v5.6 release here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project.

We would also like to thank our contributors and
encourage new people to join the project. PyPy has many
layers and we need help with all of them: `PyPy`_ and `RPython`_ documentation
improvements, tweaking popular `modules`_ to run on pypy, or general `help`_
with making RPython's JIT even better.

.. _CFFI: https://cffi.readthedocs.io/en/latest/whatsnew.html
.. _grant: https://morepypy.blogspot.com/2016/08/pypy-gets-funding-from-mozilla-for.html
.. _`PyPy`: https://doc.pypy.org
.. _`RPython`: https://rpython.readthedocs.org
.. _`modules`: https://doc.pypy.org/en/latest/project-ideas.html#make-more-python-modules-pypy-friendly
.. _`help`: https://doc.pypy.org/en/latest/project-ideas.html
.. _`enhanced`: https://morepypy.blogspot.co.at/2016/11/vectorization-extended-powerpc-and-s390x.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`PyPy and CPython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

This release supports: 

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 32 bits, OpenBSD, FreeBSD)
  
  * newer **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux,
  
  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

Other Highlights (since 5.4 released Aug 31, 2016)
=========================================================

* New features

  * Allow tests run with `-A` to find `libm.so` even if it is a script not a
    dynamically loadable file
  * Backport fixes to rposix on windows from py3.5
  * Allow user-defined ``__getitem__`` on subclasses of ``str`` and ``unicode``
  * Add ``inode`` to ``scandir()`` on posix systems
  * Support more attributes on ``super``
  * Issue #2386: non-latin1 unicode keys were ignored in ``unicode.format(**d)``
  * Restore the ability to translate with CPython
  * Update to CFFI 1.9.0
  * Support the new buffer protocol in cpyext and numpypy
  * Add ``rposix.sync()``
  * Support full-precision nanosecond times in os.stat()
  * Add documentation about the assembler backends to RPYthon
  * Search for the stdlibs from the libpypy shared object rather than the pypy-c exe,
    changes downstream packaging requirements
  * Add ``try_inline``, like ``always_inline`` and ``dont_inline`` to RPython
  * Reject ``'a'.strip(buffer(' '))`` like cpython (the argument to strip must
    be ``str`` or ``unicode``)
  * Allow ``warning.warn(('something', 1), Warning)`` like on CPython
  * Refactor ``rclock`` and add some more ``CLOCK_xxx`` constants on
    relevant platforms
  * Backport the ``faulthandler`` module from py3.5
  * Improve the error message when trying to call a method where the ``self``
    parameter is missing in the definition
  * Implement ``rposix.cpu_count``
  * Support translation on FreeBSD running on PowerPC
  * Implement ``__rmod__`` on ``str`` and ``unicode`` types
  * Issue warnings for stricter handling of ``__new__``, ``__init__`` args
  * When using ``struct.unpack('q', ...`` try harder to prefer int to long
  * Support OpenSSL version 1.1 (in addition to version 1.0)

* Bug Fixes

  * Tweak a float comparison with 0 in `backendopt.inline` to avoid rounding errors
  * Fix translation of the sandbox
  * Fix for an issue where `unicode.decode('utf8', 'custom_replace')` messed up
    the last byte of a unicode string sometimes
  * fix some calls to functions through window's COM interface
  * fix minor leak when the C call to socketpair() fails
  * make sure (-1.0 + 0j).__hash__(), (-1.0).__hash__() returns -2
  * Fix for an issue where PyBytesResize was called on a fresh pyobj
  * Fix bug in codewriter about passing the ``exitswitch`` variable to a call
  * Don't crash in ``merge_if_blocks`` if the values are symbolics
  * Issue #2325/2361: __class__ assignment between two classes with the same
    slots
  * Issue #2409: don't leak the file descriptor when doing ``open('some-dir')``
  * Windows fixes around vmprof
  * Don't use ``sprintf()`` from inside a signal handler
  * Test and fix bug from the ``guard_not_forced_2`` branch, which didn't
    save the floating-point register
  * ``_numpypy.add.reduce`` returns a scalar now

* Performance improvements:

  * Improve method calls on oldstyle classes
  * Clean and refactor code for testing cpyext to allow sharing with py3.5
  * Refactor a building the map of reflected ops in ``_numpypy``
  * Improve merging of virtual states in the JIT in order to avoid jumping to the
    preamble
  * In JIT residual calls, if the called function starts with a fast-path like
    ``if x.foo != 0: return x.foo``, then inline the check before doing the
    ``CALL``.
  * Ensure ``make_inputargs`` fails properly when given arguments with type 
    information
  * Makes ``optimiseopt`` iterative instead of recursive so it can be reasoned
    about more easily and debugging is faster
  * Refactor and remove dead code from ``optimizeopt``, ``resume``
  

.. _resolved: https://doc.pypy.org/en/latest/whatsnew-5.6.0.html

Please update, and continue to help us make PyPy better.

Cheers
