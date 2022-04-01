===============
PyPy 2.0 beta 1
===============

We're pleased to announce the 2.0 beta 1 release of PyPy. This release is
not a typical beta, in a sense the stability is the same or better than 1.9
and can be used in production. It does however include a few performance
regressions documented below that don't allow us to label is as 2.0 final.
(It also contains many performance improvements.)

The main features of this release are support for ARM processor and
compatibility with CFFI. It also includes
numerous improvements to the numpy in pypy effort, cpyext and performance.

You can download the PyPy 2.0 beta 1 release here:

    https://pypy.org/download.html 

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7.3. It's fast (`pypy 2.0 beta 1 and cpython 2.7.3`_
performance comparison) due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64 or
Windows 32. It also supports ARM machines running Linux.
Windows 64 work is still stalling, we would welcome a volunteer
to handle that.

.. _`pypy 2.0 beta 1 and cpython 2.7.3`: https://bit.ly/USXqpP

How to use PyPy?
================

We suggest using PyPy from a `virtualenv`_. Once you have a virtualenv
installed, you can follow instructions from `pypy documentation`_ on how
to proceed. This document also covers other `installation schemes`_.

.. _`pypy documentation`: https://doc.pypy.org/en/latest/getting-started.html#installing-using-virtualenv
.. _`virtualenv`: https://www.virtualenv.org/en/latest/
.. _`installation schemes`: https://doc.pypy.org/en/latest/getting-started.html#installing-pypy
.. _`PyPy and pip`: https://doc.pypy.org/en/latest/getting-started.html#installing-pypy

Regressions
===========

Reasons why this is not PyPy 2.0:

* the ``ctypes`` fast path is now slower than it used to be. In PyPy
  1.9 ``ctypes`` was either incredibly faster or slower than CPython depending whether
  you hit the fast path or not. Right now it's usually simply slower. We're
  probably going to rewrite ``ctypes`` using ``cffi``, which will make it
  universally faster.

* ``cffi`` (an alternative to interfacing with C code) is very fast, but
  it is missing one optimization that will make it as fast as a native
  call from C.

* ``numpypy`` lazy computation was disabled for the sake of simplicity.
  We should reenable this for the final 2.0 release.

Highlights
==========

* ``cffi`` is officially supported by PyPy. You can install it normally by
  using ``pip install cffi`` once you have installed `PyPy and pip`_.
  The corresponding ``0.4`` version of ``cffi`` has been released.

* ARM is now an officially supported processor architecture.
  PyPy now work on soft-float ARM/Linux builds.  Currently ARM processors
  supporting the ARMv7 and later ISA that include a floating-point unit are
  supported.

* This release contains the latest Python standard library 2.7.3 and is fully
  compatible with Python 2.7.3.

* It does not however contain hash randomization, since the solution present
  in CPython is not solving the problem anyway. The reason can be
  found on the `CPython issue tracker`_.

* ``gc.get_referrers()`` is now faster.

* Various numpy improvements. The list includes:

  * axis argument support in many places

  * full support for fancy indexing

  * ``complex128`` and ``complex64`` dtypes

* `JIT hooks`_ are now a powerful tool to introspect the JITting process that
  PyPy performs.

* ``**kwds`` usage is much faster in the typical scenario

* operations on ``long`` objects are now as fast as in CPython (from
  roughly 2x slower)

* We now have special strategies for ``dict``/``set``/``list`` which contain
  unicode strings, which means that now such collections will be both faster
  and more compact.

.. _`cpython issue tracker`: https://bugs.python.org/issue14621
.. _`jit hooks`: https://doc.pypy.org/en/latest/jit-hooks.html

Things we're working on
=======================

There are a few things that did not make it to the 2.0 beta 1, which
are being actively worked on. Greenlets support in the JIT is one
that we would like to have before 2.0 final. Two important items that
will not make it to 2.0, but are being actively worked on, are:

* Faster JIT warmup time.

* Software Transactional Memory.

Cheers,
Maciej Fijalkowski, Armin Rigo and the PyPy team
