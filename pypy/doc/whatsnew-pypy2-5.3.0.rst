=========================
What's new in PyPy2.7 5.3
=========================

.. this is a revision shortly after release-5.1
.. startrev: aa60332382a1

.. branch: techtonik/introductionrst-simplify-explanation-abo-1460879168046

.. branch: gcheader-decl

Reduce the size of generated C sources.


.. branch: remove-objspace-options

Remove a number of options from the build process that were never tested and
never set. Fix a performance bug in the method cache.

.. branch: bitstring

JIT: use bitstrings to compress the lists of read or written descrs
that we attach to EffectInfo.  Fixes a problem we had in
remove-objspace-options.

.. branch: cpyext-for-merge

Update cpyext C-API support After this branch, we are almost able to support 
upstream numpy via cpyext, so we created (yet another) fork of numpy at 
github.com/pypy/numpy with the needed changes. Among the significant changes 
to cpyext:

  - allow c-snippet tests to be run with -A so we can verify we are compatible
  - fix many edge cases exposed by fixing tests to run with -A
  - issequence() logic matches cpython
  - make PyStringObject and PyUnicodeObject field names compatible with cpython
  - add prelminary support for PyDateTime_*
  - support PyComplexObject, PyFloatObject, PyDict_Merge, PyDictProxy,
    PyMemoryView_*, _Py_HashDouble, PyFile_AsFile, PyFile_FromFile,
  - PyAnySet_CheckExact, PyUnicode_Concat
  - improve support for PyGILState_Ensure, PyGILState_Release, and thread
    primitives, also find a case where CPython will allow thread creation
    before PyEval_InitThreads is run, dissallow on PyPy 
  - create a PyObject-specific list strategy
  - rewrite slot assignment for typeobjects
  - improve tracking of PyObject to rpython object mapping
  - support tp_as_{number, sequence, mapping, buffer} slots

(makes the pypy-c bigger; this was fixed subsequently by the
share-cpyext-cpython-api branch)

.. branch: share-mapdict-methods-2

Reduce generated code for subclasses by using the same function objects in all
generated subclasses.

.. branch: share-cpyext-cpython-api

.. branch: cpyext-auto-gil

CPyExt tweak: instead of "GIL not held when a CPython C extension module
calls PyXxx", we now silently acquire/release the GIL.  Helps with
CPython C extension modules that call some PyXxx() functions without
holding the GIL (arguably, they are theorically buggy).

.. branch: cpyext-test-A

Get the cpyext tests to pass with "-A" (i.e. when tested directly with
CPython).

.. branch: oefmt

.. branch: cpyext-werror

Compile c snippets with -Werror in cpyext

.. branch: gc-del-3

Add rgc.FinalizerQueue, documented in pypy/doc/discussion/finalizer-order.rst.
It is a more flexible way to make RPython finalizers.

.. branch: unpacking-cpython-shortcut

.. branch: cleanups

.. branch: cpyext-more-slots

.. branch: use-gc-del-3

Use the new rgc.FinalizerQueue mechanism to clean up the handling of
``__del__`` methods.  Fixes notably issue #2287.  (All RPython
subclasses of W_Root need to use FinalizerQueue now.)

.. branch: ufunc-outer

Implement ufunc.outer on numpypy

.. branch: verbose-imports

Support ``pypy -v``: verbose imports.  It does not log as much as
cpython, but it should be enough to help when debugging package layout
problems.

.. branch: cpyext-macros-cast

Fix some warnings when compiling CPython C extension modules

.. branch: syntax_fix

.. branch: remove-raisingops

Remove most of the _ovf, _zer and _val operations from RPython.  Kills
quite some code internally, and allows the JIT to do better
optimizations: for example, app-level code like ``x / 2`` or ``x % 2``
can now be turned into ``x >> 1`` or ``x & 1``, even if x is possibly
negative.

.. branch: cpyext-old-buffers

Generalize cpyext old-style buffers to more than just str/buffer, add support for mmap

.. branch: numpy-includes

Move _numpypy headers into a directory so they are not picked up by upstream numpy, scipy
This allows building upstream numpy and scipy in pypy via cpyext

.. branch: traceviewer-common-merge-point-formats

Teach RPython JIT's off-line traceviewer the most common ``debug_merge_point`` formats.

.. branch: cpyext-pickle

Enable pickling of W_PyCFunctionObject by monkeypatching pickle.Pickler.dispatch
at cpyext import time

.. branch: nonmovable-list

Add a way to ask "give me a raw pointer to this list's
items".  Only for resizable lists of primitives.  Turns the GcArray
nonmovable, possibly making a copy of it first.

.. branch: cpyext-ext

Finish the work already partially merged in cpyext-for-merge. Adds support
for ByteArrayObject using the nonmovable-list, which also enables
buffer(bytearray(<some-list>)) 
