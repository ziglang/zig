===================================
PyPy v7.3.5: release of 2.7 and 3.7
===================================

We are releasing a PyPy 7.3.5 with bugfixes for PyPy 7.3.4, released April 4.
PyPy 7.3.4 was the first release that runs on windows 64-bit, so that support
is still "beta". We are releasing it in the hopes that we can garner momentum
for its continued support, but are already aware of some problems, for instance
it errors in the NumPy test suite (issue 3462_). Please help out with testing
the releae and reporting successes and failures, financially supporting our
ongoing work, and helping us find the source of these problems.

- The new windows 64-bit builds improperly named c-extension modules
  with the same extension as the 32-bit build (issue 3443_)
- Use the windows-specific ``PC/pyconfig.h`` rather than the posix one
- Fix the return type for ``_Py_HashDouble`` which impacts 64-bit windows
- A change to the python 3.7 ``sysconfig.get_config_var('LIBDIR')`` was wrong,
  leading to problems finding `libpypy3-c.so` for embedded PyPy (issue 3442_).
- Instantiate ``distutils.command.install`` schema for PyPy-specific
  ``implementation_lower``
- Delay thread-checking logic in greenlets until the thread is actually started
  (continuation of issue 3441_)
- Four upstream (CPython) security patches were applied:

  - `BPO 42988`_ to remove ``pydoc.getfile`` 
  - `BPO 43285`_ to not trust the ``PASV`` response in ``ftplib``.
  - `BPO 43075`_ to remove a possible ReDoS in urllib AbstractBasicAuthHandler
  - `BPO 43882`_ to sanitize urls containing ASCII newline and tabs in
    ``urllib.parse``

- Fix for json-specialized dicts (issue 3460_)
- Specialize ``ByteBuffer.setslice`` which speeds up binary file reading by a
  factor of 3
- When assigning the full slice of a list, evaluate the rhs before clearing the
  list (issue 3440_)
- On Python2, ``PyUnicode_Contains`` accepts bytes as well as unicode.
- Finish fixing ``_sqlite3`` - untested ``_reset()`` was missing an argument
  (issue 3432_)
- Update the packaged sqlite3 to 3.35.5 on windows. While not a bugfix, this
  seems like an easy win.

We recommend updating. These fixes are the direct result of end-user bug
reports, so please continue reporting issues as they crop up.

You can find links to download the v7.3.5 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work. If PyPy is helping you out, we would love to hear about
it and encourage submissions to our `renovated blog site`_ via a pull request
to https://github.com/pypy/pypy.org

We would also like to thank our contributors and encourage new people to join
the project. PyPy has many layers and we need help with all of them: `PyPy`_
and `RPython`_ documentation improvements, tweaking popular modules to run
on PyPy, or general `help`_ with making RPython's JIT even better. 

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
.. _`renovated blog site`: https://pypy.org/blog


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

.. _3443: https://foss.heptapod.net/pypy/pypy/-/issues/3443
.. _3442: https://foss.heptapod.net/pypy/pypy/-/issues/3442
.. _3441: https://foss.heptapod.net/pypy/pypy/-/issues/3441
.. _3440: https://foss.heptapod.net/pypy/pypy/-/issues/3440
.. _3460: https://foss.heptapod.net/pypy/pypy/-/issues/3460
.. _3462: https://foss.heptapod.net/pypy/pypy/-/issues/3462
.. _3432: https://foss.heptapod.net/pypy/pypy/-/issues/3432
.. _`BPO 42988`: https://bugs.python.org/issue42988
.. _`BPO 43285`: https://bugs.python.org/issue43285
.. _`BPO 43075`: https://bugs.python.org/issue43075
.. _`BPO 43882`: https://bugs.python.org/issue43882

