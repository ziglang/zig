=======================
What's new in PyPy 2.4+
=======================

.. this is a revision shortly after release-2.3.x
.. startrev: ca9b7cf02cf4

.. branch: fix-bytearray-complexity

Bytearray operations no longer copy the bytearray unnecessarily

Added support for ``__getitem__``, ``__setitem__``, ``__getslice__``,
``__setslice__``,  and ``__len__`` to RPython

.. branch: stringbuilder2-perf

Give the StringBuilder a more flexible internal structure, with a
chained list of strings instead of just one string. This make it
more efficient when building large strings, e.g. with cStringIO().

Also, use systematically jit.conditional_call() instead of regular
branches. This lets the JIT make more linear code, at the cost of
forcing a bit more data (to be passed as arguments to
conditional_calls). I would expect the net result to be a slight
slow-down on some simple benchmarks and a speed-up on bigger
programs.

.. branch: ec-threadlocal

Change the executioncontext's lookup to be done by reading a thread-
local variable (which is implemented in C using '__thread' if
possible, and pthread_getspecific() otherwise). On Linux x86 and
x86-64, the JIT backend has a special optimization that lets it emit
directly a single MOV from a %gs- or %fs-based address. It seems
actually to give a good boost in performance.

.. branch: fast-gil

A faster way to handle the GIL, particularly in JIT code. The GIL is
now a composite of two concepts: a global number (it's just set from
1 to 0 and back around CALL_RELEASE_GIL), and a real mutex. If there
are threads waiting to acquire the GIL, one of them is actively
checking the global number every 0.1 ms to 1 ms.  Overall, JIT loops
full of external function calls now run a bit faster (if no thread was
started yet), or a *lot* faster (if threads were started already).

.. branch: jit-get-errno

Optimize the errno handling in the JIT, notably around external
function calls. Linux-only.

.. branch: disable_pythonapi

Remove non-functioning ctypes.pyhonapi and ctypes.PyDLL, document this
incompatibility with cpython. Recast sys.dllhandle to an int.

.. branch: scalar-operations

Fix performance regression on ufunc(<scalar>, <scalar>) in numpy.

.. branch: pytest-25

Update our copies of py.test and pylib to versions 2.5.2 and 1.4.20, 
respectively.

.. branch: split-ast-classes

Classes in the ast module are now distinct from structures used by the compiler.

.. branch: stdlib-2.7.8

Upgrades from 2.7.6 to 2.7.8

.. branch: cpybug-seq-radd-rmul

Fix issue #1861 - cpython compatability madness
