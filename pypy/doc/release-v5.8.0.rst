=====================================
PyPy2.7 and PyPy3.5 v5.8 dual release
=====================================

The PyPy team is proud to release both PyPy2.7 v5.8 (an interpreter supporting
Python 2.7 syntax), and a beta-quality PyPy3.5 v5.8 (an interpreter for Python
3.5 syntax). The two releases are both based on much the same codebase, thus
the dual release.  Note that PyPy3.5 supports Linux 64bit only for now. 

This new PyPy2.7 release includes the upstream stdlib version 2.7.13, and
PyPy3.5 includes the upstream stdlib version 3.5.3.

We fixed critical bugs in the shadowstack_ rootfinder garbage collector
strategy that crashed multithreaded programs and very rarely showed up
even in single threaded programs.

We added native PyPy support to profile frames in the vmprof_ statistical
profiler.

The ``struct`` module functions ``pack*`` and ``unpack*`` are now much faster,
especially on raw buffers and bytearrays. Microbenchmarks show a 2x to 10x
speedup. Thanks to `Gambit Research`_ for sponsoring this work.

This release adds (but disables by default) link-time optimization and
`profile guided optimization`_ of the base interpreter, which may make
unjitted code run faster. To use these, translate with appropriate
`options`_.  Be aware of `issues with gcc toolchains`_, though.

Please let us know if your use case is slow, we have ideas how to make things
faster but need real-world examples (not micro-benchmarks) of problematic code.

Work sponsored by a Mozilla grant_ continues on PyPy3.5; numerous fixes from
CPython were ported to PyPy and PEP 489 was fully implemented. Of course the
bug fixes and performance enhancements mentioned above are part of both PyPy
2.7 and PyPy 3.5.

CFFI_, which is part of the PyPy release, has been updated to an unreleased 1.10.1,
improving an already great package for interfacing with C.

As always, this release fixed many other issues and bugs raised by the
growing community of PyPy users. We strongly recommend updating.

You can download the v5.8 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project.

We would also like to thank our contributors and
encourage new people to join the project. PyPy has many
layers and we need help with all of them: `PyPy`_ and `RPython`_ documentation
improvements, tweaking popular `modules`_ to run on pypy, or general `help`_
with making RPython's JIT even better.

.. _`profile guided optimization`: https://pythonfiles.wordpress.com/2017/05/12/enabling-profile-guided-optimizations-for-pypy
.. _shadowstack: config/translation.gcrootfinder.html
.. _vmprof: https://vmprof.readthedocs.io
.. _`issues with gcc toolchains`: https://bitbucket.org/pypy/pypy/issues/2572/link-time-optimization-lto-disabled
.. _CFFI: https://cffi.readthedocs.io/en/latest/whatsnew.html
.. _grant: https://morepypy.blogspot.com/2016/08/pypy-gets-funding-from-mozilla-for.html
.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`modules`: project-ideas.html#make-more-python-modules-pypy-friendly
.. _`help`: project-ideas.html
.. _`options`: config/commandline.html#general-translation-options
.. _`these benchmarks show`: https://morepypy.blogspot.com/2017/03/async-http-benchmarks-on-pypy3.html
.. _`Gambit Research`: https://gambitresearch.com

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

Highlights of the PyPy2.7, cpyext, and RPython changes (since 5.7 released March, 2017)
=======================================================================================

See also issues that were resolved_

Note that these are also merged into PyPy 3.5

* New features and cleanups

  * Implement PyModule_New, Py_GetRecursionLimit, Py_SetRecursionLimit,
    Py_EnterRecursiveCall, Py_LeaveRecursiveCall, populate tp_descr_get and
    tp_descr_set slots,
    add conversions of ``__len__``, ``__setitem__``, ``__delitem__`` to
    appropriate C-API slots
  * Fix for multiple inheritance in app-level for C-API defined classes
  * Revert a change that removed tp_getattr (Part of the 5.7.1 bugfix release)
  * Document more differences with CPython here_
  * Add native PyPy support to profile frames in vmprof
  * Fix an issue with Exception order on failed import
  * Fix for a corner case of __future__ imports
  * Update packaged Windows zlib, sqlite, expat and OpenSSL to versions used
    by CPython
  * Allow windows builds to use ``jom.exe`` for compiling in parallel
  * Rewrite ``itertools.groupby()``, following CPython
  * Backport changes from PyPy 3.5 to minimize the code differences
  * Improve support for BSD using patches contributed by downstream
  * Support profile-guided optimization, enabled with --profopt, , and
    specify training data ``profoptpath``

* Bug Fixes 

  * Correctly handle dict.pop where the popping key is not the same type as the
    dict's and pop is called with a default (Part of the 5.7.1 bugfix release)
  * Improve our file's universal newline .readline implementation for
    ``\n``, ``\r`` confusion
  * Tweak issue where ctype array ``_base`` was set on empty arrays, now it
    is closer to the implementation in CPython
  * Fix critical bugs in shadowstack that crashed multithreaded programs and
    very rarely showed up even in single threaded programs
  * Remove flaky fastpath function call from ctypes
  * Support passing a buffersize of 0 to socket.getsockopt
  * Avoid hash() returning -1 in cpyext

* Performance improvements:

  * Tweaks made to improve performance by reducing the number of guards
    inserted in jitted code, based on feedback from users
  * Add garbage collector memory pressure to some c-level allocations
  * Speed up struck.pack, struck.pack_into
  * Performance tweaks to round(x, n) for the case n == 0
  * Improve zipfile performance by not doing repeated string concatenation

* RPython improvements

  * Improve the default shadowstack garbage collector, fixing a crash with
    multithreaded code and other issues
  * Make sure lstrip consumes the entire string
  * Support posix_fallocate and posix_fadvise, expose them on PyPy3.5
  * Test and fix for int_and() propagating wrong bounds
  * Improve the generated machine code by tracking the (constant) value of
    r11 across intructions.  This lets us avoid reloading r11 with another
    (apparently slowish) "movabs" instruction, replacing it with either
    nothing or a cheaper variant.
  * Performance tweaks in the x86 JIT-generated machine code: rarely taken
    blocks are moved off-line.  Also, the temporary register used to contain
    large constants is reused across instructions. This helps CPUs branch
    predictor
  * Refactor rpython.rtyper.controllerentry to use use ``@specialize`` instead
    of ``._annspecialcase_``
  * Refactor handling of buffers and memoryviews. Memoryviews will now be
    accepted in a few more places, e.g. in compile()


.. _here: cpython_differences.html

Highlights of the PyPy3.5 release (since 5.7 beta released March 2017)
======================================================================

* New features

  * Implement main part of PEP 489 (multi-phase extension module initialization)
  * Add docstrings to various modules and functions
  * Adapt many CPython bug/feature fixes from CPython 3.5 to PyPy3.5
  * Translation succeeds on Mac OS X, unfortunately our buildbot slave cannot
    be updated to the proper development versions of OpenSSL to properly
    package a release.
  * Implement `` _SSLSocket.server_side``
  * Do not silently ignore ``_swappedbytes_`` in ctypes. We now raise a
    ``NotImplementedError``
  * Implement and expose ``msvcrt.SetErrorMode``
  * Implement ``PyModule_GetState``

* Bug Fixes

  * Fix inconsistencies in the xml.etree.ElementTree.Element class, which on
    CPython is hidden by the C version from '_elementree'.
  * OSError(None,None) is different from OSError()
  * Get closer to supporting 32 bit windows, translation now succeeds and most
    lib-python/3/test runs
  * Call ``sys.__interactivehook__`` at startup
  * Let ``OrderedDict.__init__`` behave like CPython wrt. subclasses
    overridding ``__setitem__``

* Performance improvements:

  * Use "<python> -m test" to run the CPython test suite, as documented by CPython,
    instead of our outdated regrverbose.py script
  * Change _cffi_src/openssl/callbacks.py to stop relying on the CPython C API.
  * Avoid importing the full locale module during _io initialization, 
    CPython change fbbf8b160e8d
  * Avoid freezing many app-level modules at translation, avoid importing many
    modules at startup
  * Refactor buffers, which allows an optimization for 
    ``bytearray()[:n].tobytes()``

* The following features of Python 3.5 are not implemented yet in PyPy:

  * PEP 442: Safe object finalization

.. _resolved: whatsnew-pypy2-5.8.0.html

Please update, and continue to help us make PyPy better.

Cheers
