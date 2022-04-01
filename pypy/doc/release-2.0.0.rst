============================
PyPy 2.0 - Einstein Sandwich
============================

We're pleased to announce PyPy 2.0. This is a stable release that brings
a swath of bugfixes, small performance improvements and compatibility fixes.
PyPy 2.0 is a big step for us and we hope in the future we'll be able to
provide stable releases more often.

You can download the PyPy 2.0 release here:

    https://pypy.org/download.html

The two biggest changes since PyPy 1.9 are:

* stackless is now supported including greenlets, which means eventlet
  and gevent should work (but read below about gevent)

* PyPy now contains release 0.6 of `cffi`_ as a builtin module, which
  is preferred way of calling C from Python that works well on PyPy

.. _`cffi`: https://cffi.readthedocs.org

If you're using PyPy for anything, it would help us immensely if you fill out
the following survey: https://bit.ly/pypysurvey This is for the developers
eyes and we will not make any information public without your agreement.

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy 2.0 and cpython 2.7.3`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64 or
Windows 32.  Windows 64 work is still stalling, we would welcome a volunteer
to handle that. ARM support is on the way, as you can see from the recently
released alpha for ARM.

.. _`pypy 2.0 and cpython 2.7.3`: https://speed.pypy.org

Highlights
==========

* Stackless including greenlets should work. For gevent, you need to check
  out `pypycore`_ and use the `pypy-hacks`_ branch of gevent.

* cffi is now a module included with PyPy.  (`cffi`_ also exists for
  CPython; the two versions should be fully compatible.)  It is the
  preferred way of calling C from Python that works on PyPy.

* Callbacks from C are now JITted, which means XML parsing is much faster.

* A lot of speed improvements in various language corners, most of them small,
  but speeding up some particular corners a lot.

* The JIT was refactored to emit machine code which manipulates a "frame"
  that lives on the heap rather than on the stack.  This is what makes
  Stackless work, and it could bring another future speed-up (not done yet).

* A lot of stability issues fixed.

* Refactoring much of the numpypy array classes, which resulted in removal of
  lazy expression evaluation. On the other hand, we now have more complete
  dtype support and support more array attributes.  

.. _`pypycore`: https://github.com/gevent-on-pypy/pypycore/
.. _`pypy-hacks`: https://github.com/schmir/gevent/tree/pypy-hacks

Cheers,
fijal, arigo and the PyPy team
