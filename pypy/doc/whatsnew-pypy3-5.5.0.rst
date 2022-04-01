=========================
What's new in PyPy3 5.5.0
=========================

.. this is the revision after 5.2.0 was branched
.. startrev: 2dd24a7eb90b

.. pull request #454

Update fallback code in time to match CPython.

.. d93d0a6c41f9

Add str.casefold().

.. f1c0e13019d5

Update Unicode character database to version 6.1.0.

.. pull request #461

Make win_perf_counter expose the clock info.
Add a couple more fallbacks.
Make time.monotonic conditionally available depending on platform.

.. issue 2346

Make hash(-1) return -2, like it does on CPython.

.. pull request #469

Fix the mappingproxy type to behave as in CPython.

.. branch: py3k-kwonly-builtin

Implement keyword-only arguments for built-in functions. Fix functions in the 
posix module to have keyword-only arguments wherever CPython has them, instead
of regular keyword arguments.

.. pull request #475

Add os.get_terminal_size().

.. memoryview stuff

Implement slicing of memoryview objects and improve their compatibility with
CPython.

.. bdd0b2244dd3

Set up ImportError attributes properly in _imp.load_dynamic().

.. 494a05343a22

Allow __len__ to return any index-like.

.. branch: py3k-faulthandler

Replace stub faulthandler module with a working implementation.
