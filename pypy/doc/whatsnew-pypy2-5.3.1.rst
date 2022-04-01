===========================
What's new in PyPy2.7 5.3.1
===========================

.. this is a revision shortly after release-pypy2.7-v5.3.0
.. startrev: f4d726d1a010


A bug-fix release, merging these changes:

  * Add include guards to pymem.h, fixes issue #2321

  * Make vmprof build on OpenBSD, from pull request #456

  * Fix ``bytearray('').replace('a', 'ab')``, issue #2324
