=============================================
PyPy2.7 and PyPy3.5 v5.7 - two in one release
=============================================

The PyPy team is proud to release both PyPy2.7 v5.7 (an interpreter supporting
Python v2.7 syntax), and a beta-quality PyPy3.5 v5.7 (an interpreter for Python
v3.5 syntax). The two releases are both based on much the same codebase, thus
the dual release.  Note that PyPy3.5 supports Linux 64bit only for now. 

This new PyPy2.7 release includes the upstream stdlib version 2.7.13, and
PyPy3.5 (our first in the 3.5 series) includes the upstream stdlib version
3.5.3.

We continue to make incremental improvements to our C-API
compatibility layer (cpyext). PyPy2 can now import and run many C-extension
packages, among the most notable are Numpy, Cython, and Pandas. Performance may
be slower than CPython, especially for frequently-called short C functions.
Please let us know if your use case is slow, we have ideas how to make things
faster but need real-world examples (not micro-benchmarks) of problematic code.

Work proceeds at a good pace on the PyPy3.5
version due to a grant_ from the Mozilla Foundation, hence our first 3.5.3 beta
release. Thanks Mozilla !!! While we do not pass all tests yet, asyncio works and
as `these benchmarks show`_ it already gives a nice speed bump.
We also backported the ``f""`` formatting from 3.6 (as an exception; otherwise
"PyPy3.5" supports the Python 3.5 language).

CFFI_ has been updated to 1.10, improving an already great package for
interfacing with C.

We now use shadowstack as our default gcrootfinder_ even on Linux. The
alternative, asmgcc, will be deprecated at some future point. While about 3%
slower, shadowstack is much more easily maintained and debuggable. Also,
the performance of shadowstack has been improved in general: this should
close the speed gap between Linux and other platforms.

As always, this release fixed many issues and bugs raised by the
growing community of PyPy users. We strongly recommend updating.

You can download the v5.7 release here:

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
.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`modules`: project-ideas.html#make-more-python-modules-pypy-friendly
.. _`help`: project-ideas.html
.. _`these benchmarks show`: https://morepypy.blogspot.com/2017/03/async-http-benchmarks-on-pypy3.html
.. _gcrootfinder: config/translation.gcrootfinder.html

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

Highlights of the PyPy2.7, cpyext, and RPython changes (since 5.6 released Nov, 2016)
=====================================================================================

See also issues that were resolved_

* New features and cleanups

  * update the format of the PYPYLOG file and improvements to vmprof
  * emit more sysconfig values for downstream cextension packages including
    properly setting purelib and platlib to site-packages
  * add ``PyAnySet_Check``, ``PyModule_GetName``, ``PyWeakref_Check*``,
    ``_PyImport_{Acquire,Release}Lock``, ``PyGen_Check*``, ``PyOS_AfterFork``,
  * detect and raise on recreation of a PyPy object from a PyObject during
    tp_dealloc
  * refactor and clean up poor handling of unicode exposed in work on py3.5
  * builtin module cppyy_ supports C++ 11, 14, etc. via cling (reflex has been removed)
  * adapt ``weakref`` according to CPython issue 19542_, will be in CPython 2.7.14
  * support translations with cpyext and the Boehm GC (for special cases like
    RevDB_
  * implement ``StringBuffer.get_raw_address`` for the buffer protocol, it is
    now possible to obtain the address of any readonly object without pinning it
  * refactor the initialization code in translating cpyext
  * use a cffi-style C parser to create rffi objects in cpyext, now the
    translating Python must have either ``cffi`` or ``pycparser`` available
  * implement ``move_to_end(last=True/False)`` on RPython ordered dicts, make
    available as ``__pypy__.move_to_end`` and, on py3.5,
    ``OrderedDict.move_to_end()``
  * remove completely RPython ``space.wrap`` in a major cleanup, differentiate
    between ``space.newtext`` and ``space.newbytes`` on py3.5
  * any uncaught RPython exception in the interpreter is turned into a
    SystemError (rather than a segfault)
  * add translation time --disable_entrypoints option for embedding PyPy together
    with another RPython VM


* Bug Fixes

  * fix ``"".replace("", "x", num)`` to give the same result as CPython
  * create log files without the executable bit
  * disable ``clock_gettime()`` on OS/X, since we support 10.11 and it was only
    added in 10.12
  * support ``HAVE_FSTATVFS`` which was unintentionally always false
  * fix user-created C-API heaptype, issue 2434_
  * fix ``PyDict_Update`` is not actually the same as ``dict.update``
  * assign ``tp_doc`` on ``PyTypeObject`` and tie it to the app-level ``__doc__`` attribute
    issue 2446_
  * clean up memory leaks around ``PyObject_GetBuffer``, ``PyMemoryView_GET_BUFFER``,
    ``PyMemoryView_FromBuffer``, and ``PyBuffer_Release``
  * improve support for creating C-extension objects from app-level classes,
    filling more slots, especially ``tp_new`` and ``tp_dealloc``
  * fix for ``ctypes.c_bool`` returning ``bool`` restype, issue 2475_
  * fix in corner cases with the GIL and C-API functions
  * allow overriding thread.local.__init__ in a subclass, issue 2501_
  * allow ``PyClass_New`` to be called with NULL as the first arguemnt, issue 2504_


* Performance improvements:

  * clean-ups in the jit optimizeopt
  * optimize ``if x is not None: return x`` or ``if x != 0: return x``
  * add ``jit.conditional_call_elidable()``, a way to tell the JIT 
    "conditonally call this function" returning a result
  * try harder to propagate ``can_be_None=False`` information
  * add ``rarithmetic.ovfcheck_int32_add/sub/mul``
  * add and use ``rgc.may_ignore_finalizer()``: an optimization hint that makes
    the GC stop tracking the object
  * replace malloc+memset with a single calloc, useful for large allocations?
  * linux: try to implement os.urandom() as the syscall getrandom() if available
  * propagate ``debug.ll_assert_not_none()`` through the JIT to reduce number of
    guards
  * improve the performance of ``PyDict_Next``
  * improve ``dict.pop()``
  * improve the optimization of branchy Python code by retaining more
    information across failing guards
  * add optimized "zero-copy" path for ``io.FileIO.readinto``

* RPython improvements

  * improve the consistency of RPython annotation unions
  * add translation option --keepgoing to continue after the first AnnotationError
  * improve shadowstack to where it is now the default in place of asmgcc
  * add a rpython implementation of siphash24, allow choosing hash algorithm
    randomizing the seed
  * add rstack.stack_almost_full() and use it to avoid stack overflow due to
    the JIT where possible

Highlights of the PyPy3.5 release (since 5.5 alpha released Oct, 2016)
==========================================================================

Development moved from the py3k branch to the py3.5 branch in the PyPy bitbucket repo.

* New features

  * this first PyPy3.5 release implements most of Python 3.5.3, exceptions are listed below
  * PEP 456 allowing secure and interchangable hash algorithms
  * use cryptography_'s cffi backend for SSL


* Bug Fixes

  * implement fixes for some CPython issues that arose since the last release 
  * solve deadlocks in thread locking mechanism

* Performance improvements:

  * do not create a list whenever ``descr_new`` of a ``bytesobject`` is called

* The following features of Python 3.5 are not implemented yet in PyPy:

  * PEP 442: Safe object finalization
  * PEP 489: Multi-phase extension module initialization

.. _resolved: whatsnew-pypy2-5.7.0.html
.. _19542: https://bugs.python.org/issue19542
.. _2434: https://bitbucket.org/pypy/pypy/issues/2434/support-pybind11-in-conjunction-with-pypys
.. _2446: https://bitbucket.org/pypy/pypy/issues/2446/cpyext-tp_doc-field-not-reflected-on
.. _2475: https://bitbucket.org/pypy/pypy/issues/2475
.. _2501: https://bitbucket.org/pypy/pypy/issues/2501
.. _2504: https://bitbucket.org/pypy/pypy/issues/2504
.. _RevDB: https://bitbucket.org/pypy/revdb
.. _cryptography: https://cryptography.io
.. _cppyy: cppyy.html

Please update, and continue to help us make PyPy better.

Cheers
