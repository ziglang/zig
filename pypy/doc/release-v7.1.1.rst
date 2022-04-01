=========================================
PyPy v7.1.1: release of 2.7, and 3.6-beta
=========================================

The PyPy team is proud to release a bug-fix release version 7.1.1 of PyPy, which
includes two different interpreters:

  - PyPy2.7, which is an interpreter supporting the syntax and the features of
    Python 2.7

  - PyPy3.6-beta: this is the second official release of PyPy to support 3.6
    features, although it is still considered beta quality.
    
The interpreters are based on much the same codebase, thus the double
release.

As always, this release is 100% compatible with the previous one and fixed
several issues and bugs raised by the growing community of PyPy users.
We strongly recommend updating.

The PyPy3.6 release is still not production quality so your mileage may vary.
There are open issues with incomplete compatibility and c-extension support.

You can download the v7.1.1 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work.

We would also like to thank our contributors and encourage new people to join
the project. PyPy has many layers and we need help with all of them: `PyPy`_
and `RPython`_ documentation improvements, tweaking popular modules to run
on pypy, or general `help`_ with making RPython's JIT even better.

.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`help`: project-ideas.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7, 3.6. It's fast (`PyPy and CPython 2.7.x`_ performance
comparison) due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

This PyPy release supports:

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 32 bits, OpenBSD, FreeBSD)

  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

Unfortunately at the moment of writing our ARM buildbots are out of service,
so for now we are **not** releasing any binary for the ARM architecture,
although PyPy does support ARM 32 bit processors.

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html


Changelog
=========

Changes shared across versions:

* Improve performance of ``u''.append``

* Prevent a crash in ``zlib`` when flushing a closed stream

* Fix a few corner cases when encountering unicode values above 0x110000

* Teach the JIT how to handle very large constant lists, sets, or dicts
* Fix building on ARM32 (issue 2984_)
* Fix a bug in register assignment in ARM32
* Package windows DLLs needed by cffi modules next to the cffi c-extensions
  (issue 2988_)
* Cleanup and refactor JIT code to remove ``rpython.jit.metainterp.typesystem``
* Fix memoryviews of ctype structures with padding, (cpython issue 32780_)
* CFFI updated to as-yet-unreleased 1.12.3

Python 3.6 only:

* Override some ``errno.E*`` values that were added to MSVC in v2010
  so that ``errno.E* == errno.WSAE*`` as in CPython
* Do the same optimization that CPython does for ``(1, 2, 3, *a)`` (but at the
  AST level)
* ``str.maketrans`` was broken (issue 2991_)
* Raise a ``TypeError`` when using buffers and unicode such as ``''.strip(buffer)``
  and ``'a' < buffer``
* Support ``_overlapped`` and asyncio on win32
* Fix an issue where ``''.join(list_of_strings)`` would rarely confuse utf8 and
  bytes (issue 2997_)

.. _2984: https://bitbucket.org/pypy/pypy/issues/2984
.. _2991: https://bitbucket.org/pypy/pypy/issues/2991
.. _2988: https://bitbucket.org/pypy/pypy/issues/2988
.. _2997: https://bitbucket.org/pypy/pypy/issues/2997
.. _32780: https://bugs.python.org/issue32780
