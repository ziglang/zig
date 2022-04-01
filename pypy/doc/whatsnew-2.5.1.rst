========================
What's new in PyPy 2.5.1
========================

.. this is a revision shortly after release-2.5.0
.. startrev: 397b96217b85


Non-blocking file reads sometimes raised EAGAIN even though they
had buffered data waiting, fixed in b1c4fcb04a42

Fix a bug in cpyext in multithreded programs acquiring/releasing the GIL

.. branch: vmprof

.. branch: stackroot-speedup-2

Avoid tracing all stack roots during repeated minor collections,
by ignoring the part of the stack that didn't change

.. branch: stdlib-2.7.9

Update stdlib to version 2.7.9

.. branch: fix-kqueue-error2

Fix exception being raised by kqueue.control (CPython compatibility)

.. branch: gitignore

.. branch: framestate2

Refactor rpython.flowspace.framestate.FrameState.

.. branch: alt_errno

Add an alternative location to save LastError, errno around ctypes,
cffi external calls so things like pdb will not overwrite it

.. branch: nonquadratic-heapcache

Speed up the warmup times of the JIT by removing a quadratic algorithm in the
heapcache.

.. branch: online-transforms-2

Simplify flow graphs on the fly during annotation phase.
