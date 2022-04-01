==========================================================
PyPy v7.3.8: release of python 2.7, 3.7, 3.8, and 3.9-beta
==========================================================

The PyPy team is proud to release version 7.3.8 of PyPy. It has been only a few
months since our last release, but we have some nice speedups and bugfixes we
wish to share. The release includes four different interpreters:

  - PyPy2.7, which is an interpreter supporting the syntax and the features of
    Python 2.7 including the stdlib for CPython 2.7.18+ (the ``+`` is for
    backported security updates)

  - PyPy3.7,  which is an interpreter supporting the syntax and the features of
    Python 3.7, including the stdlib for CPython 3.7.12. This will be the last
    release of PyPy3.7.

  - PyPy3.8, which is an interpreter supporting the syntax and the features of
    Python 3.8, including the stdlib for CPython 3.8.12. This is our third
    release of this interpreter, and we are removing the "beta" tag.

  - PyPy3.9, which is an interpreter supporting the syntax and the features of
    Python 3.9, including the stdlib for CPython 3.9.10. As this is our first
    release of this interpreter, we relate to this as "beta" quality. We
    welcome testing of this version, if you discover incompatibilities, please
    report them so we can gain confidence in the version. 

The interpreters are based on much the same codebase, thus the multiple
release. This is a micro release, all APIs are compatible with the other 7.3
releases. Highlights of the release, since the release of 7.3.7 in late October 2021,
include:

  - PyPy3.9 uses an RPython version of the PEG parser which brought with it a
    cleanup of the lexer and parser in general
  - Fixed a regression in PyPy3.8 when JITting empty list comprehensions
  - Tweaked some issues around changing the file layout after packaging to make
    the on-disk layout of PyPy3.8 more compatible with CPython. This requires
    ``setuptools>=58.1.0``
  - RPython now allows the target executable to have a ``.`` in its name, so
    PyPy3.9 will produce a ``pypy3.9-c`` and ``libpypy3.9-c.so``. Changing the
    name of the shared object to be version-specific (it used to be
    ``libpypy3-c.so``) will allow it to live alongside other versions.
  - Building PyPy3.9+ accepts a ``--platlibdir`` argument like CPython.
  - Improvement in ssl's use of CFFI buffers to speed up ``recv`` and ``recvinto``
  - Update the packaged OpenSSL to 1.1.1m

We recommend updating. You can find links to download the v7.3.8 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work. If PyPy is helping you out, we would love to hear about
it and encourage submissions to our blog_ via a pull request
to https://github.com/pypy/pypy.org

We would also like to thank our contributors and encourage new people to join
the project. PyPy has many layers and we need help with all of them: `PyPy`_
and `RPython`_ documentation improvements, tweaking popular modules to run
on PyPy, or general `help`_ with making RPython's JIT even better. Since the
previous release, we have accepted contributions from 6 new contributors,
thanks for pitching in, and welcome to the project!

If you are a python library maintainer and use C-extensions, please consider
making a HPy_ / CFFI_ / cppyy_ version of your library that would be performant
on PyPy.
In any case both `cibuildwheel`_ and the `multibuild system`_ support
building wheels for PyPy.

.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`help`: project-ideas.html
.. _CFFI: https://cffi.readthedocs.io
.. _cppyy: https://cppyy.readthedocs.io
.. _`multibuild system`: https://github.com/matthew-brett/multibuild
.. _`cibuildwheel`: https://github.com/joerick/cibuildwheel
.. _blog: https://pypy.org/blog
.. _HPy: https://hpyproject.org/

What is PyPy?
=============

PyPy is a Python interpreter, a drop-in replacement for CPython 2.7, 3.7, 3.8 and
3.9. It's fast (`PyPy and CPython 3.7.4`_ performance
comparison) due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

This PyPy release supports:

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 64 bits, OpenBSD, FreeBSD)

  * 64-bit **ARM** machines running Linux. A shoutout to Huawei for sponsoring
    the VM running the tests.

  * **s390x** running Linux

  * big- and little-endian variants of **PPC64** running Linux,

PyPy support Windows 32-bit, PPC64 big- and little-endian, and ARM 32 bit, but
does not release binaries. Please reach out to us if you wish to sponsor
releases for those platforms.

.. _`PyPy and CPython 3.7.4`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

Known Issues with PyPy3.9
=========================

- There is still a known `speed regression`_ around ``**kwargs`` handling
- We slightly modified the concurrent future's ``ProcessExcecutorPool`` to
  start all the worker processes when the first task is received (like on
  Python3.8) to avoid an apparent race condition when using ``fork`` and
  threads (issue 3650_).

Changelog
=========

Bugfixes shared across versions
-------------------------------
- Fix error formatting of in-place TypeErrors (``a += 'aa'`` )
- Fix corner case in ``float.fromhex`` (bpo44954_)
- Copy ``dtoa`` changes from CPython (bpo40780_)
- Use ``symtable`` to improve the position of "duplicate argument" errors
- Add ``__builtins__`` to globals ``dict`` when calling ``eval`` (issue 3584_)
- Update embedded OpenSSL to 1.1.1m (bpo43522_)
- Avoid using ``epoll_event`` directly from RPython since it is a ``packed struct``
- Clean up some compilation warnings around `const char *`` conversions to
  ``char *``
- Make sure that frozensets cannot be mutated by using methods from set (issue
  3676_)

Speedups and enhancements shared across versions
------------------------------------------------
- Add unicodedata version 13, make 3.2 the basis of unicodedata compression
- Use 10.9 as a minimum ``MACOSX_DEPLOYMENT_TARGET`` to match CPython
- Only compute the ``Some*`` annotation types once, not every time we call a
  type checked function
- Update version of pycparser to 2.21
- Update vendored vmprof to support ppc64
- Update CFFI to 1.15.0, no real changes
- Stop doing guard strengthening with guards that come from inlining the short
  preamble. Doing that can lead to endless bridges (issue 3598_)
- Split `__pypy__.do_what_I_mean()`` into the original plus ``__pypy__._internal_crash``
  to make the meaning more clear. These are functions only useful for internal
  testing (issue 3617_).
- Prepare ``_ssl`` for OpenSSL3
- Improve ``x << y`` where ``x`` and ``y`` are ``ints`` but the results doesn't fit
  into a machine word: don't convert ``y`` to ``rbigint`` and back to int
- Avoid updating counter when using `--jit off`.
- Speed up ``str`` -> ``float`` conversion for the fast path (ascii, no ``'_'``, no
  ``INF``, no leading or trailing whitespace). PyPy with `--jit off`` is now
  faster than CPython for this fastpath (issue 3682_).

C-API (cpyext) and C-extensions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
We are no longer backporting changes to the ``cpyext`` compatibility layer to
PyPy2.7.


Python 3.7+ bugfixes
--------------------

- Fix various problems with the Windows ``_overlapped`` module (issue 3589_, )
- Fix error generation on ``_ssl`` in Windows
- Properly handle ``_PYTHON_SYSCONFIGDATA_NAME`` when importing ``_sysconfigdata``
- Restore broken revdb GC support
- Fix ``sys.path[0]`` to be ``''`` (not the actual full path) when run interactively
- Add ``_socket.socket.timeout`` getter
- Fix overflow detection on ``array.array`` on windows (issue 3604_)
- Add a typedef for ``AsyncGenValueWrapper`` since you can reach it with a
  trace hook, leading to a segfault
- Add an ``index`` value to ``iter(range()).__reduce__`` for compatibility
- Fix position of syntax errors raised while parsing f-string subexpressions
- Fix stack effect of ``EXTENDED_ARG``
- Fix incrementality in the unicode escape handler
- Like CPython, limit ``pwd.getpwnam`` to ``str`` (issue 3624_)
- Only use ``run_fork_hooks`` in ``_posixprocess.fork_exec`` if ``preexec_fn``
  is used (issue 3630_)
- Remove redundant call to ``threading._after_fork`` (issue 3623_)
- Fix filename in exception raised sometimes when running code with ``-c``
- Fixes for the ``signal`` module on windows so that ``raise_signal`` will not
  segfault
- Detail about ``PYTHONIOENCODING``: if the encoding or the error is omitted,
  always use ``utf-8/strict`` (instead of asking the locale)
- Disallow overriding the ``__context__`` descriptor from ``BaseException``
  when chaining exceptions (issue 3644_)
- Replace ``raise ImportError`` with ``raise ModuleNotFoundError`` where
  appropriate in pure-python equivalents of CPython builtin modules
- Add missing ``rewinddir()`` at the end of ``os.scandir``
- ``os.dup2`` now returns ``fd2``
- Make ``__fspath__`` errors compatible with CPython
- Fix handling of backslash in raw unicode escape decoders that don't
  start valid escape sequences (issue 3652_)
- Add missing equivalent of ``_Py_RestoreSignals()`` call in ``fork_exec``
- Catch exceptions in ``atexit`` functions to avoid crashing the interpreter at
  shutdown
- Update ``fast2locals`` to deal with the fact that it's now possible to
  delete cell vars (was forbidden in Python2) (issue 3656_)
- Allow hashing memoryviews (issue 2756_)

Python 3.7+ speedups and enhancements
-------------------------------------

- Use buffer pinning to improve CFFI-based ``_ssl`` performance
- Add a fast path in the parser for unicode literals with no ``\\`` escapes
- In glibc ``mbstowcs()`` can return values above 0x10ffff (bpo35883_)
- Speed up ``new_interned_str`` by using better caching detection
- When building a class, make sure to use a specialized ``moduledict``, not a
  regular empty dict
- Implement ``_opcode.stack_effect``
- Share more ``W_UnicodeObject`` prebuilt instances, shrink the binary by over 1MB
- Fix the ctypes errcheck_ protocol
- Various fixes in the windows-only ``_overlapped`` module (issue 3625_)
- Implement ``-X utf8``
- Add ``WITH_DYLD`` to ``sysconfig`` for darwin

Python 3.7 C-API
~~~~~~~~~~~~~~~~

- Added ``PyDescr_NewGetSet``, ``PyModule_NewObject``, ``PyModule_ExecDef``,
  ``PyCodec_Decode``, ``PyCodec_Encode``, ``PyErr_WarnExplicit``,
  ``PyDateTime_TimeZone_UTC``, ``PyUnicode_DecodeLocaleAndSize``
- Fix segfault when using format strings in ``PyUnicode_FromFormat`` and
  ``PyErr_Format`` (issue 3593_)
- ``_PyObject_LookupAttrId`` does not raise ``AttributeError``
- Fix cpyext implementation of ``contextvars.get``
- Deprecate ``PyPy.h``, mention the contents in the embedding docs (issue 3608_)
- Remove duplicate definition of ``Py_hash_t``, document diff to CPython (issue 3612_)
- Fix overflow error message when converting Python ``int`` to C ``int``
- Alias ``PyDateTime_DATE_GET_FOLD``, which CPython uses instead of the
  documented ``PyDateTime_GET_FOLD`` (issue 3627_)
- Add some ``_PyHASH*`` macros (issue 3590_)
- Fix signature of ``PyUnicode_DecodeLocale`` (issue 3661_)

Python 3.8+ bugfixes
--------------------
- Unwrapping an unsigned short raises ``ValueError`` on negative numbers
- Make properties unpicklable
- When packaging, fix finding dependencies of shared objects for portable
  builds and fix location of tcl/tk runtimes (issue 3616_). Also ignore
  ``__pycache__`` directories.
- Match CPython errors in ``_io.open`` and ``socket.socket(fileno=fileno)``
- Add ``LDFLAGS`` to ``sysconfig`` values
- PyPy reports the IPv6 scope ID in ``getaddrinfo`` where CPython does not. Fix
  stdlib tests to allow PyPy's ``__repr__``. bpo35545_ touches on this. (issue
  3628_)
- Fix small bugs when raising errors in various stdlib modules that caused
  stdlib test failures
- Update bundled ``setuptools`` to ``58.1.0`` to get the fix for the new PyPy
  layout
- Fix ``multiprocessing.sharedmemory`` on windows (issue 3678_).

Python 3.8+ speedups and enhancements
-------------------------------------
- Implement reversed items and values iterator pickling, fix reversed keys
  iterator pickling
- Add more auditing events, while skipping CPython-specific tracing and
  attribute-modification tracing
- Fixed a speed regression when JITting empty list comprehensions (issue
  3598_)
- Make sure that all bytecodes that can close a loop go via ``jump_absolute``,
  so the JIT can trace them

Python 3.8 C-API
~~~~~~~~~~~~~~~~
- Add ``exports.h`` and refactor headers to more closely follow CPython
- ``PyLong_AsLong`` tries ``__index__`` first (issue 3585_)
- Redo ``PyTypeObject`` to be able to use the ``tp_vectorcall`` slot without
  changing ABI compatibility (issue 3618_) by appropriating the PyPy-only
  ``tp_pypy_flags`` slot. Users should upgrade Cython to 0.2.26 to avoid a
  compiler warning.
- Add ``PyCompilerFlags.cf_feature_version`` (bpo35766_)
- Distinguish between a C-API ``CMethod`` and an app-level ``Method``, which
  is important for obscure reasons

.. _2756: https://foss.heptapod.net/pypy/pypy/-/issues/2756
.. _3589: https://foss.heptapod.net/pypy/pypy/-/issues/3589
.. _3584: https://foss.heptapod.net/pypy/pypy/-/issues/3584
.. _3598: https://foss.heptapod.net/pypy/pypy/-/issues/3598
.. _3585: https://foss.heptapod.net/pypy/pypy/-/issues/3585
.. _3590: https://foss.heptapod.net/pypy/pypy/-/issues/3590
.. _3593: https://foss.heptapod.net/pypy/pypy/-/issues/3593
.. _3604: https://foss.heptapod.net/pypy/pypy/-/issues/3604
.. _3608: https://foss.heptapod.net/pypy/pypy/-/issues/3608
.. _3612: https://foss.heptapod.net/pypy/pypy/-/issues/3612
.. _3616: https://foss.heptapod.net/pypy/pypy/-/issues/3616
.. _3617: https://foss.heptapod.net/pypy/pypy/-/issues/3617
.. _3618: https://foss.heptapod.net/pypy/pypy/-/issues/3618
.. _3623: https://foss.heptapod.net/pypy/pypy/-/issues/3623
.. _3624: https://foss.heptapod.net/pypy/pypy/-/issues/3624
.. _3625: https://foss.heptapod.net/pypy/pypy/-/issues/3625
.. _3628: https://foss.heptapod.net/pypy/pypy/-/issues/3628
.. _3627: https://foss.heptapod.net/pypy/pypy/-/issues/3627
.. _3630: https://foss.heptapod.net/pypy/pypy/-/issues/3630
.. _3644: https://foss.heptapod.net/pypy/pypy/-/issues/3644
.. _3642: https://foss.heptapod.net/pypy/pypy/-/issues/3642
.. _3652: https://foss.heptapod.net/pypy/pypy/-/issues/3652
.. _3650: https://foss.heptapod.net/pypy/pypy/-/issues/3650
.. _3656: https://foss.heptapod.net/pypy/pypy/-/issues/3656
.. _3661: https://foss.heptapod.net/pypy/pypy/-/issues/3661
.. _3676: https://foss.heptapod.net/pypy/pypy/-/issues/3676
.. _3678: https://foss.heptapod.net/pypy/pypy/-/issues/3678
.. _3682: https://foss.heptapod.net/pypy/pypy/-/issues/3682
.. _bpo35883: https://bugs.python.org/issue35883
.. _bpo44954: https://bugs.python.org/issue44954
.. _bpo40780: https://bugs.python.org/issue40780
.. _bpo35766: https://bugs.python.org/issue35766
.. _bpo43522: https://bugs.python.org/issue43522
.. _bpo35545: https://bugs.python.org/issue35545
.. _errcheck: https://docs.python.org/3/library/ctypes.html#ctypes._FuncPtr.errcheck
.. _`speed regression`: https://foss.heptapod.net/pypy/pypy/-/issues/3649
