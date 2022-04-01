============================
What's new in PyPy2.7 7.3.0+
============================

.. this is a revision shortly after release-pypy-7.3.0
.. startrev: 994c42529580

.. branch: cpyext-speedup-tests

Make cpyext test faster, especially on py3.6

.. branch: array-and-nan

Handle ``NAN`` more correctly in ``array.array`` for ``__eq__`` and ``count``

.. branch: bpo-16055

Fixes incorrect error text for ``int('1', base=1000)``

.. branch: heptapod

adapt contributing documentation to heptapod

.. branch: pypy-jitdriver-greenkeys

Improve code generation for generators (and generator expressions in
particular) when passing them to builtin functions that consume iterators, such
as ``sum``, ``map``, ``max``, etc.

.. branch: warmup-improvements-various

Improves warmup time by up to 20%.

.. branch: StringIO-perf

Improve performance of io.StringIO(). It should now be faster than CPython in
common use cases.

.. branch: rgil-track-thread
.. branch: hpy-rpython-backports

.. branch: nested-scopes-jit

Improve the code generation for inner functions that use outer variables that
are constant.

.. branch win32-cppyy

Enable _cppyy for win32, prefer newer msvc compilers
