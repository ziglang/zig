==========================
What's new in PyPy2.7 5.10
==========================

.. this is a revision shortly after release-pypy2.7-v5.9.0
.. startrev:d56dadcef996


.. branch: cppyy-packaging

Cleanup and improve cppyy packaging

.. branch: docs-osx-brew-openssl

.. branch: keep-debug-symbols

Add a smartstrip tool, which can optionally keep the debug symbols in a
separate file, instead of just stripping them away. Use it in packaging

.. branch: bsd-patches

Fix failures on FreeBSD, contributed by David Naylor as patches on the issue
tracker (issues 2694, 2695, 2696, 2697)

.. branch: run-extra-tests

Run extra_tests/ in buildbot

.. branch: vmprof-0.4.10

Upgrade the _vmprof backend to vmprof 0.4.10

.. branch: fix-vmprof-stacklet-switch
.. branch: fix-vmprof-stacklet-switch-2

Fix a vmprof+continulets (i.e. greenelts, eventlet, gevent, ...)

.. branch: win32-vcvars

.. branch: rdict-fast-hash

Make it possible to declare that the hash function of an r_dict is fast in RPython.
