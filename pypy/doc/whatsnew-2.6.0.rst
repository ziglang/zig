========================
What's new in PyPy 2.6.0
========================

.. this is a revision shortly after release-2.5.1
.. startrev: cb01edcb59414d9d93056e54ed060673d24e67c1

issue2005:
ignore errors on closing random file handles while importing a module (cpython compatibility)

issue2013:
added constants to _ssl for TLS 1.1 and 1.2

issue2014:
Add PyLong_FromUnicode to cpyext.

issue2017: 
On non-Linux-x86 platforms, reduced the memory impact of
creating a lot of greenlets/tasklets.  Particularly useful on Win32 and
on ARM, where you used to get a MemoryError after only 2500-5000
greenlets (the 32-bit address space is exhausted).

Update gdb_pypy for python3 (gdb comatability)

Merged rstrategies into rpython which provides a library for Storage Strategies

Support unicode strings in numpy.dtype creation i.e. np.dtype(u'int64')

Various rpython cleanups for vmprof support

issue2019:
Fix isspace as called by rpython unicode.strip()

issue2023:
In the cpyext 'Concrete Object Layer' API,
don't call methods on the object (which can be overriden),
but directly on the concrete base type.

issue2029:
Hide the default_factory attribute in a dict

issue2027:
Better document pyinteractive and add --withmod-time

.. branch: gc-incminimark-pinning-improve

branch gc-incminimark-pinning-improve: 
Object Pinning is now used in `bz2` and `rzlib` (therefore also affects
Python's `zlib`). In case the data to compress/decompress is inside the nursery
(incminimark) it no longer needs to create a non-moving copy of it. This saves
one `malloc` and copying the data.  Additionally a new GC environment variable
is introduced (`PYPY_GC_MAX_PINNED`) primarily for debugging purposes.

.. branch: refactor-pycall

branch refactor-pycall:
Make `*`-unpacking in RPython function calls completely equivalent to passing
the tuple's elements as arguments. In other words, `f(*(a, b))` now behaves 
exactly like `f(a, b)`.

.. branch: issue2018

branch issue2018:
Allow prebuilt rpython dict with function values

.. branch: vmprof
.. Merged but then backed out, hopefully it will return as vmprof2

.. branch: object-dtype2

branch object-dtype2:
Extend numpy dtypes to allow using objects with associated garbage collection hook

.. branch: vmprof2

branch vmprof2:
Add backend support for vmprof - a lightweight statistical profiler -
to linux64, see client at https://vmprof.readthedocs.org

.. branch: jit_hint_docs

branch jit_hint_docs:
Add more detail to @jit.elidable and @jit.promote in rpython/rlib/jit.py

.. branch: remove-frame-debug-attrs

branch remove_frame-debug-attrs:
Remove the debug attributes from frames only used for tracing and replace
them with a debug object that is created on-demand

.. branch: can_cast

branch can_cast:
Implement np.can_cast, np.min_scalar_type and missing dtype comparison operations.

.. branch: numpy-fixes

branch numpy-fixes:
Fix some error related to object dtype, non-contiguous arrays, inplement parts of 
__array_interface__, __array_priority__, __array_wrap__

.. branch: cells-local-stack

branch cells-local-stack:
Unify the PyFrame.cells and Pyframe.locals_stack_w lists, making frame objects
1 or 3 words smaller.

.. branch: pythonoptimize-env

branch pythonoptimize-env
Implement PYTHONOPTIMIZE environment variable, fixing issue #2044

.. branch: numpy-flags

branch numpy-flags
Finish implementation of ndarray.flags, including str() and repr()

.. branch: cffi-1.0

branch cffi-1.0
PyPy now includes CFFI 1.0.

.. branch: pypyw

branch pypyw
PyPy on windows provides a non-console pypyw.exe as well as pypy.exe.
Similar to pythonw.exe, any use of stdout, stderr without redirection
will crash.

.. branch: fold-arith-ops

branch fold-arith-ops
remove multiple adds on add chains ("1 + 1 + 1 + ...")

.. branch: fix-result-types

branch fix-result-types:
* Refactor dtype casting and promotion rules for consistency and compatibility
with CNumPy.
* Refactor ufunc creation.
* Implement np.promote_types().
