=========================
What's new in PyPy3 5.7+
=========================

.. this is the revision after release-pypy3.3-5.7.x was branched
.. startrev: afbf09453369

.. branch: mtest

Use "<python> -m test" to run the CPython test suite, as documented by CPython,
instead of our outdated regrverbose.py script.

.. branch: win32-faulthandler

Enable the 'faulthandler' module on Windows;
this unblocks the Python test suite.

.. branch: superjumbo

Implement posix.posix_fallocate() and posix.posix_fadvise()

.. branch: py3.5-mac-translate

Fix for different posix primitives on MacOS

.. branch: PyBuffer

Internal refactoring of memoryviews and buffers, fixing some related
performance issues.

.. branch: jumbojet

Add sched_get min/max to rposix
