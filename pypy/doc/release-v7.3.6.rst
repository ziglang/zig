=====================================================
PyPy v7.3.6: release of python 2.7, 3.7, and 3.8-beta
=====================================================

The PyPy team is proud to release version 7.3.6 of PyPy, which includes
three different interpreters:

  - PyPy2.7, which is an interpreter supporting the syntax and the features of
    Python 2.7 including the stdlib for CPython 2.7.18+ (the ``+`` is for
    backported security updates)

  - PyPy3.7,  which is an interpreter supporting the syntax and the features of
    Python 3.7, including the stdlib for CPython 3.7.12.

  - PyPy3.8, which is an interpreter supporting the syntax and the features of
    Python 3.8, including the stdlib for CPython 3.8.12. Since this is our
    first release of the interpreter, we relate to this as "beta" quality. We
    welcome testing of this version, if you discover incompatibilites, please
    report them so we can gain confidence in the version.

The interpreters are based on much the same codebase, thus the multiple
release. This is a micro release, all APIs are compatible with the other 7.3
releases. Highlights of the release, since the release of 7.3.5 in May 2021,
include:

  - We have merged a backend for HPy_, the better C-API interface. The backend
    implements version 0.0.3.
  - Translation of PyPy into a binary, known to be slow, is now about 40%
    faster. On a modern machine, PyPy3.8 can translate in about 20 minutes.
  - PyPy Windows 64 is now available on conda-forge_, along with over 600
    commonly used binary packages. This new offering joins the more than 1000
    conda packages for PyPy on Linux and macOS. Many thanks to the conda-forge
    maintainers for pushing this forward over the past 18 months.
  - Speed improvements were made to ``io``, ``sum``, ``_ssl`` and more. These
    were done in response to user feedback.
  - The 3.8 version of the release contains a beta-quality improvement to the
    JIT to better support `compiling huge Python functions`_ by breaking them
    up into smaller pieces.
  - The release of Python3.8 required a concerted effort. We were greatly
    helped by @isidentical (Batuhan Taskaya) and other new contributors.
  - The 3.8 package now uses the same layout as CPython, and many of the
    PyPy-specific changes to ``sysconfig``, ``distutils.sysconfig``, and
    ``distutils.commands.install.py`` have been removed. The ``stdlib`` now
    is located in ``<base>/lib/pypy3.8`` on ``posix`` systems, and in
    ``<base>/Lib`` on Windows. The include files on windows remain the same,
    on ``posix`` they are in ``<base>/include/pypy3.8``. Note we still use the
    ``pypy`` prefix to prevent mixing the files with CPython (which uses
    ``python``.

.. _`compiling huge Python functions`: https://www.pypy.org/posts/2021/09/jit-auto-generated-code.html


We recommend updating. You can find links to download the v7.3.6 releases here:

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
previous release, we have accepted contributions from 7 new contributors,
thanks for pitching in, and welcome to the project!

If you are a python library maintainer and use C-extensions, please consider
making a CFFI_ / cppyy_ version of your library that would be performant on PyPy.
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
.. _`conda-forge`: https://conda-forge.org/blog//2020/03/10/pypy
.. _HPy: https://hpyproject.org/


What is PyPy?
=============

PyPy is a Python interpreter, a drop-in replacement for CPython 2.7, 3.7, and
soon 3.8. It's fast (`PyPy and CPython 3.7.4`_ performance
comparison) due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

This PyPy release supports:

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 64 bits, OpenBSD, FreeBSD)

  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

  * 64-bit **ARM** machines running Linux.

PyPy does support Windows 32-bit and ARM 32 bit processors, but does not
release binaries. Please reach out to us if you wish to sponsor releases for
those platforms.

.. _`PyPy and CPython 3.7.4`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

Changelog
=========

Bugfixes shared across versions
-------------------------------
- Backport fix for `bpo 44022`_ in ``httplib``
- Make ``dotviewer`` Python3 compatible and add some features (like rudimentary
  record support).
- Fix error reporting when the error position is the last character of a JSON
  bytestring (issue 3514_)
- Set non-volatile xmm registers in the JIT for windows 64-bit calling
  conventions. Fixes a bug where the JIT was not restoring registers when
  returning from a call
- Support multiple tags in ``hg_archive``, fixes ``platform._sys_version()``
  which was reporting the first tag (i.e. rc1) when it should have reported
  the last tag (i.e. final)
- Fix position bugs in the astcompiler stemming from the fact that
  ``SyntaxErrors`` use 1-based column offsets
- Fix an obscure corner of ``%``-formatting when a tuple is passed in that
  triggered infinite recursion in the ``__repr__`` of a ``named_tuple`` with an
  ``__iter__`` (issue 3555_)
- Fixed a PowerPC JIT bug that caused a stack overflow (issue 3463_)

Speedups and enhancements shared across versions
------------------------------------------------
- Speed up RPython typing
- Speed up RPython graph cycle finding by removing leaves before checking
  for cycles
- Speed up C compilation on GCC by using the pre-compiled header feature
- When switching from an unwrapped list strategy to the ``ObjectListStrategy``,
  try to cache wrapped elements. This prevents the memory blowup on
  code like ``l = [0] * N; l[0] = "abc"`` (issue 2881_).
- Specialize builtin ``sum`` for lists/tuples (issue 3492_).
- Update to cffi 1.14.6
- Use ``libffi-7.dll`` on windows instead of an old vendored version of
  ``libffi``
- Fix for a corner case missing an optimization: ``interpindirect2app()`` on a
  function with signature ``'self, space, __args__'`` was missing the
  optimization for that signature, which works with ``interp2app()``.  It's
  used in ``_hpy_universal``.
- Add an option to the packaging script to force non-portable packaging (issue
  3538_)
- Switch to "powersort" merging strategy by Munro and Wild instead the timsort
  algorithm (`bpo 34561`_)
- Check env keys for ``'='`` when calling ``os.execve``
- Provide a PyPy-only scoped way to malloc buffers in cffi and use it in
  ``ssl.read``

C-API (cpyext) and C-extensions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
We are no longer backporting changes to the ``cpyext`` compatiblity layer to
PyPy2.7.


Python 3.7+ bugfixes
--------------------
- Fix MemoryError on zip.read in shutil._unpack_zipfile for large files `bpo
  43650`_ 
- Fix some issues around the ``obj`` field of ``memoryview``, and add missing
  ``toreadonly``.
- Fix ``re.sub()`` with no match and with unusual types of arguments (issue
  3515_)
- Fix ``_socket.sethostname()`` failure when passed bytes
- Switch ``sys.implementation.version`` and ``sys.implementation.hexversion``
  to ``pypy_version_info`` (i.e. (7, 3.  6) not (3, 7. 10)) (issue 3129_)
- Fix ``pypy -Wonce`` (issue 3411_)

Python 3.7+ speedups and enhancements
-------------------------------------
- Speep up cached imports by re-implementing (a subset of) `bpo 22557`_. This
  brings PyPy3.7 very close to the speed of PyPy2 (issue 3431_)
- Ignore finalizers on built-in ``io`` classes if we know the stream is closed.
  Also find some other optimizations aroudn ``io`` operations.
- Add more fields to ``sysconfig.get_config_var`` via ``_sysconfigdata`` (issue
  3483_)
- Add a ``sys.implementation._multiarch`` field like CPython on linux and
  darwin
- Add a ``lib_pypy\_sysconfigdata__*.py`` file like CPython on linux, darwin
  during packaging via ``sysconfig._generate_posix_vars()`` (issue 3483_)
- Slightly adapt the packaging and cffi-module build scripts for compatibility
  with conda-forge.
- Create ``pypy.exe``, ``pypyw.exe``, ``python.exe``, ``pythonw.exe`` when
  packaging for windows
- Speed up ``_ssl`` error processing by moving the class out of
  ``_PySSL_errno`` and creating a fast-path for instantiation (issue 3490_)
- Support HPy 0.0.2
- Use CPython list of consts in ``os.{confstr,pathconf,sysconf}_names`` (issue
  3502_)
- Add ``_winapi.GetFileType`` and ``FILE_TYPE_*`` values (issue 3531_)
- Allow ``ctypes.POINTER()`` to cast `ctypes.array`` (issue 3546_)
- Update the stdlib to v3.7.12

Python 3.7 C-API
~~~~~~~~~~~~~~~~
- Add PEP 495 c-api ``TimeAndFold`` datetime constructors (issue 2987_)
- Allow ``NULL`` in ``PyErr_WriteUnraisable`` (issue 3353_)
- Support ``*TimeZone*`` functions in datetime
- Add slot functions so ``int(x)`` and ``float(x)`` work properly where
  ``x`` is a c-extension class
- When creating a ``PyUnicodeObject``, use the compact form to store the data
  directly on the object and not via an additional buffer. This is used in
  pythran via ``_PyUnicode_COMPACT_DATA`` even though it is a "private"
  interface.
- Add ``PyGILState_Check``, ``PyContextVar_New``, ``PyContextVar_Get``,
  ``PyContextVar_Set``
- Add ``PyExc_WindowsError`` (issue 3472_)
- Add ``frame.f_back``, assuming the user is aware of the dangers of examinig
  the stack
- Fix typo in ``import.h``

.. _2881: https://foss.heptapod.net/pypy/pypy/-/issues/2881
.. _2987: https://foss.heptapod.net/pypy/pypy/-/issues/2987
.. _3129: https://foss.heptapod.net/pypy/pypy/-/issues/3129
.. _3353: https://foss.heptapod.net/pypy/pypy/-/issues/3353
.. _3431: https://foss.heptapod.net/pypy/pypy/-/issues/3431
.. _3402: https://foss.heptapod.net/pypy/pypy/-/issues/3402
.. _3411: https://foss.heptapod.net/pypy/pypy/-/issues/3411
.. _3463: https://foss.heptapod.net/pypy/pypy/-/issues/3463
.. _3472: https://foss.heptapod.net/pypy/pypy/-/issues/3472
.. _3483: https://foss.heptapod.net/pypy/pypy/-/issues/3483
.. _3490: https://foss.heptapod.net/pypy/pypy/-/issues/3490
.. _3492: https://foss.heptapod.net/pypy/pypy/-/issues/3492
.. _3502: https://foss.heptapod.net/pypy/pypy/-/issues/3502
.. _3514: https://foss.heptapod.net/pypy/pypy/-/issues/3514
.. _3515: https://foss.heptapod.net/pypy/pypy/-/issues/3515
.. _3531: https://foss.heptapod.net/pypy/pypy/-/issues/3531
.. _3538: https://foss.heptapod.net/pypy/pypy/-/issues/3538
.. _3546: https://foss.heptapod.net/pypy/pypy/-/issues/3546
.. _3555: https://foss.heptapod.net/pypy/pypy/-/issues/3555
.. _`bpo 22557`: https://bugs.python.org/issue22557
.. _`bpo 44022`: https://bugs.python.org/issue44022
.. _`bpo 43650`: https://bugs.python.org/issue43650
.. _`bpo 34561`: https://bugs.python.org/issue34561
