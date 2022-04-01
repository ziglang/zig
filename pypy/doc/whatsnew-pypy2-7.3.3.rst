===========================
What's new in PyPy2.7 7.3.3
===========================

.. this is a revision shortly after release-pypy-7.3.2
.. startrev: c136fdb316e4

.. branch: rpython-error_value
.. branch: hpy-error-value
   
Introduce @rlib.objectmodel.llhelper_error_value, will is used by HPy



.. branch: cross_compilation_fixes

Respect PKG_CONFIG and CC in more places to allow cross-compilation

.. branch: darwin-sendfile-2.7

Add posix.sendfile to darwin for python3.6+

.. branch: app_main

Avoid using ``import os`` until after ``import site`` in ``app_main``

.. branch: stdlib-2.7.18-3

Update lib-python/2.7 to stdlib-2.7.18 and fix many tests

.. branch: cptpcrd-resource-prlimit

Add ``prlimit`` to ``resource``