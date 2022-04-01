=========================================
PyPy v7.1.0: release of 2.7, and 3.6-beta
=========================================

The PyPy team is proud to release the version 7.1.0 of PyPy, which includes
two different interpreters:

  - PyPy2.7, which is an interpreter supporting the syntax and the features of
    Python 2.7

  - PyPy3.6-beta: this is the second official release of PyPy to support 3.6
    features, although it is still considered beta quality.
    
The interpreters are based on much the same codebase, thus the double
release.

This release, coming fast on the heels of 7.0 in February, finally merges the
internal refactoring of unicode representation as UTF-8. Removing the
conversions from strings to unicode internally lead to a nice speed bump.

We also improved the ability to use the buffer protocol with ctype structures
and arrays.

Until we can work with downstream providers to distribute builds with PyPy, we
have made packages for some common packages `available as wheels`_.

The `CFFI`_ backend has been updated to version 1.12.2. We recommend using CFFI
rather than c-extensions to interact with C, and `cppyy`_ for interacting with
C++ code.

As always, this release is 100% compatible with the previous one and fixed
several issues and bugs raised by the growing community of PyPy users.
We strongly recommend updating.

The PyPy3.6 release is still not production quality so your mileage may vary.
There are open issues with incomplete compatibility and c-extension support.

You can download the v7.1 releases here:

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
.. _`CFFI`: https://cffi.readthedocs.io
.. _`cppyy`: https://cppyy.readthedocs.io
.. _`available as wheels`: https://github.com/antocuni/pypy-wheels

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

Changes shared across versions

* Use utf8 internally to represent unicode, with the goal of never using
  rpython-level unicode
* Update ``cffi`` to 1.12.2
* Improve performance of ``long`` operations where one of the operands fits
  into an ``int``
* Since _ctypes is implemented in pure python over libffi, add interfaces and
  methods to support the buffer interface from python. Specifically, add a
  ``__pypy__.newmemoryview`` function to create a memoryview and extend the use
  of the PyPy-specific ``__buffer__`` class method. This enables better
  buffer sharing between ctypes and NumPy.
* Add copying to zlib
* Improve register allocation in the JIT by using better heuristics
* Include ``<sys/sysmacros.h>`` on Gnu/Hurd
* Mostly for completeness sake: support for ``rlib.jit.promote_unicode``, which
  behaves like ``promote_string``, but for rpython unicode objects
* Correctly initialize the ``d_type`` and ``d_name`` members of builtin
  descriptors to fix a segfault related to classmethods in Cython
* Expand documentation of ``__pypy_`` module

C-API (cpyext) improvements shared across versions

* Move PyTuple_Type.tp_new to C
* Call internal methods from ``PyDict_XXXItem()`` instead of going through
  dunder methods (CPython cpyext compatibility)

Python 3.6 only

* Support for os.PathLike in the posix module
* Update ``idellib`` for 3.6.1
* Make ``BUILD_CONST_KEY_MAP`` JIT-friendly
* Adapt code that optimizes ``sys.exc_info()`` to wordcode
* Fix annotation bug found by ``attrs``
