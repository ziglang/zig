======================
What's new in PyPy 1.9
======================

.. this is the revision just after the creation of the release-1.8.x branch
.. startrev: a4261375b359

.. branch: default

Working hash function for numpy types.

.. branch: array_equal

.. branch: better-jit-hooks-2

Improved jit hooks

.. branch: faster-heapcache

.. branch: faster-str-decode-escape

.. branch: float-bytes

Added some primitives for dealing with floats as raw bytes.

.. branch: float-bytes-2

Added more float byte primitives.

.. branch: jit-frame-counter

Put more debug info into resops.

.. branch: kill-geninterp

Kill "geninterp", an old attempt to statically turn some fixed
app-level code to interp-level.

.. branch: kqueue

Finished select.kqueue.

.. branch: kwargsdict-strategy

Special dictionary strategy for dealing with \*\*kwds. Now having a simple
proxy ``def f(*args, **kwds): return x(*args, **kwds)`` should not make
any allocations at all.

.. branch: matrixmath-dot

numpypy can now handle matrix multiplication.

.. branch: merge-2.7.2

The stdlib was updated to version 2.7.2

.. branch: ndmin

.. branch: newindex

.. branch: non-null-threadstate

cpyext: Better support for PyEval_SaveThread and other PyTreadState_*
functions.

.. branch: numppy-flatitter

flatitier for numpy

.. branch: numpy-back-to-applevel

reuse more of original numpy

.. branch: numpy-concatenate

concatenation support for numpy

.. branch: numpy-indexing-by-arrays-bool

indexing by bool arrays

.. branch: numpy-record-dtypes

record dtypes on numpy has been started

.. branch: numpy-single-jitdriver

.. branch: numpy-ufuncs2

.. branch: numpy-ufuncs3

various refactorings regarding numpy

.. branch: numpypy-issue1137

.. branch: numpypy-out

The "out" argument was added to most of the numypypy functions.

.. branch: numpypy-shape-bug

.. branch: numpypy-ufuncs

.. branch: pytest

.. branch: safe-getargs-freelist

CPyext improvements. For example PyOpenSSL should now work

.. branch: set-strategies

Sets now have strategies just like dictionaries. This means a set
containing only ints will be more compact (and faster)

.. branch: speedup-list-comprehension

The simplest case of list comprehension is preallocating the correct size
of the list. This speeds up select benchmarks quite significantly.

.. branch: stdlib-unification

The directory "lib-python/modified-2.7" has been removed, and its
content merged into "lib-python/2.7".

.. branch: step-one-xrange

The common case of a xrange iterator with no step argument specifed
was somewhat optimized. The tightest loop involving it,
sum(xrange(n)), is now 18% faster on average.

.. branch: string-NUL

PyPy refuses filenames with chr(0) characters. This is implemented in
RPython which can enforce no-NUL correctness and propagation, similar
to const-correctness in C++.

.. branch: win32-cleanup
.. branch: win32-cleanup2
.. branch: win32-cleanup_2

Many bugs were corrected for windows 32 bit. New functionality was added to
test validity of file descriptors, leading to the removal of the global
_invalid_parameter_handler

.. branch: win32-kill

Add os.kill to windows even if translating python does not have os.kill

.. branch: win_ffi

Handle calling conventions for the _ffi and ctypes modules

.. branch: win64-stage1

.. branch: zlib-mem-pressure

Memory "leaks" associated with zlib are fixed.

.. branch: ffistruct

The ``ffistruct`` branch adds a very low level way to express C structures
with _ffi in a very JIT-friendly way


.. "uninteresting" branches that we should just ignore for the whatsnew:

.. branch: exception-cannot-occur

.. branch: sanitize-finally-stack

.. branch: revive-dlltool

(preliminary work for sepcomp)
