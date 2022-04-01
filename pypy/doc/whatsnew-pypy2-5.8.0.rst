==========================
What's new in PyPy2.7 5.8+
==========================

.. this is a revision shortly after release-pypy2.7-v5.7.0
.. startrev: 44f31f6dd39f

Add cpyext interfaces for ``PyModule_New``

Correctly handle `dict.pop`` where the ``pop``
key is not the same type as the ``dict``'s and ``pop``
is called with a default (will be part of release 5.7.1)

.. branch: issue2522

Fix missing tp_new on w_object called through multiple inheritance
(will be part of release 5.7.1)

.. branch: lstrip_to_empty_string

.. branch: vmprof-native

PyPy support to profile native frames in vmprof.

.. branch: reusing-r11
.. branch: branch-prediction

Performance tweaks in the x86 JIT-generated machine code: rarely taken
blocks are moved off-line.  Also, the temporary register used to contain
large constants is reused across instructions.

.. branch: vmprof-0.4.4

.. branch: controller-refactor

Refactor rpython.rtyper.controllerentry.

.. branch: PyBuffer-backport

Internal refactoring of buffers and memoryviews. Memoryviews will now be
accepted in a few more places, e.g. in compile().

.. branch: sthalik/fix-signed-integer-sizes-1494493539409

.. branch: cpyext-obj-stealing

Redo much of the refcount semantics in PyList_{SG}etItem to closer match
CPython and ensure the same PyObject stored in the list can be later
retrieved

.. branch: cpyext-recursionlimit

Implement Py_EnterRecursiveCall and associated functions

.. branch: pypy_ctypes_nosegfault_nofastpath

Remove faulty fastpath from ctypes

.. branch: sockopt_zero

Passing a buffersize of 0 to socket.getsockopt

.. branch: better-test-whatsnew

.. branch: faster-rstruct-2

Improve the performance of struct.pack and struct.pack_into by using raw_store
or gc_store_indexed whenever possible. Moreover, enable the existing
struct.unpack fast path to all the existing buffer types, whereas previously
it was enabled only for strings

.. branch: Kounavi/fix-typo-depricate-to-deprecate-p-1495624547235

.. branch: PyPy_profopt_enabled

Add profile-based optimization option ``profopt``, and specify training data
via ``profoptpath``
