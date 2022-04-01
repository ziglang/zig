========================
What's new in PyPy 2.6.1
========================

.. this is a revision shortly after release-2.6.0
.. startrev: 91904d5c5188

.. branch: use_min_scalar

Correctly resolve the output dtype of ufunc(array, scalar) calls.

.. branch: stdlib-2.7.10

Update stdlib to version 2.7.10

.. branch: issue2062

.. branch: disable-unroll-for-short-loops

The JIT no longer performs loop unrolling if the loop compiles to too much code.

.. branch: run-create_cffi_imports

Build cffi import libraries as part of translation by monkey-patching an 
additional task into translation

.. branch: int-float-list-strategy

Use a compact strategy for Python lists that mix integers and floats,
at least if the integers fit inside 32 bits.  These lists are now
stored as an array of floats, like lists that contain only floats; the
difference is that integers are stored as tagged NaNs.  (This should
have no visible effect!  After ``lst = [42, 42.5]``, the value of
``lst[0]`` is still *not* the float ``42.0`` but the integer ``42``.)

.. branch: cffi-callback-onerror

Part of cffi 1.2.

.. branch: cffi-new-allocator

Part of cffi 1.2.

.. branch: unicode-dtype

Partial implementation of unicode dtype and unicode scalars.

.. branch: dtypes-compatability

Improve compatibility with numpy dtypes; handle offsets to create unions,
fix str() and repr(), allow specifying itemsize, metadata and titles, add flags,
allow subclassing dtype

.. branch: indexing

Refactor array indexing to support ellipses.

.. branch: numpy-docstrings

Allow the docstrings of built-in numpy objects to be set at run-time.

.. branch: nditer-revisited

Implement nditer 'buffered' flag and fix some edge cases

.. branch: ufunc-reduce

Allow multiple axes in ufunc.reduce()

.. branch: fix-tinylang-goals

Update tinylang goals to match current rpython

.. branch: vmprof-review

Clean up of vmprof, notably to handle correctly multiple threads

.. branch: no_boehm_dl

Remove extra link library from Boehm GC
