============
PyPy2.7 v5.4
============

We have released PyPy2.7 v5.4, a little under two months after PyPy2.7 v5.3.
This new PyPy2.7 release includes incremental improvements to our C-API
compatability layer (cpyext), enabling us to pass over 99% of the upstream
numpy test suite. We updated built-in cffi_ support to version 1.8,
which now supports the "limited API" mode for c-extensions on 
CPython >=3.2.

We improved tooling for the PyPy JIT_, and expanded VMProf
support to OpenBSD and Dragon Fly BSD

As always, this release fixed many issues and bugs raised by the
growing community of PyPy users. We strongly recommend updating.

You can download the PyPy2.7 v5.4 release here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project.

We would also like to thank our contributors and
encourage new people to join the project. PyPy has many
layers and we need help with all of them: `PyPy`_ and `RPython`_ documentation
improvements, tweaking popular `modules`_ to run on pypy, or general `help`_
with making RPython's JIT even better.

.. _cffi: https://cffi.readthedocs.org
.. _JIT: https://morepypy.blogspot.com.au/2016/08/pypy-tooling-upgrade-jitviewer-and.html
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

Other Highlights (since 5.3 released in June 2016)
=========================================================

* New features:

  * Add `sys.{get,set}dlopenflags`

  * Improve CPython compatibility of 'is' for small and empty strings

  * Support for rgc.FinalizerQueue in the Boehm garbage collector

  * (RPython) support spawnv() if it is called in C `_spawnv` on windows

  * Fill in more slots when creating a PyTypeObject from a W_TypeObject,
    like `__hex__`, `__sub__`, `__pow__`

  * Copy CPython's logic more closely for `isinstance()` and
    `issubclass()` as well as `type.__instancecheck__()` and
    `type.__subclasscheck__()`

  * Expose the name of CDLL objects

  * Rewrite the win32 dependencies of `subprocess` to use cffi
    instead of ctypes

  * Improve the `JIT logging`_ facitilities

  * (RPython) make int * string work

  * Allocate all RPython strings with one extra byte, normally
    unused. This now allows `ffi.from_buffer(string)` in CFFI with
    no copy

  * Adds a new commandline option `-X track-resources` that will
    produce a `ResourceWarning` when the GC closes a file or socket.
    The traceback for the place where the file or socket was allocated
    is given as well, which aids finding places where `close()` is
    missing

  * Add missing `PyObject_Realloc`, `PySequence_GetSlice`

  * `type.__dict__` now returns a `dict_proxy` object, like on CPython.
    Previously it returned what looked like a regular dict object (but
    it was already read-only)

  * (RPython) add `rposix.{get,set}_inheritable()`, needed by Python 3.5

  * (RPython) add `rposix_scandir` portably, needed for Python 3.5

  * Increased but incomplete support for memoryview attributes (format, 
    itemsize, ...) which also adds support for `PyMemoryView_FromObject`

* Bug Fixes

  * Reject `mkdir()` in read-only sandbox filesystems

  * Add include guards to pymem.h to enable c++ compilation

  * Fix build breakage on OpenBSD and FreeBSD

  * Support OpenBSD, Dragon Fly BSD in VMProf

  * Fix for `bytearray('').replace('a', 'ab')` for empty strings

  * Sync internal state before calling `PyFile_AsFile()`

  * Allow writing to a char* from `PyString_AsString()` until it is
    forced, also refactor `PyStringObject` to look like CPython's
    and allow subclassing `PyString_Type` and `PyUnicode_Type`

  * Rpython rffi's socket(2) wrapper did not preserve errno

  * Refactor `PyTupleObject` to look like CPython's and allow
    subclassing `PyTuple_Type`

  * Allow c-level assignment to a function pointer in a C-API
    user-defined type after calling PyTypeReady by retrieving
    a pointer to the function via offsets
    rather than storing the function pointer itself

  * Use `madvise(MADV_FREE)`, or if that doesn't exist
    `MADV_DONTNEED` on freed arenas to release memory back to the
    OS for resource monitoring

  * Fix overflow detection in conversion of float to 64-bit integer
    in timeout argument to various thread/threading primitives

  * Fix win32 outputting `\r\r\n` in some cases

  * Make `hash(-1)` return -2, as CPython does, and fix all the
    ancilary places this matters

  * Fix `PyNumber_Check()` to behave more like CPython

  * (VMProf) Try hard to not miss any Python-level frame in the
    captured stacks, even if there is metainterp or blackhole interp
    involved.  Also fix the stacklet (greenlet) support

  * Fix a critical JIT bug where `raw_malloc` -equivalent functions
    lost the additional flags

  * Fix the mapdict cache for subclasses of builtin types that
    provide a dict

  * Issues reported with our previous release were resolved_ after
    reports from users on our issue tracker at
    https://bitbucket.org/pypy/pypy/issues or on IRC at #pypy

* Performance improvements:

  * Add a before_call()-like equivalent before a few operations like
    `malloc_nursery`, to move values from registers into other registers
    instead of to the stack.

  * More tightly pack the stack when calling with `release gil`

  * Support `int_floordiv()`, `int_mod()` in the JIT more efficiently
    and add `rarithmetic.int_c_div()`, `rarithmetic.int_c_mod()` as
    explicit interfaces. Clarify that `int_floordiv()` does python-style
    rounding, unlike `llop.int_floordiv()`.

  * Use `ll_assert` (more often) in incminimark

  * (Testing) Simplify handling of interp-level tests and make it
    more forward-compatible. Don't use interp-level RPython
    machinery to test building app-level extensions in cpyext

  * Constant-fold `ffi.offsetof("structname", "fieldname")` in cffi
    backend

  * Avoid a case in the JIT, where successive guard failures in
    the same Python function end up as successive levels of
    RPython functions, eventually exhausting the stack, while at
    app-level the traceback is very short

  * Check for NULL returns from calls to the raw-malloc and raise,
    rather than a guard

  * Improve `socket.recvfrom()` so that it copies less if possible

  * When generating C code, inline `goto` to blocks with only one
    predecessor, generating less lines of code

  * When running the final backend-optimization phase before emitting
    C code, constant-fold calls to we_are_jitted to return False. This
    makes the generated C code a few percent smaller

  * Refactor the `uid_t/gid_t` handling in `rlib.rposix` and in
    `interp_posix.py`, based on the clean-up of CPython 2.7.x 

.. _`JIT logging`: https://morepypy.blogspot.com/2016/08/pypy-tooling-upgrade-jitviewer-and.html
.. _resolved: https://doc.pypy.org/en/latest/whatsnew-5.4.0.html

Please update, and continue to help us make PyPy better.

Cheers
