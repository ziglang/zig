=========================
What's new in PyPy3 7.2.0
=========================

.. this is the revision after release-pypy3.6-v7.1.1
.. startrev: db5a1e7fbbd0

.. branch: fix-literal-prev_digit-underscore

Fix parsing for converting strings with underscore into ints

.. branch: winmultiprocessing

Improve multiprocessing support on win32

.. branch: setitem2d

Allow 2d indexing in ``memoryview.__setitem__`` (issue bb-3028)

.. branch: py3.6-socket-fix
.. branch: fix-importerror
.. branch: dj_s390
.. branch: bpo-35409
.. branch: remove_array_with_char_test
.. branch: fix_test_unicode_outofrange
.. branch: Ram-Rachum/faulthandleris_enabled-should-return-fal-1563636614875
.. branch: Anthony-Sottile/fix-leak-of-file-descriptor-with-_iofile-1559687440863

.. branch: py3tests

Add handling of application-level test files and -D flag to test runner

.. branch: vendor/stdlib-3.6
.. branch: stdlib-3.6.9

Update standard library to version 3.6.9

.. branch: __debug__-optimize

Fix handling of __debug__, sys.flags.optimize, and '-O' command-line flag to 
match CPython 3.6.

.. branch: more-cpyext

Add ``PyErr_SetFromWindowsErr`` and ``pytime.h``, ``pytime.c``. Fix order of
fields in ``Py_buffer``.

.. branch: Ryan-Hileman/add-support-for-zipfile-stdlib-1562420744699

Add support for the entire stdlib being inside a zipfile


.. branch: json-decoder-maps-py3.6

Much faster and more memory-efficient JSON decoding. The resulting
dictionaries that come out of the JSON decoder have faster lookups too.


