==============================
PyPy 2.5.0 - Pincushion Protea
==============================

We're pleased to announce PyPy 2.5, which contains significant performance
enhancements and bug fixes.

You can download the PyPy 2.5.0 release here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project, and for those who donate to our three sub-projects, as well as our
volunteers and contributors (10 new commiters joined PyPy since the last
release).
We've shown quite a bit of progress, but we're slowly running out of funds.
Please consider donating more, or even better convince your employer to donate,
so we can finish those projects! The three sub-projects are:

* `Py3k`_ (supporting Python 3.x): We have released a Python 3.2.5 compatible version
   we call PyPy3 2.4.0, and are working toward a Python 3.3 compatible version

* `STM`_ (software transactional memory): We have released a first working version,
  and continue to try out new promising paths of achieving a fast multithreaded Python

* `NumPy`_ which requires installation of our fork of upstream numpy,
  available `on bitbucket`_

.. _`Py3k`: https://pypy.org/py3donate.html
.. _`STM`: https://pypy.org/tmdonate2.html
.. _`NumPy`: https://pypy.org/numpydonate.html
.. _`on bitbucket`: https://www.bitbucket.org/pypy/numpy

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy and cpython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports **x86** machines on most common operating systems
(Linux 32/64, Mac OS X 64, Windows, and OpenBSD),
as well as newer **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux.

While we support 32 bit python on Windows, work on the native Windows 64
bit python is still stalling, we would welcome a volunteer
to `handle that`_.

.. _`pypy and cpython 2.7.x`: https://speed.pypy.org
.. _`handle that`: https://doc.pypy.org/en/latest/windows.html#what-is-missing-for-a-full-64-bit-translation

Highlights
==========

* The past months have seen pypy mature and grow, as rpython becomes the goto
  solution for writing fast dynamic language interpreters. Our separation of
  rpython and the python interpreter PyPy is now much clearer in the
  `PyPy documentation`_  and we now have seperate `RPython documentation`_.

* We have improved warmup time as well as jitted code performance: more than 10%
  compared to pypy-2.4.0, due to internal cleanup and gc nursery improvements.
  We no longer zero-out memory allocated in the gc nursery by default, work that
  was started during a GSoC.

* Passing objects between C and PyPy has been improved. We are now able to pass
  raw pointers to C (without copying) using **pinning**. This improves I/O;
  benchmarks that use networking intensively improved by about 50%. File()
  operations still need some refactoring but are already showing a 20%
  improvement on our benchmarks. Let us know if you see similar improvements.

* Our integrated numpy support gained much of the GenericUfunc api in order to
  support the lapack/blas linalg module of numpy. This dovetails with work in the
  pypy/numpy repository to support linalg both through the (slower) cpyext capi
  interface and also via (the faster) pure python cffi interface, using an
  extended frompyfunc() api. We will soon post a seperate blog post specifically
  about linalg and PyPy.

* Dictionaries are now ordered by default, see the `blog post`_

* Our nightly translations use --shared by default, including on OS/X and linux

* We now more carefully handle errno (and GetLastError, WSAGetLastError) tying
  the handlers as close as possible to the external function call, in non-jitted
  as well as jitted code.

* Issues reported with our previous release were resolved_ after reports from users on
  our issue tracker at https://bitbucket.org/pypy/pypy/issues or on IRC at
  #pypy.

.. _`PyPy documentation`: https://doc.pypy.org
.. _`RPython documentation`: https://rpython.readthedocs.org
.. _`blog post`: https://morepypy.blogspot.com/2015/01/faster-more-memory-efficient-and-more.html
.. _resolved: https://doc.pypy.org/en/latest/whatsnew-2.5.0.html

We have further improvements on the way: rpython file handling,
finishing numpy linalg compatibility, numpy object dtypes, a better profiler,
as well as support for Python stdlib 2.7.9.

Please try it out and let us know what you think. We especially welcome
success stories, we know you are using PyPy, please tell us about it!

Cheers

The PyPy Team
