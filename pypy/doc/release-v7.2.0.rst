====================================
PyPy v7.2.0: release of 2.7, and 3.6
====================================

The PyPy team is proud to release the version 7.2.0 of PyPy, which includes
two different interpreters:

  - PyPy2.7, which is an interpreter supporting the syntax and the features of
    Python 2.7 including the stdlib for CPython 2.7.13

  - PyPy3.6: which is an interpreter supporting the syntax and the features of
    Python 3.6, including the stdlib for CPython 3.6.9.
    
The interpreters are based on much the same codebase, thus the double
release.

With the support of Arm Holdings Ltd. and `Crossbar.io`_, this release supports
the 64-bit ``aarch64`` ARM architecture. More about the work and the
performance data around this welcome development can be found in the `blog
post`_.

This release removes the "beta" tag from PyPy3.6. While there may still be some
small corner-case incompatibilities (around the exact error messages in
exceptions and the handling of faulty codec errorhandlers) we are happy with
the quality of the 3.6 series and are looking forward to working on a Python
3.7 interpreter.

We updated our benchmark runner at https://speed.pypy.org to a more modern
machine and updated the baseline python to CPython 2.7.11. Thanks to `Baroque
Software`_ for maintaining the benchmark runner.

The CFFI-based ``_ssl`` module was backported to PyPy2.7 and updated to use
cryptography_ version 2.7. Additionally the ``_hashlib``, and ``crypt`` (or
``_crypt`` on Python3) modules were converted to CFFI. This has two
consequences. End users and packagers can more easily update these libraries
for their platform by executing ``(cd lib_pypy; ../bin/pypy _*_build.py)``.
More significantly, since PyPy itself links to fewer system shared objects
(DLLs), on platforms with a single runtime namespace like linux different CFFI
and c-extension modules can load different versions of the same shared object
into PyPy without collision (`issue 2617`_).

Until downstream providers begin to distribute c-extension builds with PyPy, we
have made packages for some common packages `available as wheels`_.

The `CFFI`_ backend has been updated to version 1.13.0. We recommend using CFFI
rather than c-extensions to interact with C, and `cppyy`_ for interacting with
C++ code.

Thanks to Anvil_, we revived the `PyPy Sandbox`_, which allows total control
over a python interpreter's interactions with the external world.

We implemented a new JSON decoder that is much faster, uses less memory, and
uses a JIT-friendly specialized dictionary.

As always, this release is 100% compatible with the previous one and fixed
several issues and bugs raised by the growing community of PyPy users.
We strongly recommend updating. Many of the fixes are the direct result of
end-user bug reports, so please continue reporting issues as they crop up.

You can download the v7.2 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work.

We would also like to thank our contributors and encourage new people to join
the project. PyPy has many layers and we need help with all of them: `PyPy`_
and `RPython`_ documentation improvements, tweaking popular modules to run
on pypy, or general `help`_ with making RPython's JIT even better. Since the
previous release, we have accepted contributions from 27 new contributors,
thanks for pitching in.

.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`help`: project-ideas.html
.. _`CFFI`: https://cffi.readthedocs.io
.. _`cppyy`: https://cppyy.readthedocs.io
.. _`available as wheels`: https://github.com/antocuni/pypy-wheels
.. _`Baroque Software`: https://baroquesoftware.com
.. _Anvil: https://anvil.works
.. _`PyPy Sandbox`: https://morepypy.blogspot.com/2019/08
.. _`Crossbar.io`: https://crossbario.com
.. _`blog post`:  https://morepypy.blogspot.com/2019/07/pypy-jit-for-aarch64.html
.. _cryptography: https://cryptography.io/en/latest

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

  * 64-bit **ARM** machines running Linux.

Unfortunately at the moment of writing our ARM buildbots are out of service,
so for now we are **not** releasing any binary for the ARM architecture (32
bit), although PyPy does support ARM 32 bit processors. 

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html


Changelog
=========

Changes released in v7.1.1
--------------------------

* Improve performance of ``u''.append``
* Prevent a crash in ``zlib`` when flushing a closed stream
* Fix a few corner cases when encountering unicode values above 0x110000
* Teach the JIT how to handle very large constant lists, sets, or dicts
* Fix building on ARM32 (`issue 2984`_)
* Fix a bug in register assignment in ARM32
* Package windows DLLs needed by cffi modules next to the cffi c-extensions
  (`issue 2988`_)
* Cleanup and refactor JIT code to remove ``rpython.jit.metainterp.typesystem``
* Fix memoryviews of ctype structures with padding, (CPython issue 32780_)

Changes to Python 3.6 released in v7.1.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* On win32, override some ``errno.E*`` values that were added to MSVC in v2010
  so that ``errno.E* == errno.WSAE*`` as in CPython
* Do the same optimization that CPython does for ``(1, 2, 3, *a)`` (but at the
  AST level)
* Raise a ``TypeError`` when using buffers and unicode such as ``''.strip(buffer)``
  and ``'a' < buffer``
* Support ``_overlapped`` and asyncio on win32
* Fix an issue where ``''.join(list_of_strings)`` would rarely confuse utf8 and
  bytes (`issue 2997`_)
* Fix ``io.IncrementalNewlineDecoder`` interaction with ``\r`` (`issue 3012`_)

Changes shared across versions
------------------------------

* Update ``cffi`` to 1.13.0
* Add support for ARM aarch64
* Many internal changes to the utf-8 processing code, since now unicode strings
  are stored internally as utf-8. A few corner cases were fixed, and performance
  bottlenecks were improved. Specifically, issues were fixed with ``maketrans``,
  ``strip``, comparison with ``bytearray``, use in ``array.array``, ``join``,
  ``translate``, forrmatting, ``__int__``, ``str(<int>)``, ``startswith``,
  ``endswith``,
* Reduce the probability of a deadlock when acquiring a semaphore by
  moving global state changes closer to the actual aquire (`issue 2953`_)
* Cleanup and refactor parts of the JIT code
* Cleanup ``optimizeopt``
* Support the ``z15`` variant of the ``s390x`` CPU.
* Fixes to ``_ctypes`` handling of memoryviews
* Fix a shadowstack overflow when using ``sys.setrecursionlimit`` (`issue 2722`)
* Fix a bug that prevent memory-tracking in vmprof working on PyPy
* Improve the speed and memory use of the ``_pypyjson`` JSON decoder. The
  resulting dictionaries that come out of the JSON decoder have faster lookups too
* ``struct.unpack`` of a sliced ``bytearray`` exposed a subtle bug where the
  JIT's ``gc_load`` family of calls must force some lazy code (`issue 3014`_)
* Remove ``copystrcontent`` and ``copyunicodecontent`` in the backends.
  Instead, replace it in ``rewrite.py`` with a direct call to ``memcpy()`` and
  a new basic operation, ``load_effective_address``, which the backend can
  even decide not to implement.
* Allow 2d indexing in ``memoryview.__setitem__`` (`issue 3028`_)
* Speed up 'bytearray += bytes' and other similar combinations
* Compute the greatest common divisor of two RPython ``rbigint`` instances
  using `Lehmer's algorithm`_ and use it in the ``math`` module
* Add ``RFile.closed`` to mirror standard `file` behaviour
* Add a ``-D`` pytest option to run tests directly on the host python without
  any knowlege of PyPy internals. This allows using ``pypy3 pytest.py ...``
  for a subset of tests (called **app-level testing**)
* Accept arguments to ``subprocess.Popen`` that are not directly subscriptable
  (like iterators) (`issue 3050`_)
* Catch more low-level ``SocketError`` exceptions and turn them into app-level
  exceptions (`issue 3049`_)
* Fix formatting of a ``memoryview``: ``b"<%s>" % memoryview(b"X")``
* Correctly wrap the I/O errors we can get when importing modules
* Fix bad output from JSON with ``'skipkeys=True'`` (`issue 3052`_)
* Fix compatibility with latest virtualenv HEAD
* Avoid ``RuntimeError`` in ``repr()`` of recursive ``dictviews`` (CPython
  issue 18533_)
* Fix for printing after ``gc.get_objects()`` (`issue 2979`)
* Optimize many fast-paths through utf-8 code when we know it is ascii or no
  surroagates are present
* Check for a rare case of someone shrinking a buffer from another thread
  while using it in a ``read()`` variant. One of the issues discovered when
  reviewing the code for the sandbox.
* Prevent segfault when slicing ``array.array`` with a large step size
* Support building ``ncurses`` on Suse Linux
* Update statically-linked ``_ssl`` OpenSSL to 1.1.0c on ``darwin``
* Optimize ``W_TextIOWrapper._readline`` and ``ByteBuffer.getslice``
* Fix possible race condition in threading ``Lock.release()`` (`issue 3072`_)
* Make ``CDLL(None)`` on win32 raise ``TypeError``
* Change ``sys.getfilesystemcodeerors()`` to ``'strict'`` on win32
* Update vendored version of ``pycparser`` to version 2.19
* Implement a much faster JSON decoder (3x speedup for large json files, 2x less memory)

C-API (cpyext) and c-extensions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* Add ``DateTime_FromTimestamp`` and ``Date_FromTimestamp`` to the 
  ``PyDateTime_CAPI`` struct

* Add constants and macros needed to build opencv2_ with PyPy2.7
* Add more constants to `sysconfig``. Set ``MACOSX_DEPLOYMENT_TARGET`` for
  darwin (`issue 2994`_)
* fix ``CBuffer.buffer_attach``
* Add ``_PyDict_GetItemWithError`` (``PyDict_GetItemWithError`` on Python3)

Python 3.6 only
---------------

* Accept ``a, b = (*x, 2)`` (`issue 2995`_)
* Class methods with the signature ``def meth(*args, **kwargs)`` were not adding
  an implied ``self`` argument (`issue 2996`_)
* Fix handling of ``__fpath__`` (`issue 2985`_)
* Disable ``assert`` when run with ``-O`` (`issue 3000`_)
* ``codecs.encode``, ``codecs.decode`` can behave differently than
  ``ustr.encode``, ``bytes.decode`` (`issue 3001`_)
* Putting ``pdb.set_trace`` call in a threaded program did not work (`issue
  3003`_)
* Fix parsing for converting strings with underscore into ints
* Add ``memoryview.obj`` which stores a reference, (`issue 3016`_)
* Fix datetime.fromtimestamp for win32 (CPython issue 29097_)
* Improve multiprocessing support on win32
* Support negative offsets in ``lnotab`` (`issue 2943`_)
* Fix leak of file descriptor with `_io.FileIO('dir/')`
* Fix ``float.__round__(None)`` (`issue 3033`_)
* Fix for when we should use the Universal Newline mode on Windows for
  stdin/stdout/stderr (`issue 3007`_)
* Fix ImportError invalid arguments error wording
* Ignore GeneratorExit when throwing into the aclose coroutine of an
  asynchronous generator (CPython issue 35409_)
* Improve the pure-python ``faulthander`` module
* Properly raise an exception when a ``BlockingIOError`` exception escapes
  from ``W_BufferedReader.readline_w()`` (`issue 3042`_)
* Fix a code path only used in ``zipimport`` (`issue 3034`_)
* Update the stdlib to 3.6.9, fix many failing tests
* Fix handling of ``__debug__``, ``-O``, and ``sys.flags.optimizeOptimize``
  (CPython issue 27169_)
* Fix raising ``SystemExit`` in ``atexit``
* Fix case where ``int(<subint>)`` would go into infinite recursion
* Don't ignore fold parameter in ``(date,)time.replace()``
* Fix logic bug for ``memoryview.cast`` (when ``view.format`` is not ``'B'``)
* Implement retry-on-EINTR in fcntl module (CPython issue 35189_)
* Fix handling of 1st argument to ``hashlib.blake2{b,s}()`` (CPython issue
  33729_)
* Prevent overflow in ``_hashlib`` ``digest()`` (CPython issue 34922_)
* ``IOBase.readlines()`` relies on the iterator protocol instead of calling
  ``readline()`` directly
* Don't inherit ``IS_ABSTRACT`` flag in classes
* Reset raw_pos after unwinding the raw stream (CPython issue 32228_)
* Add existing options ``-b`` and ``-d`` to ``pypy3 --help`` text
* Clean up ``_codecs`` error handling code
* Add support for using stdlib as a zipfile
* Check return type of ``__prepare__()`` (CPython issue 31588_)
* Fix logic in ``_curses.get_wch`` (`issue 3064`_)
* Match CPython exit code when failing to flush stdout/stderr at exit
* Improve SyntaxError message output
* Add ``range.__bool__``
* Add cursor validity check to ``_sqlite.Cursor.close``
* Improve message when mistakenly using ``print something`` in Python3
* Handle generator exit in ``athrow()`` (CPython issue 33786_)
* Support unmarshalling ``TYPE_INT64`` and turn ``OverflowErrors`` from
  ``marshal.loads`` into ``ValueErrors``
* Update ``_posixsubprocess.c`` to match CPython (CPython issue 32270_)
* Remove unused ``_posixsubprocess.cloexec_pipe()``
* Add missing constants to ``stat`` and ``kill _stat`` (`issue 3073`_)
* Fix argument handling in ``select.poll().poll()``
* Raise ``SyntaxError`` instead of ``DeprecationWarning`` when treating invalid
  escapes in bytes as errors (CPython issue 28691_)
* Handle locale in `time.strftime()`. (`issue 3079`_)
* Fix an issue when calling ``PyFrame.fset_f_lineno`` (`issue 3066`_)

Python 3.6 c-API
~~~~~~~~~~~~~~~~

* Add ``PyStructSequence_InitType2``, ``Py_RETURN_NOTIMPLEMENTED``,
  ``PyGILState_Check``, ``PyUnicode_AsUCS4``, ``PyUnicode_AsUCS4Copy``,
  ``PyErr_SetFromWindowsErr``,
* Sync the various ``Py**Flag`` constants with CPython
* Allow ``PyTypeObject`` with ``tp_doc==""`` (`issue 3055`_)
* Update ``pymacro.h`` to match CPython 3.6.9
* Support more datetime C functions and definitions

.. _`Lehmer's algorithm`: https://en.wikipedia.org/wiki/Lehmer's_GCD_algorithm
.. _29097: https://bugs.python.org/issue29097
.. _32780: https://bugs.python.org/issue32780
.. _35409 : https://bugs.python.org/issue35409
.. _27169 : https://bugs.python.org/issue27169
.. _18533 : https://bugs.python.org/issue18533
.. _35189 : https://bugs.python.org/issue35189
.. _33279 : https://bugs.python.org/issue33279
.. _34922 : https://bugs.python.org/issue34922
.. _32228 : https://bugs.python.org/issue32228
.. _31588 : https://bugs.python.org/issue31588
.. _33786 : https://bugs.python.org/issue33786
.. _32270 : https://bugs.python.org/issue32270
.. _28691 : https://bugs.python.org/issue28691
.. _33729 : https://bugs.python.org/issue33729

.. _opencv2: https://github.com/skvark/opencv-python/
.. _`issue 2617`: https://bitbucket.com/pypy/pypy/issues/2617
.. _`issue 2722`: https://bitbucket.com/pypy/pypy/issues/2722
.. _`issue 2953`: https://bitbucket.com/pypy/pypy/issues/2953
.. _`issue 2943`: https://bitbucket.com/pypy/pypy/issues/2943
.. _`issue 2980`: https://bitbucket.com/pypy/pypy/issues/2980
.. _`issue 2984`: https://bitbucket.com/pypy/pypy/issues/2984
.. _`issue 2994`: https://bitbucket.com/pypy/pypy/issues/2994
.. _`issue 2995`: https://bitbucket.com/pypy/pypy/issues/2995
.. _`issue 2996`: https://bitbucket.com/pypy/pypy/issues/2995
.. _`issue 2997`: https://bitbucket.com/pypy/pypy/issues/2995
.. _`issue 2988`: https://bitbucket.com/pypy/pypy/issues/2988
.. _`issue 2985`: https://bitbucket.com/pypy/pypy/issues/2985
.. _`issue 2986`: https://bitbucket.com/pypy/pypy/issues/2986
.. _`issue 3000`: https://bitbucket.com/pypy/pypy/issues/3000
.. _`issue 3001`: https://bitbucket.com/pypy/pypy/issues/3001
.. _`issue 3003`: https://bitbucket.com/pypy/pypy/issues/3003
.. _`issue 3007`: https://bitbucket.com/pypy/pypy/issues/3007
.. _`issue 3012`: https://bitbucket.com/pypy/pypy/issues/3012
.. _`issue 3014`: https://bitbucket.com/pypy/pypy/issues/3014
.. _`issue 3016`: https://bitbucket.com/pypy/pypy/issues/3016
.. _`issue 3028`: https://bitbucket.com/pypy/pypy/issues/3028
.. _`issue 3033`: https://bitbucket.com/pypy/pypy/issues/3033
.. _`issue 3034`: https://bitbucket.com/pypy/pypy/issues/3034
.. _`issue 3042`: https://bitbucket.com/pypy/pypy/issues/3042
.. _`issue 3049`: https://bitbucket.com/pypy/pypy/issues/3049
.. _`issue 3050`: https://bitbucket.com/pypy/pypy/issues/3050
.. _`issue 3052`: https://bitbucket.com/pypy/pypy/issues/3052
.. _`issue 3055`: https://bitbucket.com/pypy/pypy/issues/3055
.. _`issue 2979`: https://bitbucket.com/pypy/pypy/issues/2979
.. _`issue 3064`: https://bitbucket.com/pypy/pypy/issues/3064
.. _`issue 3072`: https://bitbucket.com/pypy/pypy/issues/3072
.. _`issue 3073`: https://bitbucket.com/pypy/pypy/issues/3073
.. _`issue 3079`: https://bitbucket.com/pypy/pypy/issues/3079
.. _`issue 3066`: https://bitbucket.com/pypy/pypy/issues/3066
