===========================
What's new in PyPy2.7 7.3.2
===========================

.. this is a revision shortly after release-pypy-7.3.1
.. startrev: 1cae9900d598

.. branch: optimize-sre-unicode

Speed up performance of matching Unicode strings in the ``re`` module
significantly for characters that are part of ASCII.

.. branch: rpython-recvmsg_into

Refactor RSocket.xxx_into() methods and add .recvmsg_into().

.. branch: bo-fix-source-links

Fix documentation extlinks for heptapod directory schema

.. branch: py3.6 # ignore, bad merge

.. branch: ssl  # ignore, small test fix

.. branch: ctypes-stuff

Fix implementation of PEP 3118 in ctypes.

.. branch: issue3240

Use make_portable on macOS

.. branch: wb_before_move

Add ``rgc.ll_arraymove()``, as a way to shift items inside the same
array with proper GC support. Improves ``while lst: lst.pop(0)``.

.. branch: no-str-unicode-union

Remove all implicit str-unicode conversions in RPython.

.. branch: initialize_lock_timeout_on_windows

Fix uninitialized value in rlock.acquire on windows, fixes issue 3252

.. branch: jit-releaseall 

Add ``pypyjit.releaseall()`` that marks all current machine code
objects as ready to release. They will be released at the next GC (unless they
are currently in use in the stack of one of the threads).
