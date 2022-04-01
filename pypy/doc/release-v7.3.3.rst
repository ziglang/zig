==============================================
PyPy v7.3.3: release of 2.7, 3.6, and 3.7 beta
==============================================

-The PyPy team is proud to release the version 7.3.3 of PyPy, which includes
three different interpreters:

  - PyPy2.7, which is an interpreter supporting the syntax and the features of
    Python 2.7 including the stdlib for CPython 2.7.18 (updated from the
    previous version)

  - PyPy3.6: which is an interpreter supporting the syntax and the features of
    Python 3.6, including the stdlib for CPython 3.6.12 (updated from the
    previous version).
    
  - PyPy3.7 beta: which is our second release of an interpreter supporting the
    syntax and the features of Python 3.7, including the stdlib for CPython
    3.7.9. We call this beta quality software, there may be issues about
    compatibility with new and changed features in CPython 3.7.
    Please let us know what is broken or missing. We have not implemented the
    `documented changes`_ in the ``re`` module, and a few other pieces are also
    missing. For more information, see the `PyPy 3.7 wiki`_ page
    
The interpreters are based on much the same codebase, thus the multiple
release. This is a micro release, all APIs are compatible with the 7.3
releases, but read on to find out what is new.

..
  The major new feature is prelminary support for the Universal mode of HPy: a
  new way of writing c-extension modules to totally encapsulate the `PyObject*`.
  The goal, as laid out in the `HPy blog post`_, is to enable a migration path
  for c-extension authors who wish their code to be performant on alternative
  interpreters like GraalPython_ (written on top of the Java virtual machine),
  RustPython_, and PyPy. Thanks to Oracle for sponsoring work on HPy.

Several issues exposed in the 7.3.2 release were fixed. Many of them came from the
great work ongoing to ship PyPy-compatible binary packages in `conda-forge`_.
A big shout out to them for taking this on.

Development of PyPy has moved to https://foss.heptapod.net/pypy/pypy.
This was covered more extensively in this `blog post`_. We have seen an
increase in the number of drive-by contributors who are able to use gitlab +
mercurial to create merge requests.

The `CFFI`_ backend has been updated to version 1.14.3. We recommend using CFFI
rather than c-extensions to interact with C, and using cppyy_ for performant
wrapping of C++ code for Python.

A new contributor took us up on the challenge to get `windows 64-bit`_ support.
The work is proceeding on the ``win64`` branch, more help in coding or
sponsorship is welcome. In anticipation of merging this large change, we fixed
many test failures on windows.

As always, this release fixed several issues and bugs.  We strongly recommend
updating. Many of the fixes are the direct result of end-user bug reports, so
please continue reporting issues as they crop up.

You can find links to download the v7.3.3 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work.

We would also like to thank our contributors and encourage new people to join
the project. PyPy has many layers and we need help with all of them: `PyPy`_
and `RPython`_ documentation improvements, tweaking popular modules to run
on pypy, or general `help`_ with making RPython's JIT even better. Since the
previous release, we have accepted contributions from 2 new contributors,
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
.. _`conda-forge`: https://conda-forge.org/blog//2020/03/10/pypy
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
3.7. It's fast (`PyPy and CPython 3.7.4`_ performance
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

.. _`PyPy and CPython 3.7.4`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

Changelog
=========

Changes shared across versions
------------------------------
- Better support macOSx <= 10.13
- Use ``MACOSX_DEPLOYMENT_TARGET`` from environment, if set, when translating
- Update stdlib to 2.7.18
- Add limited support for ``long double`` to RPython (issue 3312_)
- Package a ``.hg_archival.txt`` in the source tarball. The file was left out
  of the source tarball after the move to heptapod (issue 3315_)
- Fix a race condition in ``crypt``
- Update expired certificates used in python testing
- Always use NT ``sysconfig`` scheme on windows (issue 3321_)
- Delay importing ``os`` and ``_codecs`` until after importing ``site``
- `bpo-35194`_: Fix a wrong constant in cp932 codec
- `bpo-34794`_: Fix a leak in Tkinter
- `bpo-33781`_: ``audioop``: enhance rounding double as int
- `bpo-31893`_: Simplify ``select.kqueue`` object comparison

C-API (cpyext) and c-extensions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- Check for ``None`` in ``PyLong_AsUnsignedLongLong``
- Dynamically allocate ``Py_buffer.format`` if needed (issue 3336_)
- Fix for readonly flag on PyObject_GetBuffer(<bytes>, view) (issue 3307_)

Python 3.6+
-----------
- Fix windows support for using ``venv`` inside a ``venv``
- Support ``os.sendfile`` on BSD derivatives (macOSx and freebsd)
- Fix ``_socket.sethostname(<bytes>)``
- Fix for modifying ``self.__dict__`` in ``self.__set_name__``, issue 3326_
- bpo-33041_: Fixed jumping if the function contains an ``async for`` loop.
- bpo-17288_: Prevent jump from a yield statement
- bpo-11471_: avoid generating a ``JUMP_FORWARD`` instruction at the end of an
  ``if``-block if there is no ``else``-clause
- Fix ``os.listdir('')`` and ``os.stat('')`` on windows (issue 3331_)
- Fix many unicode encoding/decoding errors on windows
- Fix pickling of time subclasses (issue 3324_, bpo-41966_)
- Add support for ``sqlite3_load_extension`` (issue 3334_)
- Change default file encoding from mbcs to utf-8 on windows
- Change default file encoding from ascii to utf-8 on linux
- Add ``resource.prlimit()``
- Accept PathLike in ``nt._getfullpathname`` (issue 3343_)
- Fix some problems with ``winreg``


Python 3.6 C-API
~~~~~~~~~~~~~~~~

- Export ``PyStructSequence_NewType`` (issue 3346_)

.. _3312: https://foss.heptapod.net/pypy/pypy/-/issues/3312
.. _3315: https://foss.heptapod.net/pypy/pypy/-/issues/3315
.. _3321: https://foss.heptapod.net/pypy/pypy/-/issues/3321
.. _3326: https://foss.heptapod.net/pypy/pypy/-/issues/3326
.. _3331: https://foss.heptapod.net/pypy/pypy/-/issues/3331
.. _3324: https://foss.heptapod.net/pypy/pypy/-/issues/3324
.. _3334: https://foss.heptapod.net/pypy/pypy/-/issues/3334
.. _3336: https://foss.heptapod.net/pypy/pypy/-/issues/3336
.. _3307: https://foss.heptapod.net/pypy/pypy/-/issues/3307
.. _3343: https://foss.heptapod.net/pypy/pypy/-/issues/3343
.. _3346: https://foss.heptapod.net/pypy/pypy/-/issues/3346

.. _`merge request 723`: https://foss.heptapod.net/pypy/pypy/-/merge_request/723

.. _bpo-35194: https://bugs.python.org/issue35194
.. _bpo-34794: https://bugs.python.org/issue34794
.. _bpo-33781: https://bugs.python.org/issue33781
.. _bpo-31893: https://bugs.python.org/issue31893
.. _bpo-33041: https://bugs.python.org/issue33041
.. _bpo-17288: https://bugs.python.org/issue17288
.. _bpo-11471: https://bugs.python.org/issue11471
.. _bpo-41966: https://bugs.python.org/issue41966
