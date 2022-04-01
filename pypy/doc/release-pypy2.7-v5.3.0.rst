============
PyPy2.7 v5.3
============

We have released PyPy2.7 v5.3, about six weeks after PyPy 5.1 and a week after
`PyPy3.3 v5.2 alpha 1`_, the first PyPy release targetting 3.3
compatibility. This new PyPy2.7 release includes further improvements for the
CAPI compatibility layer which we call cpyext. In addtion to complete support
for lxml, we now pass most (more than 90%) of the upstream numpy test suite,
and much of SciPy is supported as well.

We updated cffi_ to version 1.7 (small changes, documented here_).

.. _`PyPy3.3 v5.2 alpha 1`: https://morepypy.blogspot.com/2016/05/pypy33-v52-alpha-1-released.html
.. _cffi: https://cffi.readthedocs.org
.. _here: https://cffi.readthedocs.io/en/latest/whatsnew.html

You can download the PyPy2.7 v5.3 release here:

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
.. _`dynamic languages`: https://pypyjs.org

Other Highlights (since 5.1 released in April 2016)
=========================================================

* New features:

  * Merge a major expansion of the C-API support in cpyext, here are some of
    the highlights:

      - allow c-snippet tests to be run with -A so we can verify we are compatible
      - fix many edge cases exposed by fixing tests to run with -A
      - issequence() logic matches cpython
      - make PyStringObject and PyUnicodeObject field names compatible with cpython
      - add prelminary support for PyDateTime_*
      - support PyComplexObject, PyFloatObject, PyDict_Merge, PyDictProxy,
        PyMemoryView_*, _Py_HashDouble, PyFile_AsFile, PyFile_FromFile,
        PyAnySet_CheckExact, PyUnicode_Concat, PyDateTime_TZInfo
      - improve support for PyGILState_Ensure, PyGILState_Release, and thread
        primitives, also find a case where CPython will allow thread creation
        before PyEval_InitThreads is run, dissallow on PyPy 
      - create a PyObject-specific list strategy
      - rewrite slot assignment for typeobjects
      - improve tracking of PyObject to rpython object mapping
      - support tp_as_{number, sequence, mapping, buffer} slots
      - support ByteArrayObject via the new resizable_list_supporting_raw_ptr
      - implement PyList_SET_ITEM with CPython's behavior, instead of SetItem's
      - fix the signature of PyUFunc_FromFuncAndDataAndSignature
      - implement many PyWhatever_FOO() as a macro taking a `void *`

  * CPyExt tweak: instead of "GIL not held when a CPython C extension module
    calls PyXxx", we now silently acquire/release the GIL.  Helps with
    CPython C extension modules that call some PyXxx() functions without
    holding the GIL (arguably, they are theorically buggy).

  * Add rgc.FinalizerQueue, documented in pypy/doc/discussion/finalizer-order.rst.
    It is a more flexible way to make RPython finalizers. Use this mechanism to
    clean up handling of ``__del__`` methods, fixing issue #2287

  * Generalize cpyext old-style buffers to more than just str/buffer, add
    support for mmap

  * Support command line -v to trace import statements

  * Add rposix functions for PyPy3.3 support

  * Give super an __init__ and a simple __new__ for CPython compatibility

  * Revive traceviewer, a tool to use pygame to view traces

* Bug Fixes

  * Fix issue #2277: only special-case two exact lists in zip(), not list
    subclasses, because an overridden __iter__() should be called (probably)

  * Fix issue #2226: Another tweak in the incremental GC- this should ensure
    that progress in the major GC occurs quickly enough in all cases.

  * Clarify and refactor documentation on https://doc.pypy.org

  * Use "must be unicode, not %T" in unicodedata TypeErrors.

  * Manually reset sys.settrace() and sys.setprofile() when we're done running.
    This is not exactly what CPython does, but if we get an exception, unlike
    CPython, we call functions from the 'traceback' module, and these would
    call more the trace/profile function.  That's unexpected and can lead
    to more crashes at this point.

  * Use the appropriate tp_dealloc on a subclass of a builtin type, and call
    tp_new for a python-sublcass of a C-API type

  * Fix for issue #2285 - rare vmprof segfaults on OS/X

  * Fixed issue #2172 - where a test specified an invalid parameter to mmap on powerpc

  * Fix issue #2311 - grab the `__future__` flags imported in the main script, in
    `-c`, or in `PYTHON_STARTUP`, and expose them to the `-i` console

  * Issues reported with our previous release were resolved_ after reports from users on
    our issue tracker at https://bitbucket.org/pypy/pypy/issues or on IRC at
    #pypy

* Numpy_:

  * Implement ufunc.outer on numpypy

  * Move PyPy-specific numpy headers to a subdirectory (also changed `the repo`_
    accordingly)

* Performance improvements:

  * Use bitstrings to compress lists of descriptors that are attached to an
    EffectInfo

  * Remove most of the _ovf, _zer and _val operations from RPython.  Kills
    quite some code internally, and allows the JIT to do better
    optimizations: for example, app-level code like ``x / 2`` or ``x % 2``
    can now be turned into ``x >> 1`` or ``x & 1``, even if x is possibly
    negative.

  * Copy CPython's 'optimization': ignore __iter__ etc. for `f(**dict_subclass())`

  * Use the __builtin_add_overflow built-ins if they are available

  * Rework the way registers are moved/spilled in before_call()

* Internal refactorings:

  * Refactor code to better support Python3-compatible syntax

  * Document and refactor OperationError -> oefmt

  * Reduce the size of generated C sources during translation by 
    eliminating many many unused struct declarations (Issue #2281)

  * Remove a number of translation-time options that were not tested and
    never used. Also fix a performance bug in the method cache

  * Reduce the size of generated code by using the same function objects in
    all generated subclasses

  * Share cpyext Py* function wrappers according to the signature, shrinking the
    translated libpypy.so by about 10% (measured without the JIT)

  * Compile c snippets with -Werror, and fix warnings it exposed

.. _resolved: https://doc.pypy.org/en/latest/whatsnew-5.3.0.html
.. _Numpy: https://bitbucket.org/pypy/numpy
.. _`the repo`: https://bitbucket.org/pypy/numpy

Please update, and continue to help us make PyPy better.

Cheers

The PyPy Team

