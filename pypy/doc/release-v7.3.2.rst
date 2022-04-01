===============================================
PyPy v7.3.2: release of 2.7, 3.6, and 3.7 alpha
===============================================

The PyPy team is proud to release the version 7.3.2 of PyPy, which includes
three different interpreters:

  - PyPy2.7, which is an interpreter supporting the syntax and the features of
    Python 2.7 including the stdlib for CPython 2.7.13

  - PyPy3.6: which is an interpreter supporting the syntax and the features of
    Python 3.6, including the stdlib for CPython 3.6.9.
    
  - PyPy3.7 alpha: which is our first release of an interpreter supporting the
    syntax and the features of Python 3.7, including the stdlib for CPython
    3.7.9. We call this alpha quality software, there may be issues about
    compatibility with new and changed features in CPython 3.7.
    Please let us know what is broken or missing. We have not implemented the
    `documented changes`_ in the ``re`` module, and a few other pieces are also
    missing. For more information, see the `PyPy 3.7 wiki`_ page
    
The interpreters are based on much the same codebase, thus the multiple
release. This is a micro release, all APIs are compatible with the 7.3.0 (Dec
2019) and 7.3.1 (April 2020) releases, but read on to find out what is new.

..
  The major new feature is prelminary support for the Universal mode of HPy: a
  new way of writing c-extension modules to totally encapsulate the `PyObject*`.
  The goal, as laid out in the `HPy blog post`_, is to enable a migration path
  for c-extension authors who wish their code to be performant on alternative
  interpreters like GraalPython_ (written on top of the Java virtual machine),
  RustPython_, and PyPy. Thanks to Oracle for sponsoring work on HPy.

Conda Forge now `supports PyPy`_ as a python interpreter. The support is quite
complete for linux and macOS. This is the result of a lot of
hard work and goodwill on the part of the Conda Forge team.  A big shout out
to them for taking this on.

Development of PyPy has moved to https://foss.heptapod.net/pypy/pypy.
This was covered more extensively in this `blog post`_. We have seen an
increase in the number of drive-by contributors who are able to use gitlab +
mercurial to create merge requests.

The `CFFI`_ backend has been updated to version 1.14.2. We recommend using CFFI
rather than c-extensions to interact with C, and using cppyy_ for performant
wrapping of C++ code for Python.

Numpy has begun shipping `wheels on PyPI` for PyPy, currently for linux 64-bit
only.  Wheels for PyPy windows will be available from the next NumPy release.

A new contributor took us up on the challenge to get `windows 64-bit`` support.
The work is proceeding on the ``win64`` branch, more help in coding or
sponsorship is welcome.

As always, this release fixed several issues and bugs.  We strongly recommend
updating. Many of the fixes are the direct result of end-user bug reports, so
please continue reporting issues as they crop up.

You can find links to download the v7.3.2 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work.

We would also like to thank our contributors and encourage new people to join
the project. PyPy has many layers and we need help with all of them: `PyPy`_
and `RPython`_ documentation improvements, tweaking popular modules to run
on pypy, or general `help`_ with making RPython's JIT even better. Since the
previous release, we have accepted contributions from 8 new contributors,
thanks for pitching in.

If you are a python library maintainer and use c-extensions, please consider
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
.. _`blog post`: https://morepypy.blogspot.com/2020/02/pypy-and-cffi-have-moved-to-heptapod.html
.. _`supports PyPy`: https://conda-forge.org/blog//2020/03/10/pypy
.. _`documented changes`: https://docs.python.org/3/whatsnew/3.7.html#re
.. _`PyPy 3.7 wiki`: https://foss.heptapod.net/pypy/pypy/-/wikis/py3.7%20status
.. _`wheels on PyPI`: https://pypi.org/project/numpy/#files
.. _`windows 64-bit`: https://foss.heptapod.net/pypy/pypy/-/issues/2073#note_141389
.. _`HPy blog post`: https://morepypy.blogspot.com/2019/12/hpy-kick-off-sprint-report.html
.. _`GraalPython`: https://github.com/graalvm/graalpython
.. _`RustPython`: https://github.com/RustPython/RustPython


What is PyPy?
=============

PyPy is a Python interpreter, a drop-in replacement for CPython 2.7, 3.6, and
3.7. It's fast (`PyPy and CPython 2.7.x`_ performance
comparison) due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

This PyPy release supports:

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 32 bits, OpenBSD, FreeBSD)

  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

  * 64-bit **ARM** machines running Linux.

PyPy does support ARM 32 bit processors, but does not release binaries.

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

Changelog
=========

Changes shared across versions
------------------------------
- More sysconfig fixes for win32
- Fix ``time.tm_gmtoff`` and ``tm_zone`` on win32 to be like CPython
- Speed up the performance of matching unicode strings in the sre engine
- Add jobs control to the Makefile (`issue 3187`_)
- encode unicodes even in (built-in) files opened in binary mode (`issue 3178`_)
- Refactor ``RSocket.xxx_into()`` methods and add ``.recvmsg_into()``
- Invoke ``pip`` via ``runpy`` in ``ensurepip`` (`merge request 723`_)
- Fix implementation of PEP 3118 in ``ctypes``
- Package macOS as a "portable package" including needed ``dylib`` files
- Allow overridden ``.__int__()`` in subclasses of ``complex``
- More bitbucket -> heptapod documentation fixes
- Fix path to tcl,tk on windows, `issue 3247`_
- Speed up ``list.pop``, ``list.insert`` operations that shift many items (`merge request 729`_)
- Update win32 to `openssl1.1`
- Assigning a class instance as ``__get__`` should call the class's
  ``__call__``, not its ``__get__`` (`issue 3255`_)
- Remove all implicit ``str``-``unicode`` conversions in RPython (`merge request 732`_)
- Need ``FORBID_TEMP_BOXES`` on aarch64, like on arm32, to prevent register spilling (`issue 3188`_)
- Initialize lock timeout on windows if timeout is infinite (impacted PyPy 2.7
  only) (`merge request 744`, `issue 3252`_)
- Move ``lib_pypy/tools`` -> ``lib_pypy/pypy_tools``: otherwise ``tools``
  appears on the ``sys.path``. This would override any ``tools`` in packages
  like NumPy.
- Update ``libffi_msvc`` by copying the fixes done in cffi, and also fix when
  returning a ``struct`` in CFFI
- Add full precision times from ``os.stat`` on macOS
- PyPy 2.7 only: add SOABI to distutils.sysconfig so wheel gets the correct ABI
  tag
- Use the full set of format strings in ``time.strftime`` on windows. After the
  transition to a more modern MSVC compiler, windows now supports strings like
  ``%D`` and others.
- Raise like CPython when ``strftime()`` year outside 1 - 9999 on windows
- Use ``wcsftime`` in ``strftime()`` on windows
- Fix `issue 3282`_ where iterating over a ``mmap`` should return an ``int``,
  not a ``byte``
- Use ``_chsize_s`` for ftruncate on windows: CPython issue 23668_
- Allow untranslated tests to run on top of PyPY2.7, not only CPython2.7
- Add missing ``os`` functions ``os.sched_rr_get_interval``,
  ``os.sched_getscheduler``, ``os.sched_setscheduler``, ``os.sched_getparam``
- Set ``buffer`` to ``None`` on close of buffered ``io`` classes
- Use the ``Suppres_IPH`` context manager wherever CPython uses
  ``_Py_BEGIN_SUPPRESS_IPH``, ``_Py_END_SUPPRESS_IPH``
- Fix leaked string if an exception occurs in socket.settimeout on windows
- close open ``mmap`` and ``zipfile`` resources in stdlib tests
- Make stack 3MB on windows which aligns expectations with Linux
- Add ``pypyjit.releaseall()`` that marks all current machine code objects as
  ready to release. They will be released at the next GC (unless they are
  currently in use in the stack of one of the threads).
- Fix possible infinite loop in `tarfile.py`: CPython issue 39017_
- Reject control characters in http requests: CPython issue 39603_
- Fix regex in parsing http headers to reject infinite backtracking: CPyton
  issue 39503_
- Escape the server title when rendering from ``xmlrpc`` as HTML: CPython issue
  38243_
- Build fixes for latest XCode on MacOS


C-API (cpyext) and c-extensions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- Add ``PyCFunction_Call``, ``PyNumber_ToBase``, contiguous part of
  ``PyMemoryView_GetContiguous``
- use ``space.getitem`` in ``PySequence_ITEM``, fixes `pybind11 2146`_
- give preference to ``as_sequence.sq_item`` in ``PySequence_ITEM``
- In Py_EnterRecursiveCall, ``char*`` -> ``const char *``, `issue 3232`_
- Fix ``PySet_Add`` for ``frozenset`` (`issue 3251`_)
- Support using ``sq_repeat`` and ``sq_inplace_repeat``, `issue 3281`_

Python 3.6 only
---------------
- Fix ``_sqlite3.Connection`` with ``isolation_level=None`` in the constructor
- Fix embedded mode for CFFI (CFFI issue 449)
- Add ``socket.recvmsg_into``
- Fix return types in ``os.readlink()`` (`issue 3177`_) and ``os.listdir()``
- Fix `os.listdir()`` for win32
- Update ``_ssl`` to handle Post Handshake Authorization callbacks (PHA)
- Fix ``oldcrc`` argument of ``binascii.crc_hqx`` to ``unsigned int``
- Implement ``socket.sethostname()`` (`issue 3198`_)
- Backport CPython `35519`_: "Rename test.bisect to test.bisect_cmd" from CPython 3.7
- Fix the repr of ``SRE_Pattern`` and ``SRE_Match``
- Fix ill-defined behaviour with class.__init__ (`issue 3239`_)
- Improve pickling performance (`issue 3230`_)
- Forward port race condition fix from PyPy 2.7 ``Lib/weakref.py`` (`issue 3243`_)
- Implement bpo `30465`_: Fix lineno and col_offset in fstring AST nodes (`merge request 730`_)
- Implement bpo `29104`_: Fixed parsing backslashes in f-strings (`merge request 736`_)
- Fix ``time.sleep`` bug in win32
- Expose missing ``lzma_stream_encoder`` in cffi ``_lzma`` module (`issue 3242_`)
- Fix ``os.unsetenv`` on win32, bpo `39413`_ (CPython 3.7+, we can do 3.6+)
- Add symlinks to ``pypy``, ``pypy3.6`` to linux, macOS tarball. Maybe needed for macOS and multibuild
- The following sequence no longer makes any copy: ``b = StringBuilder();
  b.append(some_large_string); s = b.build()``
- Add missing ``os`` constants: ``P_NOWAIT``, ``P_NOWAITO``, ``P_WAIT``
- Allow codec errorhandlers to modify the underlying str/bytes being converted
- Do not import ``platform`` at startup (`issue 3269`_)
- Enable more extensive optimizations of list strategies on Python3, since
  ``int`` and ``long`` are the same (`issue 3250`_)
- Special case bytewise codec errorhandlers ``replace``, ``ignore``,
  ``surrogateescape`` to use the same logic as ``final == True``
- Allow ``CRTL-C`` to interrupt ``time.sleep`` on windows
- Inhibit compiler tail-call optimization via ``PYPY_INHIBIT_TAIL_CALL`` on windows
- When ``pypy -m pip`` fails to find ``pip``, give an error message that hints
  at ``pypy -m ensurepip``
- Fix broken ``_socket.share`` on windows
- Add missing ``os.{gs}et_handle_inheritable`` (PEP 446) on windows
- Fix ip address hashing in ``ipaddress.py``: CPython issue 41004_
- Disallow CR/LF in ``email.headerregistry.Address``: CPython issue 39073_
- Ban ``reuse_address`` parameter in ``loop.create_datagram_endpoint()`` in
  ``asyncio.base_events``: CPython issue 37228
- Preventing newline in ``encodongs.uu.filename`` from corrupting the output
  format: CPython issue 38945
- Prevent backtracking in regexes in ``http.cookiejar``: Cpython issue 38804_
- Sync ``email._header_value_parser``, ``email._parseaddr`` and their
  respective tests: CPython 37461_ and 34155_
- Revert extending ``time.time()`` and friends to accept an optional ``info``
  argument, use a private ``time`` function instead.

Python 3.6 C-API
~~~~~~~~~~~~~~~~
- Add ``PyType_GetFlags``, ``PyType_GetSlot``, ``PyUnicode_{En,De}code_Locale``,
  ``PyUnicode_{Find,Read,Write}Char``,
- Fix ``PyUnicode_*`` handling on windows where ``wchar_t`` is 2 bytes

.. _`issue 3187`: https://foss.heptapod.net/pypy/pypy/-/issues/3187
.. _`issue 3178`: https://foss.heptapod.net/pypy/pypy/-/issues/3178
.. _`issue 3177`: https://foss.heptapod.net/pypy/pypy/-/issues/3177
.. _`issue 3188`: https://foss.heptapod.net/pypy/pypy/-/issues/3188
.. _`issue 3198`: https://foss.heptapod.net/pypy/pypy/-/issues/3198
.. _`issue 3232`: https://foss.heptapod.net/pypy/pypy/-/issues/3232
.. _`issue 3239`: https://foss.heptapod.net/pypy/pypy/-/issues/3239
.. _`issue 3230`: https://foss.heptapod.net/pypy/pypy/-/issues/3230
.. _`issue 3242`: https://foss.heptapod.net/pypy/pypy/-/issues/3242
.. _`issue 3243`: https://foss.heptapod.net/pypy/pypy/-/issues/3243
.. _`issue 3247`: https://foss.heptapod.net/pypy/pypy/-/issues/3247
.. _`issue 3250`: https://foss.heptapod.net/pypy/pypy/-/issues/3250
.. _`issue 3251`: https://foss.heptapod.net/pypy/pypy/-/issues/3251
.. _`issue 3252`: https://foss.heptapod.net/pypy/pypy/-/issues/3252
.. _`issue 3255`: https://foss.heptapod.net/pypy/pypy/-/issues/3255
.. _`issue 3269`: https://foss.heptapod.net/pypy/pypy/-/issues/3269
.. _`issue 3274`: https://foss.heptapod.net/pypy/pypy/-/issues/3274
.. _`issue 3282`: https://foss.heptapod.net/pypy/pypy/-/issues/3282
.. _`issue 3281`: https://foss.heptapod.net/pypy/pypy/-/issues/3281

.. _`merge request 723`: https://foss.heptapod.net/pypy/pypy/-/merge_request/723
.. _`merge request 729`: https://foss.heptapod.net/pypy/pypy/-/merge_request/729
.. _`merge request 730`: https://foss.heptapod.net/pypy/pypy/-/merge_request/730
.. _`merge request 736`: https://foss.heptapod.net/pypy/pypy/-/merge_request/736
.. _`merge request 732`: https://foss.heptapod.net/pypy/pypy/-/merge_request/732
.. _`merge request 744`: https://foss.heptapod.net/pypy/pypy/-/merge_request/744

.. _31976: https://bugs.python.org/issue31976
.. _35519: https://bugs.python.org/issue35519
.. _30465: https://bugs.python.org/issue30465
.. _39413: https://bugs.python.org/issue39413
.. _23668: https://bugs.python.org/issue23668
.. _29104: https://bugs.python.org/issue29104
.. _39017: https://bugs.python.org/issue39017
.. _41014: https://bugs.python.org/issue41014
.. _39603: https://bugs.python.org/issue39603
.. _39503: https://bugs.python.org/issue39503
.. _39073: https://bugs.python.org/issue39073
.. _37228: https://bugs.python.org/issue37228
.. _38945: https://bugs.python.org/issue38945
.. _38804: https://bugs.python.org/issue38804
.. _38243: https://bugs.python.org/issue38243
.. _37461: https://bugs.python.org/issue37461
.. _34155: https://bugs.python.org/issue34155
.. _41004: https://bugs.python.org/issue41004

.. _`pybind11 2146`: https://github.com/pybind/pybind11/pull/2146
