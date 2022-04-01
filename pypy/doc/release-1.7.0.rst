==================================
PyPy 1.7 - widening the sweet spot
==================================

We're pleased to announce the 1.7 release of PyPy. As became a habit, this
release brings a lot of bugfixes and performance improvements over the 1.6
release. However, unlike the previous releases, the focus has been on widening
the "sweet spot" of PyPy. That is, classes of Python code that PyPy can greatly
speed up should be vastly improved with this release. You can download the 1.7
release here:

    https://pypy.org/download.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy 1.7 and cpython 2.7.1`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 32/64 or
Windows 32. Windows 64 work is ongoing, but not yet natively supported.

The main topic of this release is widening the range of code which PyPy
can greatly speed up. On average on
our benchmark suite, PyPy 1.7 is around **30%** faster than PyPy 1.6 and up
to **20 times** faster on some benchmarks.

.. _`pypy 1.7 and cpython 2.7.1`: https://speed.pypy.org


Highlights
==========

* Numerous performance improvements. There are too many examples which python
  constructs now should behave faster to list them.

* Bugfixes and compatibility fixes with CPython.

* Windows fixes.

* PyPy now comes with stackless features enabled by default. However,
  any loop using stackless features will interrupt the JIT for now, so no real
  performance improvement for stackless-based programs. Contact pypy-dev for
  info how to help on removing this restriction.

* NumPy effort in PyPy was renamed numpypy. In order to try using it, simply
  write::

    import numpypy as numpy

  at the beginning of your program. There is a huge progress on numpy in PyPy
  since 1.6, the main feature being implementation of dtypes.

* JSON encoder (but not decoder) has been replaced with a new one. This one
  is written in pure Python, but is known to outperform CPython's C extension
  up to **2 times** in some cases. It's about **20 times** faster than
  the one that we had in 1.6.

* The memory footprint of some of our RPython modules has been drastically
  improved. This should impact any applications using for example cryptography,
  like tornado.

* There was some progress in exposing even more CPython C API via cpyext.

Things that didn't make it, expect in 1.8 soon
==============================================

There is an ongoing work, which while didn't make it to the release, is
probably worth mentioning here. This is what you should probably expect in
1.8 some time soon:

* Specialized list implementation. There is a branch that implements lists of
  integers/floats/strings as compactly as array.array. This should drastically
  improve performance/memory impact of some applications

* NumPy effort is progressing forward, with multi-dimensional arrays coming
  soon.

* There are two brand new JIT assembler backends, notably for the PowerPC and
  ARM processors.

Fundraising
===========

It's maybe worth mentioning that we're running fundraising campaigns for
NumPy effort in PyPy and for Python 3 in PyPy. In case you want to see any
of those happen faster, we urge you to donate to `numpy proposal`_ or
`py3k proposal`_. In case you want PyPy to progress, but you trust us with
the general direction, you can always donate to the `general pot`_.

.. _`numpy proposal`: https://pypy.org/numpydonate.html
.. _`py3k proposal`: https://pypy.org/py3donate.html
.. _`general pot`: https://pypy.org
