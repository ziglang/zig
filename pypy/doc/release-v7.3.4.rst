===================================
PyPy v7.3.4: release of 2.7 and 3.7
===================================

..
  Changelog up to commit 9c11d242d78c


The PyPy team is proud to release the version 7.3.4 of PyPy, which includes
two different interpreters:

  - PyPy2.7, which is an interpreter supporting the syntax and the features of
    Python 2.7 including the stdlib for CPython 2.7.18+ (the ``+`` is for
    backported security updates)

  - PyPy3.7,  which is an interpreter supporting the syntax and the features of
    Python 3.7, including the stdlib for CPython 3.7.10. We no longer refer to
    this as beta-quality as the last incompatibilities with CPython (in the
    ``re`` module) have been fixed.

We are no longer releasing a Python3.6 version, as we focus on updating to
Python 3.8. We have begun streaming the advances towards this goal on Saturday
evenings European time on https://www.twitch.tv/pypyproject. If Python3.6 is
important to you, please reach out as we could offer sponsored longer term
support.

The two interpreters are based on much the same codebase, thus the multiple
release. This is a micro release, all APIs are compatible with the other 7.3
releases. Highlights of the release include binary **Windows 64** support,
faster numerical instance fields, and a preliminary HPy backend.

A new contributor (Ondrej Baranovič - thanks!) took us up on the challenge to get
`windows 64-bit`_ support.  The work has been merged and for the first time we
are releasing a 64-bit Windows binary package.

The release contains the biggest change to `PyPy's implementation of the
instances of user-defined classes`_ in many years. The optimization was
motivated by the report of performance problems running a `numerical particle
emulation`_. We implemented an optimization that stores ``int`` and ``float``
instance fields in an unboxed way, as long as these fields are type-stable
(meaning that the same field always stores the same type, using the principle
of `type freezing`_). This gives significant performance improvements on
numerical pure-Python code, and other code where instances store many integers
or floating point numbers.

.. _`PyPy's implementation of the instances of user-defined classes`:
   https://www.pypy.org/posts/2010/11/efficiently-implementing-python-objects-3838329944323946932.html
.. _`numerical particle emulation`: https://github.com/paugier/nbabel
.. _`type freezing`: https://www.csl.cornell.edu/~cbatten/pdfs/cheng-type-freezing-cgo2020.pdf

There were also a number of optimizations for methods around strings and bytes,
following user reported performance problems. If you are unhappy with PyPy's
performance on some code of yours, please report `an issue`_!

.. _`an issue`: https://foss.heptapod.net/pypy/pypy/-/issues/

A major new feature is prelminary support for the Universal mode of HPy: a
new way of writing c-extension modules to totally encapsulate ``PyObject*``.
The goal, as laid out in the `HPy documentation`_ and recent `HPy blog post`_,
is to enable a migration path
for c-extension authors who wish their code to be performant on alternative
interpreters like GraalPython_ (written on top of the Java virtual machine),
RustPython_, and PyPy. Thanks to Oracle and IBM for sponsoring work on HPy.

Support for the vmprof_ statistical profiler has been extended to ARM64 via a
built-in backend.

Several issues exposed in the 7.3.3 release were fixed. Many of them came from the
great work ongoing to ship PyPy-compatible binary packages in `conda-forge`_.
A big shout out to them for taking this on.

Development of PyPy takes place on https://foss.heptapod.net/pypy/pypy.
We have seen an increase in the number of drive-by contributors who are able to
use gitlab + mercurial to create merge requests.

The `CFFI`_ backend has been updated to version 1.14.5 and the cppyy_ backend
to 1.14.2. We recommend using CFFI rather than C-extensions to interact with C,
and using cppyy for performant wrapping of C++ code for Python.

As always, we strongly recommend updating to the latest versions. Many fixes
are the direct result of end-user bug reports, so please continue reporting
issues as they crop up.

You can find links to download the v7.3.4 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work. If PyPy is helping you out, we would love to hear about
it and encourage submissions to our `renovated blog site`_ via a pull request
to https://github.com/pypy/pypy.org

We would also like to thank our contributors and encourage new people to join
the project. PyPy has many layers and we need help with all of them: `PyPy`_
and `RPython`_ documentation improvements, tweaking popular modules to run
on PyPy, or general `help`_ with making RPython's JIT even better. Since the
previous release, we have accepted contributions from 10 new contributors,
thanks for pitching in, and welcome to the project!

If you are a python library maintainer and use C-extensions, please consider
making a cffi / cppyy version of your library that would be performant on PyPy.
In any case both `cibuildwheel`_ and the `multibuild system`_ support
building wheels for PyPy.

.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`help`: project-ideas.html
.. _`CFFI`: https://cffi.readthedocs.io
.. _`cppyy`: https://cppyy.readthedocs.io
.. _`multibuild system`: https://github.com/matthew-brett/multibuild
.. _`cibuildwheel`: https://github.com/joerick/cibuildwheel
.. _`blog post`: https://pypy.org/blog/2020/02/pypy-and-cffi-have-moved-to-heptapod.html
.. _`conda-forge`: https://conda-forge.org/blog//2020/03/10/pypy
.. _`documented changes`: https://docs.python.org/3/whatsnew/3.7.html#re
.. _`PyPy 3.7 wiki`: https://foss.heptapod.net/pypy/pypy/-/wikis/py3.7%20status
.. _`wheels on PyPI`: https://pypi.org/project/numpy/#files
.. _`windows 64-bit`: https://foss.heptapod.net/pypy/pypy/-/issues/2073#note_141389
.. _`HPy documentation`: https://hpy.readthedocs.io/en/latest/
.. _`HPy blog post`: https://hpyproject.org/blog/posts/2021/03/hello-hpy/
.. _`GraalPython`: https://github.com/graalvm/graalpython
.. _`RustPython`: https://github.com/RustPython/RustPython
.. _`renovated blog site`: https://pypy.org/blog
.. _vmprof: https://vmprof.readthedocs.io/en/latest/


What is PyPy?
=============

PyPy is a Python interpreter, a drop-in replacement for CPython 2.7, 3.7, and
soon 3.8. It's fast (`PyPy and CPython 3.7.4`_ performance
comparison) due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

This PyPy release supports:

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 32/64 bits, OpenBSD, FreeBSD)

  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

  * 64-bit **ARM** machines running Linux.

PyPy does support ARM 32 bit processors, but does not release binaries.

.. _`PyPy and CPython 3.7.4`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

Changelog
=========

Bugfixes shared across versions
-------------------------------
- Test, fix xml default attribute values (issue 3333_, `bpo 42151`_)
- Rename ``_hashlib.Hash`` to ``HASH`` to match CPython
- Fix loading system libraries with ctypes on macOS Big Sur (issue 3314)
- Fix ``__thread_id`` in greenlets (issue 3381_)
- Reject XML entity declarations in plist files (`bpo 42051`_)
- Make compare_digest more constant-time (`bpo 40791`_)
- Only use '&' as a query string separator in url parsing (`bpo 42967`_)
- Fix `__r*__` reverse methods on weakref proxies
- Restore pickle of dict iterators on default (python2.7)

Speedups and enhancements shared across versions
------------------------------------------------
- Introduce a new RPython decorator ``@llhelper_error_value``, which
  officializes the fact that you can raise RPython exceptions from llhelpers,
  and makes it possible to specify what is the C value to return in case of
  errors. Useful for HPY_
- Introduce a new RPython decorator ``@never_allocate`` which ensures a class
  is **never** instantiated at runtime. Useful for objects that are required to
  be constant-folded away
- Upstream internal ``cparser`` tool from ``pypy/`` to ``rpython/``
- Make ``set.update(<non-set>)`` more jit-friendly by
  - unrolling it if the number of args is small (usually 1)
  - jitting the adding of new elements
  which fixes ``test_unpack_ex`` on PyPy3.7 as a side-effect
- Fix position of ``elif`` clauses in the AST
- Make the ``exe`` stack larger on windows
- Implement ``constcharpsize2str`` in rffi and refactor code to use it
- Add a ``versions.json`` to https://downloads.python.org/pypy/versions.json
  for the gitlab actions python install action
- Add symlinks for python, python3 to the package tarballs (not on Windows)
- Fix a missing error: bare ``except:``-clauses should come last in ``codegen``
- Copy manifest from CPython and link it into ``pypy.exe`` (issue 3363)
- Preserve ``None`` passed as ``REG_BINARY`` instead of crashing or changing it
  to an empty string in ``winreg`` (`bpo 21151`_)
- Add ``REG_QWORD*`` and ``Reg{Dis,En}ableReflectionKey``, and
  ``RegDeleteKeyEx`` to ``winreg``
- Backport msvc detection from python3, which probably breaks using Visual
  Studio 2008 (MSVC9, or the version that used to be used to build CPython2.7
  on Windows)
- Optimize chains of ``longlong2float(float2longlong(x))`` and vice versa
- Optimize instances of maps with integer and float fields by storing them
  unboxed in a float array (on 32bit machines this is only done for float
  fields). The float array is stored in one of the storage slots of the
  instance. Once a field proves to be type-unstable we give up on
  type-specializing this class and revert all instances once we touch them the
  next time to the default representation.
- Update the version of Tk/Tcl on windows to 8.6
- Updated ``cppyy`` API to ``cppyy_backend 1.14.2``: consistent types for
  Win64, support for new builtin types
- Refactor the intbound analysis in the JIT
- Faster ``str.replace`` and ``bytes.replace`` implementations.
- Implement ``vmprof`` support for aarch64
- Fast path for ``unicode.upper/lower``, ``unicodedb.toupper/lower`` for ascii,
  latin-1
- Add a JIT driver for ``re.split``
- Expose ``os.memfd_create`` on Linux for glibc>2.27 (not on portable builds)
- Add a shortcut for ``re.sub`` doing zero replacements
  for things like escaping characters)
- Expose the physical size of a list in ``__pypy__.list_get_physical_size``
- Clean up the icon bundled with the exe in windows
- Add a fast path for ``list[:] = l2``
- Update packaged OpenSSL to 1.1.1k
- Make ARM builds portable

C-API (cpyext) and C-extensions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- make order of arguments of ``PyDescr_NewGetSet`` consistent with CPython,
  related to issue 2267_
- Fix parsing ``inf`` and friends in ``PyOS_string_to_double`` (issue 3375_)
- Fix signature of ``PyEval_EvalCode``
- Change parameter type of ``PyModule_New`` to ``const char*``, add
  ``PyModule_Check`` and ``PyModule_CheckExact``
- Add ``PyUnicode_Contains`` (issue 3400_)
- Fix ``PyObject_Format`` for type objects (issue 3404_)
- Move ``inttypes.h`` into ``pyport.h`` (issue 3407_)
- Sync ``Py_.*Flags`` values with ``sys.flags`` (issue 3409_)
- Make ``PyUnicode_Check`` a macro, but still export the function from
  the shared library for backwards compatibility


Python 3.7+
-----------
- Update the ``re`` module to the Python 3.7 implementation
- Fix the ``crypt`` thread lock (issue 3395_) and fix input encoding (issue
  3378_)
- Fixes ``utf_8_decode`` for ``final=False`` (issue 3348_)
- Test, fix for ``time.strftime(u'%y\ud800%m', time.localtime(192039127))``
- ``CALL_FUNCTION_KW`` with keyword arguments is now much faster, because the
  data structure storing the arguments can be removed by the JIT
- Fix the ``repr`` of subclasses
- Better error message for ``object.__init__`` with too many parameters
- Fix bug in ``codecs`` where using a function from the parser turns warnings
  into SyntaxErrors a bit too eagerly
- Produce proper deprecation warnings from the compiler, with the right
  filename and line number
- Fixes for circular imports (`bpo 30024`_) and stack usage (`bpo 31286`_)
- A type annotated assignment was incorrectly handled in the scoping rules,
  leading to a crash in complex situations (issue 3355)
- Fix a segfault in nonblocking bufferio reads (issue 3172)
- Use correct slot for ``sni_callback`` attribute in ``_ssl`` (issue 3359_)
- Hang on to ``servername_callback`` handle in ``_ssl`` so it will not be
  deleted until the context is deleted (issue 3396)
- Implement ``set_wakeup_fd(warn_on_full_buffer)`` (issue 3227_)
- Round-trip invalid UTF-16 data in ``winreg`` without a ``UnicodeDecodeError``
  (issue 3342_)
- Truncate ``REG_SZ`` at first ``NULL`` in ``winreg`` to match ``reg.exe``
  behaviour (`bpo 25778`_)
- Fix for surrogates in ``winreg`` input value (issue 3345_)
- In ``sysconfig``, ``INCLUDEPY`` and ``INCLUDEDIR`` should point to the
  original directory even in a virtualenv (issue 3364_)
- Add ``LDLIBRARY`` to ``sysconfig`` for posgresql
- Prevent overflow in ``_hash_long`` on win64 using method from CPython
- Raise ``ValueError`` when ``argv[0]`` of ``execv`` and friends is empty (`bpo
  28732`_)
- Allow compiler to inherit flags from ``__future__.annotations`` (issue 3371_)
- Provide a PyPy ``BytesBuilder`` alternative to ``io.BytesIO`` in pure-python
  ``pickle``
- Generalize venv to copy all ``*.exe`` and ``*.dll`` for windows
- The evaluation order of keys and values of *large* dict literals was wrong in
  3.7 (in lower versions it was the same way, but in 3.7 the evaluation order
  of *small* dicts changed), issue 3380_
- Cache the imported ``re`` module in ``_sre`` (going through ``__import__`` is
  unfortunately quite expensive on 3.x)
- Mention a repeated keyword argument in the error message
- Stop emitting the ``STORE_ANNOTATION`` and ``BINARY_DIVIDE`` bytecodes,
  update pyc magic number
- Fix ``site.py`` to be closer to upstream to enable ``pip install --user`` and
  ``pip install --local``
- No longer call ``eval()`` on content received via HTTP in CJK codec tests (`bpo 41944`_)
- Add missing `c_/f_/contiguous` flags on memoryview
- Fix ``xml.ElementTree.extend`` not working on iterators (issue 3181_, `bpo 43399`_)
- `Python -m` now adds *starting* directory to `sys.path` (`bpo 33053`_)
- Reimplement ``heapq.merge()`` using a linked tournament tree (`bpo 38938`_)
- Fix shring of cursors in ``sqllite3`` (issues 3351_ and 3403_)
- Fix remaining ``sqllite3`` incompatibilities
- Fix ``CALL_METHOD_KW`` to not lose the immutability of the keyword name tuple

Python 3.7 C-API
~~~~~~~~~~~~~~~~
- Change ``char *`` to ``const char *`` in ``PyStructSequence_Field``,
  ``PyStructSequence_Desc``, ``PyGetSetDef``, ``wrapperbase``
- Implement ``METH_FASTCALL`` (issue 3357_)
- Add ``pystrtod.h`` and expose constants
- Clean up some ``char *`` -> ``const char *`` misnaming (issue 3362)
- Accept ``NULL`` input to ``PyLong_AsUnsignedLongLongMask``
- Add ``PyImport_GetModule`` (issue 3385_)
- Converting utf-8 to 1-byte buffers must consider latin-1 encoding (issue `3413`_)
- Fix value of ``.__module__`` and ``.__name__`` on the result of
  ``PyType_FromSpec``
- Add missing ``PyFile_FromFd``

.. _2267: https://foss.heptapod.net/pypy/pypy/-/issues/2267
.. _2371: https://foss.heptapod.net/pypy/pypy/-/issues/2371
.. _3172: https://foss.heptapod.net/pypy/pypy/-/issues/3172
.. _3181: https://foss.heptapod.net/pypy/pypy/-/issues/3181
.. _3227: https://foss.heptapod.net/pypy/pypy/-/issues/3227
.. _3314: https://foss.heptapod.net/pypy/pypy/-/issues/3314
.. _3333: https://foss.heptapod.net/pypy/pypy/-/issues/3333
.. _3342: https://foss.heptapod.net/pypy/pypy/-/issues/3342
.. _3345: https://foss.heptapod.net/pypy/pypy/-/issues/3345
.. _3348: https://foss.heptapod.net/pypy/pypy/-/issues/3348
.. _3351: https://foss.heptapod.net/pypy/pypy/-/issues/3351
.. _3355: https://foss.heptapod.net/pypy/pypy/-/issues/3355
.. _3357: https://foss.heptapod.net/pypy/pypy/-/issues/3357
.. _3359: https://foss.heptapod.net/pypy/pypy/-/issues/3359
.. _3362: https://foss.heptapod.net/pypy/pypy/-/issues/3362
.. _3363: https://foss.heptapod.net/pypy/pypy/-/issues/3363
.. _3364: https://foss.heptapod.net/pypy/pypy/-/issues/3364
.. _3371: https://foss.heptapod.net/pypy/pypy/-/issues/3371
.. _3375: https://foss.heptapod.net/pypy/pypy/-/issues/3375
.. _3378: https://foss.heptapod.net/pypy/pypy/-/issues/3378
.. _3380: https://foss.heptapod.net/pypy/pypy/-/issues/3380
.. _3385: https://foss.heptapod.net/pypy/pypy/-/issues/3385
.. _3381: https://foss.heptapod.net/pypy/pypy/-/issues/3381
.. _3395: https://foss.heptapod.net/pypy/pypy/-/issues/3395
.. _3396: https://foss.heptapod.net/pypy/pypy/-/issues/3396
.. _3400: https://foss.heptapod.net/pypy/pypy/-/issues/3400
.. _3403: https://foss.heptapod.net/pypy/pypy/-/issues/3403
.. _3404: https://foss.heptapod.net/pypy/pypy/-/issues/3404
.. _3407: https://foss.heptapod.net/pypy/pypy/-/issues/3407
.. _3409: https://foss.heptapod.net/pypy/pypy/-/issues/3409
.. _3413: https://foss.heptapod.net/pypy/pypy/-/issues/3413

.. _`merge request 723`: https://foss.heptapod.net/pypy/pypy/-/merge_request/723

.. _`bpo 21151`: https://bugs.python.org/issue21151
.. _`bpo 25778`: https://bugs.python.org/issue25778
.. _`bpo 28732`: https://bugs.python.org/issue28732
.. _`bpo 30024`: https://bugs.python.org/issue30024
.. _`bpo 31286`: https://bugs.python.org/issue31286
.. _`bpo 33053`: https://bugs.python.org/issue33053
.. _`bpo 38938`: https://bugs.python.org/issue38938
.. _`bpo 40791`: https://bugs.python.org/issue40791
.. _`bpo 41944`: https://bugs.python.org/issue41944
.. _`bpo 42051`: https://bugs.python.org/issue42051
.. _`bpo 42151`: https://bugs.python.org/issue42151
.. _`bpo 42967`: https://bugs.python.org/issue42967
.. _`bpo 43399`: https://bugs.python.org/issue43399

.. _HPy: https://hpy.readthedocs.io/en/latest/
