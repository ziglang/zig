=========================
What's new in PyPy3 7.3.2
=========================

.. this is the revision after release-pypy3.6-v7.3.1
.. startrev: e81cea3ac65e

.. branch: py3-recvmsg_into

Implement socket.recvmsg_into().

.. branch: py3-posix-fixes

Fix return types in os.readlink() (issue #3177) and os.listdir().

.. branch: winconsoleio

Provide the ``_WindowsConsoleIO`` module on windows. Support may be incomplete.

.. branch: fix-windows-utf8

Fix os.listdir() on Windows with unicode file names

.. branch: locale-encode-decode

Use utf8 in locale.py, add `PyUnicode_{En,De}code_Locale`

.. branch: exc.object

Allow errorhandlers to modify the underlying str/bytes being converted

.. branch: win-unicode

Fix PyUnicode handling of windows where wchar_t is 2 bytes

.. branch: list-with-longs

Internally, integers are W_IntObject or W_LongObject depending on how large
they are.  It's possible to obtain W_LongObject even though the integer is
small enough, depending on how you build it (e.g. dividing two very large
integers).  The problem now fixed was that these small W_LongObjects caused
various optimizations to stop working: for example, storing one in a list
of W_IntObjects caused the list to loose its int optimization (issue #3250).

.. branch: redo-pr-639

Add ``os.sched_rr_get_interval``, ``os.sched_getscheduler``,
``sched_setscheduler``, ``sched_getparam``

.. branch: hpy

Provide a backend for HPy, currently disabled in the release

