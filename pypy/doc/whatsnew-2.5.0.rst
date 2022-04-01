========================
What's new in PyPy 2.5.0
========================

.. this is a revision shortly after release-2.4.x
.. startrev: 7026746cbb1b

.. branch: win32-fixes5

Fix c code generation for msvc so empty "{ }" are avoided in unions,
Avoid re-opening files created with NamedTemporaryFile,
Allocate by 4-byte chunks in rffi_platform,
Skip testing objdump if it does not exist,
and other small adjustments in own tests

.. branch: rtyper-stuff

Small internal refactorings in the rtyper.

.. branch: var-in-Some

Store annotations on the Variable objects, rather than in a big dict.
Introduce a new framework for double-dispatched annotation implementations.

.. branch: ClassRepr

Refactor ClassRepr and make normalizecalls independent of the rtyper.

.. branch: remove-remaining-smm

Remove all remaining multimethods.

.. branch: improve-docs

Split RPython documentation from PyPy documentation and clean up.  There now is
a clearer separation between documentation for users, developers and people
interested in background information.

.. branch: kill-multimethod

Kill multimethod machinery, all multimethods were removed earlier.

.. branch nditer-external_loop

Implement `external_loop` arguement to numpy's nditer

.. branch kill-rctime

Rename pypy/module/rctime to pypy/module/time, since it contains the implementation of the 'time' module.

.. branch: ssa-flow

Use SSA form for flow graphs inside build_flow() and part of simplify_graph()

.. branch: ufuncapi

Implement most of the GenericUfunc api to support numpy linalg. The strategy is
to encourage use of pure python or cffi ufuncs by extending frompyfunc().
See the docstring of frompyfunc for more details. This dovetails with a branch
of pypy/numpy - cffi-linalg which is a rewrite of the _umath_linalg module in
python, calling lapack from cffi. The branch also support traditional use of
cpyext GenericUfunc definitions in c.

.. branch: all_ordered_dicts

This makes ordered dicts the default dictionary implementation in
RPython and in PyPy. It polishes the basic idea of rordereddict.py
and then fixes various things, up to simplifying
collections.OrderedDict.

Note: Python programs can rely on the guaranteed dict order in PyPy
now, but for compatibility with other Python implementations they
should still use collections.OrderedDict where that really matters.
Also, support for reversed() was *not* added to the 'dict' class;
use OrderedDict.

Benchmark results: in the noise. A few benchmarks see good speed
improvements but the average is very close to parity.

.. branch: berkerpeksag/fix-broken-link-in-readmerst-1415127402066
.. branch: bigint-with-int-ops
.. branch: dstufft/update-pip-bootstrap-location-to-the-new-1420760611527
.. branch: float-opt
.. branch: gc-incminimark-pinning

This branch adds an interface rgc.pin which would (very temporarily)
make object non-movable. That's used by rffi.alloc_buffer and
rffi.get_nonmovable_buffer and improves performance considerably for
IO operations.

.. branch: gc_no_cleanup_nursery

A branch started by Wenzhu Man (SoC'14) and then done by fijal. It
removes the clearing of the nursery. The drawback is that new objects
are not automatically filled with zeros any longer, which needs some
care, mostly for GC references (which the GC tries to follow, so they
must not contain garbage). The benefit is a quite large speed-up.

.. branch: improve-gc-tracing-hooks
.. branch: improve-ptr-conv-error
.. branch: intern-not-immortal

Fix intern() to return mortal strings, like in CPython.

.. branch: issue1922-take2
.. branch: kill-exported-symbols-list
.. branch: kill-rctime
.. branch: kill_ll_termios
.. branch: look-into-all-modules
.. branch: nditer-external_loop
.. branch: numpy-generic-item
.. branch: osx-shared

``--shared`` support on OS/X (thanks wouter)

.. branch: portable-threadlocal
.. branch: pypy-dont-copy-ops
.. branch: recursion_and_inlining
.. branch: slim-down-resumedescr
.. branch: squeaky/use-cflags-for-compiling-asm
.. branch: unicode-fix
.. branch: zlib_zdict

.. branch: errno-again

Changes how errno, GetLastError, and WSAGetLastError are handled.
The idea is to tie reading the error status as close as possible to
the external function call. This fixes some bugs, both of the very
rare kind (e.g. errno on Linux might in theory be overwritten by
mmap(), called rarely during major GCs, if such a major GC occurs at
exactly the wrong time), and some of the less rare kind
(particularly on Windows tests).

.. branch: osx-package.py
.. branch: package.py-helpful-error-message

.. branch: typed-cells

Improve performance of integer globals and class attributes.
