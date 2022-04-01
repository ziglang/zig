==========================
What's new in PyPy2.7 7.0+
==========================

.. this is a revision shortly after release-pypy-7.0.0
.. startrev: 481c69f7d81f

.. branch: zlib-copying-third-time-a-charm

Make sure zlib decompressobjs have their streams deallocated immediately
on flush.

.. branch: zlib-copying-redux

Fix calling copy on already-flushed compressobjs.



.. branch: math-improvements

Improve performance of long operations where one of the operands fits into
an int.

.. branch: regalloc-playground

Improve register allocation in the JIT.

.. branch: promote-unicode

Implement rlib.jit.promote_unicode to complement promote_string

.. branch: unicode-utf8

Use utf8 internally to represent unicode, with the goal of never using rpython-level unicode

.. branch: newmemoryview-app-level

Since _ctypes is implemented in pure python over libffi, add interfaces and
methods to support the buffer interface from python. Specifically, add a
``__pypy__.newmemoryview`` function to create a memoryview and extend the use
of the PyPy-specific ``__buffer__`` class method.