========
PyPy 5.1
========

We have released PyPy 5.1, about a month after PyPy 5.0.

This release includes more improvement to warmup time and memory
requirements. We have seen about a 20% memory requirement reduction and up to
30% warmup time improvement, more detail in the `blog post`_.

We also now have `fully support for the IBM s390x`_. Since this support is in
`RPython`_, any dynamic language written using RPython, like PyPy, will
automagically be supported on that architecture.  

We updated cffi_ to 1.6, and continue to improve support for the wider
python ecosystem using the PyPy interpreter.

You can download the PyPy 5.1 release here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project.

We would also like to thank our contributors and
encourage new people to join the project. PyPy has many
layers and we need help with all of them: `PyPy`_ and `RPython`_ documentation
improvements, tweaking popular `modules`_ to run on pypy, or general `help`_
with making RPython's JIT even better.

.. _`PyPy`: https://doc.pypy.org
.. _`RPython`: https://rpython.readthedocs.org
.. _`modules`: https://doc.pypy.org/en/latest/project-ideas.html#make-more-python-modules-pypy-friendly
.. _`help`: https://doc.pypy.org/en/latest/project-ideas.html
.. _`numpy`: https://bitbucket.org/pypy/numpy
.. _cffi: https://cffi.readthedocs.org
.. _`fully support for the IBM s390x`: https://morepypy.blogspot.com/2016/04/pypy-enterprise-edition.html
.. _`blog post`: https://morepypy.blogspot.com/2016/04/warmup-improvements-more-efficient.html

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

Other Highlights (since 5.0 released in March 2015)
=========================================================

* New features:

  * A new jit backend for the IBM s390x, which was a large effort over the past
    few months.

  * Add better support for PyUnicodeObject in the C-API compatibility layer

  * Support GNU/kFreeBSD Debian ports in vmprof

  * Add __pypy__._promote

  * Make attrgetter a single type for CPython compatibility

* Bug Fixes

  * Catch exceptions raised in an exit function

  * Fix a corner case in the JIT

  * Fix edge cases in the cpyext refcounting-compatible semantics
    (more work on cpyext compatibility is coming in the ``cpyext-ext``
    branch, but isn't ready yet)

  * Try harder to not emit NEON instructions on ARM processors without NEON
    support

  * Improve the rpython posix module system interaction function calls

  * Detect a missing class function implementation instead of calling a random
    function

  * Check that PyTupleObjects do not contain any NULLs at the
    point of conversion to W_TupleObjects

  * In ctypes, fix _anonymous_ fields of instances

  * Fix JIT issue with unpack() on a Trace which contains half-written operations

  * Fix sandbox startup (a regression in 5.0)

  * Fix possible segfault for classes with mangled mro or __metaclass__

  * Fix isinstance(deque(), Hashable) on the pure python deque

  * Fix an issue with forkpty()

  * Issues reported with our previous release were resolved_ after reports from users on
    our issue tracker at https://bitbucket.org/pypy/pypy/issues or on IRC at
    #pypy

* Numpy_:

  * Implemented numpy.where for a single argument

  * Indexing by a numpy scalar now returns a scalar

  * Fix transpose(arg) when arg is a sequence

  * Refactor include file handling, now all numpy ndarray, ufunc, and umath
    functions exported from libpypy.so are declared in pypy_numpy.h, which is
    included only when building our fork of numpy

  * Add broadcast

* Performance improvements:

  * Improve str.endswith([tuple]) and str.startswith([tuple]) to allow JITting

  * Merge another round of improvements to the warmup performance

  * Cleanup history rewriting in pyjitpl

  * Remove the forced minor collection that occurs when rewriting the
    assembler at the start of the JIT backend

  * Port the resource module to cffi

* Internal refactorings:

  * Use a simpler logger to speed up translation

  * Drop vestiges of Python 2.5 support in testing

  * Update rpython functions with ones needed for py3k

.. _resolved: https://doc.pypy.org/en/latest/whatsnew-5.0.0.html
.. _Numpy: https://bitbucket.org/pypy/numpy

Please update, and continue to help us make PyPy better.

Cheers

The PyPy Team

