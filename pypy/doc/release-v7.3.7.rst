========================================
PyPy v7.3.7: bug-fix release of 3.7, 3.8
========================================

We are releasing a PyPy 7.3.7 to fix the recent 7.3.6 release's binary
incompatibility with the previous 7.3.x releases. We mistakenly added fields
to ``PyFrameObject`` and ``PyDateTime_CAPI`` that broke the promise of binary
compatibility, which means that c-extension wheels compiled for 7.3.5 will not
work with 7.3.6 and via-versa. Please do not use 7.3.6.

We have added a cursory test for binary API breakage to the
https://github.com/pypy/binary-testing repo which hopefully will prevent such
mistakes in the future.

Additionally, a few smaller bugs were fixed:

- Use ``uint`` for the ``request`` argument of ``fcntl.ioctl`` (issue 3568_)
- Fix incorrect tracing of `while True`` body in 3.8 (issue 3577_)
- Properly close resources when using a ``conncurrent.futures.ProcessPool``
  (issue 3317_)
- Fix the value of ``LIBDIR`` in ``_sysconfigdata`` in 3.8 (issue 3582_)


You can find links to download the v7.3.7 releases here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. If PyPy is not quite good enough for your needs, we are available for
direct consulting work. If PyPy is helping you out, we would love to hear about
it and encourage submissions to our `blog site`_ via a pull request
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
.. _`blog site`: https://pypy.org/blog


What is PyPy?
=============

PyPy is a Python interpreter, a drop-in replacement for CPython 2.7, 3.7, and
3.8. It's fast (`PyPy and CPython 3.7.4`_ performance
comparison) due to its integrated tracing JIT compiler.

We also welcome developers of other `dynamic languages`_ to see what RPython
can do for them.

This PyPy release supports:

  * **x86** machines on most common operating systems
    (Linux 32/64 bits, Mac OS X 64 bits, Windows 64 bits, OpenBSD, FreeBSD)

  * 64-bit **ARM** machines running Linux.

  * **s390x** running Linux

PyPy does support ARM 32 bit and PPC64 processors, but does not release binaries.

.. _`PyPy and CPython 3.7.4`: https://speed.pypy.org
.. _`dynamic languages`: https://rpython.readthedocs.io/en/latest/examples.html

.. _3568: https://foss.heptapod.net/pypy/pypy/-/issues/3568
.. _3577: https://foss.heptapod.net/pypy/pypy/-/issues/3577
.. _3317: https://foss.heptapod.net/pypy/pypy/-/issues/3317
.. _3582: https://foss.heptapod.net/pypy/pypy/-/issues/3582

