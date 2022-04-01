========================
What's new in PyPy 4.0.0
========================

.. this is a revision shortly after release-2.6.1
.. startrev: 3a8f5481dab4

.. branch: keys_with_hash

Improve the performance of ``dict.update()`` and a bunch of methods from
sets, by reusing the hash value stored in one dict when inspecting
or changing another dict with that key.

.. branch: optresult-unroll 

A major refactoring of the ``ResOperations`` that kills Box. Also rewrote
unrolling to enable future enhancements.  Should improve warmup time
by 20% or so.

.. branch: optimize-cond-call

Optimize common sequences of operations like
``int_lt/cond_call`` in the JIT backends

.. branch: missing_openssl_include

Fix for missing headers in OpenBSD, already applied in downstream ports

.. branch: gc-more-incremental

Remove a source of non-incremental-ness in the GC: now
``external_malloc()`` no longer runs ``gc_step_until()`` any more. If there
is a currently-running major collection, we do only so many steps
before returning. This number of steps depends on the size of the
allocated object. It is controlled by tracking the general progress
of these major collection steps and the size of old objects that
keep adding up between them.

.. branch: remember-tracing-counts

Reenable jithooks

.. branch: detect_egd2

.. branch: shadowstack-no-move-2

Issue #2141: fix a crash on Windows and OS/X and ARM when running
at least 20 threads.

.. branch: numpy-ctypes

Add support for ndarray.ctypes property.

.. branch: share-guard-info

Share guard resume data between consecutive guards that have only
pure operations and guards in between.

.. branch: issue-2148

Fix performance regression on operations mixing numpy scalars and Python 
floats, cf. issue #2148.

.. branch: cffi-stdcall

Win32: support ``__stdcall`` in CFFI.

.. branch: callfamily

Refactorings of annotation and rtyping of function calls.

.. branch: fortran-order

Allow creation of fortran-ordered ndarrays

.. branch: type_system-cleanup

Remove some remnants of the old ``ootypesystem`` vs ``lltypesystem`` dichotomy.

.. branch: cffi-handle-lifetime

``ffi.new_handle()`` returns handles that work more like CPython's: they
remain valid as long as the target exists (unlike the previous
version, where handles become invalid *before* the ``__del__`` is called).

.. branch: ufunc-casting

allow automatic casting in ufuncs (and ``frompypyfunc``) to cast the
arguments to the allowed function type declarations, fixes various
failures in linalg CFFI functions

.. branch: vecopt
.. branch: vecopt-merge

A new optimization pass to use emit vectorized loops

.. branch: ppc-updated-backend

The PowerPC JIT backend is merged.

.. branch: osx-libffi

.. branch: lazy-fast2locals

Improve the performance of simple trace functions by lazily calling
``fast2locals`` and ``locals2fast`` only if ``f_locals`` is actually accessed.

