======================
What's new in PyPy 5.0
======================

.. this is a revision shortly after release-4.0.1
.. startrev: 4b5c840d0da2

Fixed ``_PyLong_FromByteArray()``, which was buggy.

Fixed a crash with stacklets (or greenlets) on non-Linux machines
which showed up if you forget stacklets without resuming them.

.. branch: numpy-1.10

Fix tests to run cleanly with -A and start to fix micronumpy for upstream numpy
which is now 1.10.2

.. branch: osx-flat-namespace

Fix the cpyext tests on OSX by linking with -flat_namespace

.. branch: anntype

Refactor and improve exception analysis in the annotator.

.. branch: posita/2193-datetime-timedelta-integrals

Fix issue #2193. ``isinstance(..., int)`` => ``isinstance(..., numbers.Integral)`` 
to allow for alternate ``int``-like implementations (e.g., ``future.types.newint``)

.. branch: faster-rstruct

Improve the performace of struct.unpack, which now directly reads inside the
string buffer and directly casts the bytes to the appropriate type, when
allowed. Unpacking of floats and doubles is about 15 times faster now, while
for integer types it's up to ~50% faster for 64bit integers.

.. branch: wrap-specialisation

Remove unnecessary special handling of space.wrap().

.. branch: compress-numbering

Improve the memory signature of numbering instances in the JIT. This should massively
decrease the amount of memory consumed by the JIT, which is significant for most programs.

.. branch: fix-trace-too-long-heuristic

Improve the heuristic when disable trace-too-long

.. branch: fix-setslice-can-resize

Make rlist's ll_listsetslice() able to resize the target list to help
simplify objspace/std/listobject.py. Was issue #2196.

.. branch: anntype2

A somewhat random bunch of changes and fixes following up on branch 'anntype'. Highlights:

- Implement @doubledispatch decorator and use it for intersection() and difference().

- Turn isinstance into a SpaceOperation

- Create a few direct tests of the fundamental annotation invariant in test_model.py

- Remove bookkeeper attribute from DictDef and ListDef.

.. branch: cffi-static-callback

.. branch: vecopt-absvalue

- Enhancement. Removed vector fields from AbstractValue.

.. branch: memop-simplify2

Simplification. Backends implement too many loading instructions, only having a slightly different interface.
Four new operations (gc_load/gc_load_indexed, gc_store/gc_store_indexed) replace all the
commonly known loading operations

.. branch: more-rposix

Move wrappers for OS functions from `rpython/rtyper` to `rpython/rlib` and 
turn them into regular RPython functions. Most RPython-compatible `os.*` 
functions are now directly accessible as `rpython.rposix.*`.

.. branch: always-enable-gil

Simplify a bit the GIL handling in non-jitted code.  Fixes issue #2205.

.. branch: flowspace-cleanups

Trivial cleanups in flowspace.operation : fix comment & duplicated method

.. branch: test-AF_NETLINK

Add a test for pre-existing AF_NETLINK support. Was part of issue #1942.

.. branch: small-cleanups-misc

Trivial misc cleanups: typo, whitespace, obsolete comments

.. branch: cpyext-slotdefs
.. branch: fix-missing-canraise
.. branch: whatsnew

.. branch: fix-2211

Fix the cryptic exception message when attempting to use extended slicing
in rpython. Was issue #2211.

.. branch: ec-keepalive

Optimize the case where, in a new C-created thread, we keep invoking
short-running Python callbacks.  (CFFI on CPython has a hack to achieve
the same result.)  This can also be seen as a bug fix: previously,
thread-local objects would be reset between two such calls.

.. branch: globals-quasiimmut

Optimize global lookups.

.. branch: cffi-static-callback-embedding

Updated to CFFI 1.5, which supports a new way to do embedding.
Deprecates https://pypy.readthedocs.org/en/latest/embedding.html.

.. branch: fix-cpython-ssl-tests-2.7

Fix SSL tests by importing cpython's patch


.. branch: remove-getfield-pure

Remove pure variants of ``getfield_gc_*`` operations from the JIT. Relevant
optimizations instead consult the field descriptor to determine the purity of
the operation. Additionally, pure ``getfield`` operations are now handled
entirely by `rpython/jit/metainterp/optimizeopt/heap.py` rather than
`rpython/jit/metainterp/optimizeopt/pure.py`, which can result in better codegen
for traces containing a large number of pure getfield operations.

.. branch: exctrans

Try to ensure that no new functions get annotated during the 'source_c' phase.
Refactor sandboxing to operate at a higher level.

.. branch: cpyext-bootstrap

.. branch: vmprof-newstack

Refactor vmprof to work cross-operating-system.

.. branch: seperate-strucmember_h

Seperate structmember.h from Python.h Also enhance creating api functions
to specify which header file they appear in (previously only pypy_decl.h) 

.. branch: llimpl

Refactor register_external(), remove running_on_llinterp mechanism and
apply sandbox transform on externals at the end of annotation.

.. branch: cffi-embedding-win32

.. branch: windows-vmprof-support

vmprof should work on Windows.


.. branch: reorder-map-attributes

When creating instances and adding attributes in several different orders
depending on some condition, the JIT would create too much code. This is now
fixed.

.. branch: cpyext-gc-support-2

Improve CPython C API support, which means lxml now runs unmodified
(after removing pypy hacks, pending pull request)

.. branch: look-inside-tuple-hash

Look inside tuple hash, improving mdp benchmark

.. branch: vlen-resume

Compress resume data, saving 10-20% of memory consumed by the JIT

.. branch: issue-2248

.. branch: ndarray-setitem-filtered

Fix boolean-array indexing in micronumpy

.. branch: numpy_partition

Support ndarray.partition() as an app-level function numpy.core._partition_use,
provided as a cffi wrapper to upstream's implementation in the pypy/numpy repo

