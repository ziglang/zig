===============
PyPy 2.0 beta 2
===============

We're pleased to announce the 2.0 beta 2 release of PyPy. This is a major
release of PyPy and we're getting very close to 2.0 final, however it includes
quite a few new features that require further testing. Please test and report
issues, so we can have a rock-solid 2.0 final. It also includes a performance
regression of about 5% compared to 2.0 beta 1 that we hope to fix before
2.0 final. The ARM support is not working yet and we're working hard to
make it happen before the 2.0 final. The new major features are:

* JIT now supports stackless features, that is greenlets and stacklets. This
  means that JIT can now optimize the code that switches the context. It enables
  running `eventlet`_ and `gevent`_ on PyPy (although gevent requires some
  special support that's not quite finished, read below).

* This is the first PyPy release that includes `cffi`_ as a core library.
  Version 0.6 comes included in the PyPy library. cffi has seen a lot of
  adoption among library authors and we believe it's the best way to wrap
  C libaries. You can see examples of cffi usage in `_curses.py`_ and
  `_sqlite3.py`_ in the PyPy source code.

You can download the PyPy 2.0 beta 2 release here:

    https://pypy.org/download.html 

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7.3. It's fast (`pypy 2.0 beta 2 and cpython 2.7.3`_
performance comparison) due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64 or
Windows 32. It also supports ARM machines running Linux, however this is
disabled for the beta 2 release.
Windows 64 work is still stalling, we would welcome a volunteer
to handle that.

.. _`pypy 2.0 beta 2 and cpython 2.7.3`: https://bit.ly/USXqpP

How to use PyPy?
================

We suggest using PyPy from a `virtualenv`_. Once you have a virtualenv
installed, you can follow instructions from `pypy documentation`_ on how
to proceed. This document also covers other `installation schemes`_.

.. _`pypy documentation`: https://doc.pypy.org/en/latest/getting-started.html#installing-using-virtualenv
.. _`virtualenv`: https://www.virtualenv.org/en/latest/
.. _`installation schemes`: https://doc.pypy.org/en/latest/getting-started.html#installing-pypy

Highlights
==========

* ``cffi`` is officially supported by PyPy. It comes included in the standard
  library, just use ``import cffi``

* stackless support - `eventlet`_ just works and `gevent`_ requires `pypycore`_
  and `pypy-hacks`_ branch of gevent (which mostly disables cython-based
  modules)

* callbacks from C are now much faster. pyexpat is about 3x faster, cffi
  callbacks around the same

* ``__length_hint__`` is implemented (PEP 424)

* a lot of numpy improvements

Improvements since 1.9
======================

* `JIT hooks`_ are now a powerful tool to introspect the JITting process that
  PyPy performs

* various performance improvements compared to 1.9 and 2.0 beta 1

* operations on ``long`` objects are now as fast as in CPython (from
  roughly 2x slower)

* we now have special strategies for ``dict``/``set``/``list`` which contain
  unicode strings, which means that now such collections will be both faster
  and more compact.

.. _`eventlet`: https://eventlet.net/
.. _`gevent`: https://www.gevent.org/
.. _`cffi`: https://cffi.readthedocs.org/en/release-0.6/
.. _`JIT hooks`: https://doc.pypy.org/en/latest/jit-hooks.html
.. _`pypycore`: https://github.com/gevent-on-pypy/pypycore
.. _`pypy-hacks`: https://github.com/schmir/gevent/tree/pypy-hacks
.. _`_curses.py`: https://bitbucket.org/pypy/pypy/src/aefddd47f224e3c12e2ea74f5c796d76f4355bdb/lib_pypy/_curses.py?at=default
.. _`_sqlite3.py`: https://bitbucket.org/pypy/pypy/src/aefddd47f224e3c12e2ea74f5c796d76f4355bdb/lib_pypy/_sqlite3.py?at=default

