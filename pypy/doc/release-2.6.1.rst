==========
PyPy 2.6.1 
==========

We're pleased to announce PyPy 2.6.1, an update to PyPy 2.6.0 released June 1.
We have updated stdlib to 2.7.10, `cffi`_ to version 1.3, extended support for
the new vmprof_ statistical profiler for multiple threads, and increased
functionality of numpy.

You can download the PyPy 2.6.1 release here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project, and our volunteers and contributors.  

.. _`cffi`: https://cffi.readthedocs.org

We would also like to encourage new people to join the project. PyPy has many
layers and we need help with all of them: `PyPy`_ and `RPython`_ documentation
improvements, tweaking popular `modules`_ to run on pypy, or general `help`_ with making
RPython's JIT even better. 

.. _`PyPy`: https://doc.pypy.org 
.. _`RPython`: https://rpython.readthedocs.org
.. _`modules`: https://doc.pypy.org/en/latest/project-ideas.html#make-more-python-modules-pypy-friendly
.. _`help`: https://doc.pypy.org/en/latest/project-ideas.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy and cpython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports **x86** machines on most common operating systems
(Linux 32/64, Mac OS X 64, Windows 32, OpenBSD_, freebsd_),
as well as newer **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux.

We also welcome developers of other
`dynamic languages`_ to see what RPython can do for them.

.. _`pypy and cpython 2.7.x`: https://speed.pypy.org
.. _OpenBSD: https://cvsweb.openbsd.org/cgi-bin/cvsweb/ports/lang/pypy
.. _freebsd: https://svnweb.freebsd.org/ports/head/lang/pypy/
.. _`dynamic languages`: https://pypyjs.org

Highlights 
===========

* Bug Fixes

  * Revive non-SSE2 support

  * Fixes for detaching _io.Buffer*

  * On Windows, close (and flush) all open sockets on exiting

  * Drop support for ancient macOS v10.4 and before

  * Clear up contention in the garbage collector between trace-me-later and pinning

  * Issues reported with our previous release were resolved_ after reports from users on
    our issue tracker at https://bitbucket.org/pypy/pypy/issues or on IRC at
    #pypy.

* New features:

  * cffi was updated to version 1.3

  * The python stdlib was updated to 2.7.10 from 2.7.9

  * vmprof now supports multiple threads and OS X

  * The translation process builds cffi import libraries for some stdlib
    packages, which should prevent confusion when package.py is not used

  * better support for gdb debugging

  * freebsd should be able to translate PyPy "out of the box" with no patches

* Numpy:

  * Better support for record dtypes, including the ``align`` keyword

  * Implement casting and create output arrays accordingly (still missing some corner cases)

  * Support creation of unicode ndarrays

  * Better support ndarray.flags

  * Support ``axis`` argument in more functions

  * Refactor array indexing to support ellipses

  * Allow the docstrings of built-in numpy objects to be set at run-time

  * Support the ``buffered`` nditer creation keyword

* Performance improvements:

  * Delay recursive calls to make them non-recursive

  * Skip loop unrolling if it compiles too much code

  * Tweak the heapcache

  * Add a list strategy for lists that store both floats and 32-bit integers.
    The latter are encoded as nonstandard NaNs.  Benchmarks show that the speed
    of such lists is now very close to the speed of purely-int or purely-float
    lists. 

  * Simplify implementation of ffi.gc() to avoid most weakrefs

  * Massively improve the performance of map() with more than
    one sequence argument

.. _`vmprof`: https://vmprof.readthedocs.org
.. _resolved: https://doc.pypy.org/en/latest/whatsnew-2.6.1.html

Please try it out and let us know what you think. We welcome
success stories, `experiments`_,  or `benchmarks`_, we know you are using PyPy, please tell us about it!

Cheers

The PyPy Team

.. _`experiments`: https://morepypy.blogspot.com/2015/02/experiments-in-pyrlang-with-rpython.html
.. _`benchmarks`: https://mithrandi.net/blog/2015/03/axiom-benchmark-results-on-pypy-2-5-0
