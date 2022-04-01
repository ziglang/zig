======================================
PyPy2.7 and PyPy3.5 v6.0 dual release
======================================

The PyPy team is proud to release both PyPy2.7 v6.0 (an interpreter supporting
Python 2.7 syntax), and a PyPy3.5 v6.0 (an interpreter supporting Python
3.5 syntax). The two releases are both based on much the same codebase, thus
the dual release.

This release is a feature release following our previous 5.10 incremental
release in late December 2017. Our C-API compatibility layer ``cpyext`` is
now much faster (see the `blog post`_) as well as more complete. We have made
many other improvements in speed and CPython compatibility. Since the changes
affect the included python development header files, all c-extension modules must
be recompiled for this version.

Until we can work with downstream providers to distribute builds with PyPy, we
have made packages for some common packages `available as wheels`_. You may
compile yourself using ``pip install --no-build-isolation <package>``, the
``no-build-isolation`` is currently needed for pip v10.

First-time python users are often stumped by silly typos and omissions when
getting started writing code. We have improved our parser to emit more friendly
`syntax errors`_,  making PyPy not only faster but more friendly.

The GC now has `hooks`_ to gain more insights into its performance

The Matplotlib TkAgg backend now works with PyPy, as do pygame and pygobject_.

We updated the `cffi`_ module included in PyPy to version 1.11.5, and the
`cppyy`_ backend to 0.6.0. Please use these to wrap your C and C++ code,
respectively, for a JIT friendly experience.

As always, this release is 100% compatible with the previous one and fixed
several issues and bugs raised by the growing community of PyPy users.
We strongly recommend updating.

The Windows PyPy3.5 release is still considered beta-quality. There are open
issues with unicode handling especially around system calls and c-extensions.

The utf8 branch that changes internal representation of unicode to utf8 did not
make it into the release, so there is still more goodness coming. We also
began working on a Python3.6 implementation, help is welcome.

You can download the v6.0 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work.

We would also like to thank our contributors and encourage new people to join
the project. PyPy has many layers and we need help with all of them: `PyPy`_
and `RPython`_ documentation improvements, tweaking popular `modules`_ to run
on pypy, or general `help`_ with making RPython's JIT even better.

.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`modules`: project-ideas.html#make-more-python-modules-pypy-friendly
.. _`help`: project-ideas.html
.. _`blog post`: https://morepypy.blogspot.it/2017/10/cape-of-good-hope-for-pypy-hello-from.html
.. _pygobject: https://lazka.github.io/posts/2018-04_pypy-pygobject/index.html
.. _`syntax errors`: https://morepypy.blogspot.com/2018/04/improving-syntaxerror-in-pypy.html
.. _`hooks`: gc_info.html#gc-hooks
.. _`cffi`: https://cffi.readthedocs.io
.. _`cppyy`: https://cppyy.readthedocs.io
.. _`available as wheels`: https://github.com/antocuni/pypy-wheels

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7 and CPython 3.5. It's fast (`PyPy and CPython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

The PyPy release supports:

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 32 bits, OpenBSD, FreeBSD)

  * newer **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux,

  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

Changelog
=========

* Speed up C-API method calls, and make most Py*_Check calls C macros
* Speed up C-API slot method calls
* Enable TkAgg backend support for matplotlib
* support ``hastzinfo`` and ``tzinfo`` in the C-API ``PyDateTime*`` structures
* datetime.h is now more similar to CPython
* We now support ``PyUnicode_AsUTF{16,32}String``, ``_PyLong_AsByteArray``,
  ``_PyLong_AsByteArrayO``,
* PyPy3.5 on Windows is compiled with the Microsoft Visual Compiler v14, like
  CPython
* Fix performance of attribute lookup when more than 80 attributes are used
* Improve performance on passing built-in types to C-API C code
* Improve the performance of datetime and timedelta by skipping the consistency
  checks of the datetime values (they are correct by construction)
* Improve handling of ``bigint`` s, including fixing ``int_divmod``
* Improve reporting of GC statistics
* Accept unicode filenames in ``dbm.open()``
* Improve RPython support for half-floats
* Added missing attributes to C-API ``instancemethod`` on pypy3
* Store error state in thread-local storage for C-API.
* Fix JIT bugs exposed in the sre module
* Improve speed of Python parser, improve ParseError messages and SyntaxError
* Handle JIT hooks more efficiently
* Fix a rare GC bug exposed by intensive use of cpyext ``Buffer`` s

We also refactored many parts of the JIT bridge optimizations, as well as cpyext
internals, and together with new contributors fixed issues, added new
documentation, and cleaned up the codebase.
