=======================================
PyPy 2.2 - Incrementalism
=======================================

We're pleased to announce PyPy 2.2, which targets version 2.7.3 of the Python
language. This release main highlight is the introduction of the incremental
garbage collector, sponsored by the `Raspberry Pi Foundation`_.

This release also contains several bugfixes and performance improvements. 

You can download the PyPy 2.2 release here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project. We showed quite a bit of progress on all three projects (see below)
and we're slowly running out of funds.
Please consider donating more so we can finish those projects!  The three
projects are:

* Py3k (supporting Python 3.x): the release PyPy3 2.2 is imminent.

* STM (software transactional memory): a preview will be released very soon,
  as soon as we fix a few bugs

* NumPy: the work done is included in the PyPy 2.2 release. More details below.

.. _`Raspberry Pi Foundation`: https://www.raspberrypi.org

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy 2.2 and cpython 2.7.2`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64, Windows
32, or ARM (ARMv6 or ARMv7, with VFPv3).

Work on the native Windows 64 is still stalling, we would welcome a volunteer
to handle that.

.. _`pypy 2.2 and cpython 2.7.2`: https://speed.pypy.org

Highlights
==========

* Our Garbage Collector is now "incremental".  It should avoid almost
  all pauses due to a major collection taking place.  Previously, it
  would pause the program (rarely) to walk all live objects, which
  could take arbitrarily long if your process is using a whole lot of
  RAM.  Now the same work is done in steps.  This should make PyPy
  more responsive, e.g. in games.  There are still other pauses, from
  the GC and the JIT, but they should be on the order of 5
  milliseconds each.

* The JIT counters for hot code were never reset, which meant that a
  process running for long enough would eventually JIT-compile more
  and more rarely executed code.  Not only is it useless to compile
  such code, but as more compiled code means more memory used, this
  gives the impression of a memory leak.  This has been tentatively
  fixed by decreasing the counters from time to time.

* NumPy has been split: now PyPy only contains the core module, called
  ``_numpypy``.  The ``numpy`` module itself has been moved to
  ``https://bitbucket.org/pypy/numpy`` and ``numpypy`` disappeared.
  You need to install NumPy separately with a virtualenv:
  ``pip install git+https://bitbucket.org/pypy/numpy.git``;
  or directly:
  ``git clone https://bitbucket.org/pypy/numpy.git``;
  ``cd numpy``; ``pypy setup.py install``.

* non-inlined calls have less overhead

* Things that use ``sys.set_trace`` are now JITted (like coverage)

* JSON decoding is now very fast (JSON encoding was already very fast)

* various buffer copying methods experience speedups (like list-of-ints to
  ``int[]`` buffer from cffi)

* We finally wrote (hopefully) all the missing ``os.xxx()`` functions,
  including ``os.startfile()`` on Windows and a handful of rare ones
  on Posix.

* numpy has a rudimentary C API that cooperates with ``cpyext``

Cheers,
Armin Rigo and Maciej Fijalkowski
