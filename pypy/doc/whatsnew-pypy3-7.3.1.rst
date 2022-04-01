=========================
What's new in PyPy3 7.3.1
=========================

.. this is the revision after release-pypy3.6-v7.3.0
.. startrev: a56889d5df88

.. branch: cpyext-speedup-tests-py36

Make cpyext test faster, especially on py3.6

.. branch: py3.6-sqlite

Follow CPython's behaviour more closely in sqlite3

.. branch: py3-StringIO-perf

Improve performance of io.StringIO(). It should now be faster than CPython in
common use cases.

.. branch: ignore-pyenv-launcher

virtualenv on macOS defines an environment variable ``__PYVENV_LAUNCHER__`` to
let the invoked python know it is inside a venv. This is not needed on PyPy so
it is deleted when importing ``site`` and reset afterwards.
