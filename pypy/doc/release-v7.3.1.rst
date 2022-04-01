===================================
PyPy v7.3.1: release of 2.7 and 3.6
===================================

The PyPy team is proud to release the version 7.3.1 of PyPy, which includes
two different interpreters:

  - PyPy2.7, which is an interpreter supporting the syntax and the features of
    Python 2.7 including the stdlib for CPython 2.7.13

  - PyPy3.6: which is an interpreter supporting the syntax and the features of
    Python 3.6, including the stdlib for CPython 3.6.9.
    
The interpreters are based on much the same codebase, thus the multiple
release. This is a micro release, no APIs have changed since the 7.3.0 release
in December, but read on to find out what is new.

Conda Forge now `supports PyPy`_ as a python interpreter. The support right now
is being built out. After this release, many more c-extension-based
packages can be successfully built and uploaded. This is the result of a lot of
hard work and good will on the part of the Conda Forge team.  A big shout out
to them for taking this on.

We have worked with the python packaging group to support tooling around
building third party packages for python, so this release updates the pip and
setuptools installed when executing ``pypy -mensurepip`` to ``pip>=20``. This
completes the work done to update the PEP 425 `python tag`_ from ``pp373`` to
mean "PyPy 7.3 running python3" to ``pp36`` meaning "PyPy running python
3.6" (the format is recommended in the PEP). The tag itself was
changed in 7.3.0, but older pip versions build their own tag without querying
pypy. This means that wheels built for the previous tag format will not be
discovered by pip from this version, so library authors should update their
PyPY-specific wheels on PyPI.

Development of PyPy is transitioning to https://foss.heptapod.net/pypy/pypy.
This move was covered more extensively in the `blog post`_ from last month.

The `CFFI`_ backend has been updated to version 14.0. We recommend using CFFI
rather than c-extensions to interact with C, and using cppyy_ for performant
wrapping of C++ code for Python. The ``cppyy`` backend has been enabled
experimentally for win32, try it out and let use know how it works.

Enabling ``cppyy`` requires a more modern C compiler, so win32 is now built
with MSVC160 (Visual Studio 2019). This is true for PyPy 3.6 as well as for 2.7.

We have improved warmup time by up to 20%, performance of ``io.StringIO`` to
match if not be faster than CPython, and improved JIT code generation for
generators (and generator expressions in particular) when passing them to
functions like ``sum``, ``map``, and ``map`` that consume them.

As always, this release fixed several issues and bugs raised by the growing
community of PyPy users.  We strongly recommend updating. Many of the fixes are
the direct result of end-user bug reports, so please continue reporting issues
as they crop up.

You can find links to download the v7.3.1 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work.

We would also like to thank our contributors and encourage new people to join
the project. PyPy has many layers and we need help with all of them: `PyPy`_
and `RPython`_ documentation improvements, tweaking popular modules to run
on pypy, or general `help`_ with making RPython's JIT even better. Since the
previous release, we have accepted contributions from 13 new contributors,
thanks for pitching in.

If you are a python library maintainer and use c-extensions, please consider
making a cffi / cppyy version of your library that would be performant on PyPy.
In any case both `cibuildwheel`_ and the `multibuild system`_ support
building wheels for PyPy wheels.

.. _`PyPy`: index.html
.. _`RPython`: https://rpython.readthedocs.org
.. _`help`: project-ideas.html
.. _`CFFI`: https://cffi.readthedocs.io
.. _`cppyy`: https://cppyy.readthedocs.io
.. _`available as wheels`: https://github.com/antocuni/pypy-wheels
.. _`portable-pypy`: https://github.com/squeaky-pl/portable-pypy
.. _`docker images`: https://github.com/pypy/manylinux
.. _`multibuild system`: https://github.com/matthew-brett/multibuild
.. _`cibuildwheel`: https://github.com/joerick/cibuildwheel
.. _`manylinux2010`: https://github.com/pypa/manylinux
.. _`blog post`: https://morepypy.blogspot.com/2020/02/pypy-and-cffi-have-moved-to-heptapod.html
.. _ `python tag`: https://www.python.org/dev/peps/pep-0425/#python-tag
.. _`supports PyPy`: https://conda-forge.org/blog//2020/03/10/pypy


What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7, 3.6, and soon 3.7. It's fast (`PyPy and CPython 2.7.x`_ performance
comparison) due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

This PyPy release supports:

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 32 bits, OpenBSD, FreeBSD)

  * big- and little-endian variants of **PPC64** running Linux,

  * **s390x** running Linux

  * 64-bit **ARM** machines running Linux.

Unfortunately at the moment of writing our ARM32 buildbots are out of service,
so for now we are **not** releasing any binaries for that architecture,
although PyPy does support ARM 32 bit processors. 

.. _`PyPy and CPython 2.7.x`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html


Changelog
=========

Changes shared across versions
------------------------------
- We now package and ship the script to rebuild all the stdlib helper modules
  that on CPython are written as c-extensions and in PyPy use CFFI. These are
  located in ``lib_pypy``, and the build script in ``lib_pypy/pypy_tools``.
- Implement CPython 16055_: Fixes incorrect error text for
  ``int('1', base=1000)``.
- Handle NaN correctly in ``array.array``.
- Fix `issue 3137`_: rsplit of unicode strings that end with a non-ascii char
  was broken
- Fix `issue 3140`_: add ``$dist_name`` to ``include`` path when using
  ``setup.py install``
- Fix `issue 3146`_: using a jsonDict as an instance `__dict__` would segfault
- Fix `issue 3144`_: using `wch` in the curses CFFI module 
- Fix `issue 3149`_ which is related to the still-open CPython issue 12029_
  around Exceptions, metaclasses, ``__instancecheck__`` and ``__subclasscheck__``
- Fix a corner case in ``multibytecodec``: for stateful codecs, when encoding
  fails and we use replacement, the replacement string must be written in the
  output preserving the state.
- Correct mistake in position when handling errors in unicode formatting
- Add ``__rsub__``, ``__rand__`` and ``__ror__``, ``__rxor__`` operations to
  set and frozenset objects
- Fix bug in locale-specific string formatting: the thousands separator was
  always ``'.'``
- Fix `issue 3065`_ (again!): segfault in ``mmap``
- ``rstruct.runpack`` should align for next read
- Fix `issue 3155`_: virtualenv on win32 installs into Scripts, not bin
- Add Python3.6 ``socket`` constants, they will be exposed in pypy2.7 as well
- Use better green keys for non-standard jitdrivers to make sure that e.g.
  generators are specialized based on their code object
- Improve warmup speed of PyPy by around ~5-20%

  - a few minor tweaks in the interpreter
  - since tracing guards is super costly, work harder at not emitting
    too many guard_not_invalidated while tracing
  - optimize quasi_immut during tracing
  - optimize loopinvariant calls during tracing
  - a small optimization around non-standard virtualizables during tracing
- Fix off-by-one error and rework system calls to ``_get_tzname`` on win32
- Fix `issue 3134`_: non-ascii filenames on win32
- Fix app-level bufferable classes, related to getting the CFFI backend to
  pyzmq working
- Improve performance of ``io.StringIO()``. It should now be faster than
  CPython in common use cases
- Fix bug in ``PyCode.__eq__``: the compiler contains careful logic to make
  sure that it doesn't unify things like ``0.0`` and ``-0.0`` (they are equal,
  but the sign still shouldn't be dropped)
- Speed up integer parsing with some fast paths for common cases
- Add ``__pypy__.utf8content`` to return the raw content of a Unicode object
  (for debugging)
- Update ``pip`` and ``setuptools`` in ``ensurepip`` to 20.0.2 and 44.0.0
  respectively
- Fix potential segfault in the zipimporter
- Fixes in the JIT backend for PowerPC 
- Update the statically-linked openssl to 1.1.1f on macOS.
- Fix `re` grouprefs which were broken for unicode

C-API (cpyext) and c-extensions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- Fix more of `issue 3141`_ : use ``Py_TYPE(op)`` instead of ``(ob)->ob_type``
  in our header files
- Partially resync ``pyport.h`` with CPython and add many missing constants
- Check for ``ferror`` when reading from a file in ``PyRun_File``

Python 3.6 only
---------------
- Fix for CPython 30891_: deadlock import detection causes deadlocks
- Don't swallow the UnicodeDecodeError in one corner case (fixes issue 3132)
- Follow CPython's behaviour more closely in sqlite3
- Fix `issue 3136`: On windows, ``os.putenv()`` cannot have a key with ``'='``
  in it.
- More closely follow CPython's line number output in disassembly of constants
- Don't give a new error message if metaclass is actually type
- Improve ``fcntl``'s handling of errors in functions that do not retry
- Re-implement ``BUILD_LIST_FROM_ARG`` as a fast path
- Fix `issue 3159`_: ``venv`` should copy directories, not just files
- Add missing ``MACOSX_DEPLOYMENT_TARGET`` to ``config_vars`` for Darwin
- Fix for path-as- ``memoryview`` on win32
- Fix `issue 3166`_: Obscure ordering-of-which-error-to-report-first
- Improve the performance of ``str.join``. This helps both lists (in some
  situations) and iterators, but the latter is helped more. Some speedups of
  >50% when using some other iterator
- Remove ``__PYVENV_LAUNCHER__`` from ``os.environ`` during startup on Darwin

Python 3.6 C-API
~~~~~~~~~~~~~~~~

- Fix `issue 3160`_: include ``structseq.h`` in ``Python.h`` (needed for
  ``PyStructSequence_InitType2`` in NumPy)
- Fix `issue 3165`_: surrogates in ``PyUnicode_FromKindAndData``
- Add  ``PyDescr_TYPE``, ``PyDescr_NAME``.

.. _`issue 3065`: https://foss.heptapod.net/pypy/pypy/issues/3065
.. _`issue 3132`: https://foss.heptapod.net/pypy/pypy/issues/3132
.. _`issue 3134`: https://foss.heptapod.net/pypy/pypy/issues/3134
.. _`issue 3136`: https://foss.heptapod.net/pypy/pypy/issues/3136
.. _`issue 3137`: https://foss.heptapod.net/pypy/pypy/issues/3137
.. _`issue 3140`: https://foss.heptapod.net/pypy/pypy/issues/3140
.. _`issue 3141`: https://foss.heptapod.net/pypy/pypy/issues/3141
.. _`issue 3144`: https://foss.heptapod.net/pypy/pypy/issues/3144
.. _`issue 3146`: https://foss.heptapod.net/pypy/pypy/issues/3146
.. _`issue 3149`: https://foss.heptapod.net/pypy/pypy/issues/3149
.. _`issue 3155`: https://foss.heptapod.net/pypy/pypy/issues/3155
.. _`issue 3159`: https://foss.heptapod.net/pypy/pypy/issues/3159
.. _`issue 3160`: https://foss.heptapod.net/pypy/pypy/issues/3160
.. _`issue 3165`: https://foss.heptapod.net/pypy/pypy/issues/3165
.. _`issue 3166`: https://foss.heptapod.net/pypy/pypy/issues/3166

.. _12029: https://bugs.python.org/issue12029
.. _16055: https://bugs.python.org/issue16055
.. _30891: https://bugs.python.org/issue30891

.. _`python tag`: https://www.python.org/dev/peps/pep-0425/#python-tag
