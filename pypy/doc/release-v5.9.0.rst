=====================================
PyPy2.7 and PyPy3.5 v5.9 dual release
=====================================

The PyPy team is proud to release both PyPy2.7 v5.9 (an interpreter supporting
Python 2.7 syntax), and a beta-quality PyPy3.5 v5.9 (an interpreter for Python
3.5 syntax). The two releases are both based on much the same codebase, thus
the dual release.  Note that PyPy3.5 supports Linux 64bit only for now. 

This new PyPy2.7 release includes the upstream stdlib version 2.7.13, and
PyPy3.5 includes the upstream stdlib version 3.5.3.

NumPy and Pandas now work on PyPy2.7 (together with Cython 0.27.1). Issues
that appeared as excessive memory
use were cleared up and other incompatibilities were resolved. The C-API
compatibility layer does slow down code which crosses the python-c interface
often, we have ideas on how it could be improved, and still recommend
using pure python on PyPy or interfacing via CFFI_. Many other modules
based on C-API exentions now work on PyPy as well.

Cython 0.27.1 (released very recently) supports more projects with PyPy, both
on PyPy2.7 and PyPy3.5 beta. Note version **0.27.1** is now the minimum
version that supports this version of PyPy, due to some interactions with
updated C-API interface code.

We optimized the JSON parser for recurring string keys, which should decrease
memory use to 50% and increase parsing speed by up to 15% for large JSON files
with many repeating dictionary keys (which is quite common).

CFFI_, which is part of the PyPy release, has been updated to 1.11.1,
improving an already great package for interfacing with C. CFFI now supports
complex arguments in API mode, as well as ``char16_t`` and ``char32_t`` and has
improved support for callbacks.

Please let us know if your use case is slow, we have ideas how to make things
faster but need real-world examples (not micro-benchmarks) of problematic code.

Work sponsored by a Mozilla grant_ continues on PyPy3.5; numerous fixes from
CPython were ported to PyPy. Of course the bug fixes and performance enhancements
mentioned above are part of both PyPy2.7 and PyPy3.5 beta.

As always, this release fixed many other issues and bugs raised by the
growing community of PyPy users. We strongly recommend updating.

You can download the v5.9 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project.

We would also like to thank our contributors and
encourage new people to join the project. PyPy has many
layers and we need help with all of them: `PyPy`_ and `RPython`_ documentation
improvements, tweaking popular `modules`_ to run on pypy, or general `help`_
with making RPython's JIT even better.

.. _vmprof: https://vmprof.readthedocs.io
.. _CFFI: https://cffi.readthedocs.io/en/latest/whatsnew.html
.. _grant: https://morepypy.blogspot.com/2016/08/pypy-gets-funding-from-mozilla-for.html
.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`modules`: project-ideas.html#make-more-python-modules-pypy-friendly
.. _`help`: project-ideas.html

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

Highlights of the PyPy2.7, cpyext, and RPython changes (since 5.8 released June, 2017)
======================================================================================

See also issues that were resolved_

Note that these are also merged into PyPy 3.5

* New features and cleanups

  * Add support for ``PyFrozenSet_New``, ``PyObject_HashNotImplemented``,
    ``PyObject_Print(NULL, ...)``, ``PyObject_RichCompareBool(a, a, ...)``,
    ``PyType_IS_GC`` (does nothing), ``PyUnicode_FromFormat``
  * ctypes ``char_p`` and ``unichar_p`` indexing now CPython compatible
  * ``gcdump`` now reports largest object
  * More complete support in the ``_curses`` CFFI module
  * Add cPickle.Unpickler.find_global (issue 1853_)
  * Fix ``PyErr_Fetch`` + ``PyErr_NormalizeException`` with no exception set
  * Simplify ``gc.get_referrers()`` to return the opposite of ``gc.get_referents()``
  * Update RevDB to version pypy2.7-v5.6.2
  * Previously, ``instance.method`` would return always the same bound method
    object, when gotten from the same instance (as far as ``is`` and ``id()``
    can tell).  CPython doesn't do that.  Now PyPy, like CPython, returns a 
    different bound method object every time.  For ``type.method``, PyPy2 still
    returns always the same *unbound* method object; CPython does it for built-in
    types but not for user-defined types
  * Link to disable PaX protection for the JIT when needed
  * Update build instructions and an rarely used Makefile
  * Recreate support for using leakfinder in cpyext tests which had suffered
    bit-rot, disable due to many false positives
  * Add more functionality to ``sysconfig``
  * Added ``_swappedbytes_`` support for ``ctypes.Structure``
  * Better support the ``inspect`` module on ``frames``

* Bug Fixes 

  * Fix issue 2592_ - cpyext ``PyListObject.pop``, ``pop_end`` must return a value
  * Implement ``PyListOjbect.getstorage_copy``
  * Fix for ``reversed(dictproxy)`` issue 2601_
  * Fix for duplicate names in ctypes' ``_fields__``, issue 2621_
  * Update built-in ``pyexpat`` module on win32 to use UTF-8 version not UTF-16
  * ``gc.get_objects`` now handles objects with finalizers more consistently
  * Fixed memory leak in ``SSLContext.getpeercert`` returning validated
    certificates and ``SSLContext.get_ca_certs(binary_mode=True)``
    (_get_crl_dp) `CPython issue 29738`_

* Performance improvements:

  * Improve performance of ``bytearray.extend`` by rewriting portions in app-level
  * Optimize list accesses with constant indexes better by retaining more
    information about them
  * Add a jit driver for ``array.count`` and ``array.index``
  * Improve information retained in a bridge wrt ``array``
  * Move some dummy CAPI functions and ``Py*_Check`` functions from RPython into
    pure C macros
  * In the fast ``zip(intlist1, intlist2)`` implementation, don't wrap and unwrap
    all the ints
  * Cache string keys that occur in JSON dicts, as they are likely to repeat

* RPython improvements

  * Do not preallocate a RPython list if we only know an upper bound on its size
  * Issue 2590_: fix the bounds in the GC when allocating a lot of objects with finalizers
  * Replace magical NOT RPYTHON comment with a decorator
  * Implement ``socket.sendmsg()``/``.recvmsg()`` for py3.5
  * Add ``memory_pressure`` for ``_SSLSocket`` objects

* Degredations

  * Disable vmprof on win32, due to upstream changes that break the internal ``_vmprof`` module

.. _here: cpython_differences.html
.. _1853: https://bitbucket.org/pypy/pypy/issues/1853
.. _2592: https://bitbucket.org/pypy/pypy/issues/2592
.. _2590: https://bitbucket.org/pypy/pypy/issues/2590
.. _2621: https://bitbucket.org/pypy/pypy/issues/2621

Highlights of the PyPy3.5 release (since 5.8 beta released June 2017)
======================================================================

* New features

  * Add support for ``_PyNamespace_New``, ``PyMemoryView_FromMemory``, 
    ``Py_EnterRecursiveCall`` raising RecursionError, ``PyObject_LengthHint``,
    ``PyUnicode_FromKindAndData``, ``PyDict_SetDefault``, ``PyGenObject``,
    ``PyGenObject``, ``PyUnicode_Substring``, ``PyLong_FromUnicodeObject``
  * Implement ``PyType_FromSpec`` (PEP 384) and fix issues with PEP 489 support
  * Support the new version of ``os.stat()`` on win32
  * Use ``stat3()`` on Posix
  * Accept buffer objects as filenames, except for `oslistdir``
  * Make slices of array ``memoryview`` s usable as writable buffers if contiguous
  * Better handling of ``'%s'`` formatting for byte strings which might be utf-8 encoded
  * Update the macros ``Py_DECREF`` and similar to use the CPython 3.5 version
  * Ensure that ``mappingproxy`` is recognised as a mapping, not a sequence
  * Enable PGO for CLang
  * Rework ``cppyy`` packaging and rename the backend to ``_cppyy``
  * Support for libressl 2.5.4
  * Mirror CPython ``classmethod __reduce__`` which fixes pickling test
  * Use utf-8 for ``readline`` history file
  * Allow assigning ``'__class__'`` between ``ModuleType`` and its subclasses
  * Add async slot functions in cpyext

* Bug Fixes

  * Try to make ``openssl`` CFFI bindings more general and future-proof
  * Better support ``importlib`` by only listing built-in modules in ``sys.builtin``
  * Add ``memory_pressure`` to large CFFI allocations in ``_lzma``, issue 2579_
  * Fix for ``reversed(mapping object)`` issue 2601_
  * Fixing regression with non-started generator receiving non-``None``, should
    always raise ``TypeError``
  * ``itertools.islice``: use same logic as CPython, fixes 2643_

* Performance improvements:

  * 

* The following features of Python 3.5 are not implemented yet in PyPy:

  * PEP 442: Safe object finalization

.. _resolved: whatsnew-pypy2-5.9.0.html
.. _2579: https://bitbucket.org/pypy/pypy/issues/2579
.. _2601: https://bitbucket.org/pypy/pypy/issues/2601
.. _2643: https://bitbucket.org/pypy/pypy/issues/2643
.. _CPython issue 29738: https://bugs.python.org/issue29738

Please update, and continue to help us make PyPy better.

Cheers
