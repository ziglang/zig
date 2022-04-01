===========================
What's new in PyPy2.7 5.10+
===========================

.. this is a revision shortly after release-pypy2.7-v5.10.0
.. startrev: 6b024edd9d12

.. branch: cpyext-avoid-roundtrip

Big refactoring of some cpyext code, which avoids a lot of nonsense when
calling C from Python and vice-versa: the result is a big speedup in
function/method calls, up to 6 times faster.

.. branch: cpyext-datetime2

Support ``tzinfo`` field on C-API datetime objects, fixes latest pandas HEAD


.. branch: mapdict-size-limit

Fix a corner case of mapdict: When an instance is used like a dict (using
``setattr`` and ``getattr``, or ``.__dict__``) and a lot of attributes are
added, then the performance using mapdict is linear in the number of
attributes. This is now fixed (by switching to a regular dict after 80
attributes).


.. branch: cpyext-faster-arg-passing

When using cpyext, improve the speed of passing certain objects from PyPy to C
code, most notably None, True, False, types, all instances of C-defined types.
Before, a dict lookup was needed every time such an object crossed over, now it
is just a field read.


.. branch: 2634_datetime_timedelta_performance

Improve datetime + timedelta performance.

.. branch: memory-accounting

Improve way to describe memory

.. branch: msvc14

Allow compilaiton with Visual Studio 2017 compiler suite on windows

.. branch: refactor-slots

Refactor cpyext slots.


.. branch: call-loopinvariant-into-bridges

Speed up branchy code that does a lot of function inlining by saving one call
to read the TLS in most bridges.

.. branch: rpython-sprint

Refactor in rpython signatures

.. branch: cpyext-tls-operror2

Store error state thread-locally in executioncontext, fixes issue #2764

.. branch: cpyext-fast-typecheck

Optimize `Py*_Check` for `Bool`, `Float`, `Set`. Also refactor and simplify
`W_PyCWrapperObject` which is used to call slots from the C-API, greatly
improving microbenchmarks in https://github.com/antocuni/cpyext-benchmarks


.. branch: fix-sre-problems

Fix two (unrelated) JIT bugs manifesting in the re module:

- green fields are broken and were thus disabled, plus their usage removed from
  the _sre implementation

- in rare "trace is too long" situations, the JIT could break behaviour
  arbitrarily.

.. branch: jit-hooks-can-be-disabled

Be more efficient about JIT hooks. Make it possible for the frontend to declare
that jit hooks are currently not enabled at all. in that case, the list of ops
does not have to be created in the case of the on_abort hook (which is
expensive).


.. branch: pyparser-improvements

Improve speed of Python parser, improve ParseError messages slightly.

.. branch: ioctl-arg-size

Work around possible bugs in upstream ioctl users, like CPython allocate at
least 1024 bytes for the arg in calls to ``ioctl(fd, request, arg)``. Fixes
issue #2776

.. branch: cpyext-subclass-setattr

Fix for python-level classes that inherit from C-API types, previously the
`w_obj` was not necessarily preserved throughout the lifetime of the `pyobj`
which led to cases where instance attributes were lost. Fixes issue #2793


.. branch: pyparser-improvements-2

Improve line offsets that are reported by SyntaxError. Improve error messages
for a few situations, including mismatched parenthesis.

.. branch: issue2752

Fix a rare GC bug that was introduced more than one year ago, but was
not diagnosed before issue #2752.

.. branch: gc-hooks

Introduce GC hooks, as documented in doc/gc_info.rst

.. branch: gc-hook-better-timestamp

Improve GC hooks

.. branch: cppyy-packaging

Update backend to 0.6.0 and support exceptions through wrappers
