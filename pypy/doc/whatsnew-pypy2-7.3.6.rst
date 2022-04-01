===========================
What's new in PyPy2.7 7.3.6
===========================

.. this is a revision shortly after release-pypy-7.3.4
.. startrev: 9c11d242d78c


.. branch: faster-rbigint-big-divmod

Speed up ``divmod`` for very large numbers. This also speeds up string
formatting of big numbers.

.. branch: jit-heapcache-interiorfields

Optimize dictionary operations in the JIT a bit more, making it possible to
completely optimize away the creation of dictionaries in more situations (such
as calling the ``dict.update`` method on known dicts).

.. branch: bpo-35714

Add special error messange for ``'\0'`` in ``rstruct.formatiterator``
(bpo-35714)

.. branch: gcc-precompiled-header

Speed up GCC compilation by using a pre-compiled header.

.. branch: set-vmprof_apple-only-on-darwin

Only set VMPROF_APPLE on bsd-like when sys.platform is darwin

.. minor branches not worth to document
.. branch: fix-checkmodule-2
.. branch: tiny-traceviewer-fix


.. branch: dotviewer-python3

Make dotviewer python3 compatible and add some features (like rudimentary
record support).

.. branch: specialize-sum

Add specialization for sum(list) and sum(tuple)

.. branch: win64-xmm-registers

Set non-volatile xmm registers in the JIT for windows 64-bit calling
conventions. Fixes a bug where the JIT was not restoring registers when
returning from a call

.. branch: no-make-portable

Add an option to package pypy non-portably

.. branch: win64-stat

Add ``st_file_attributes`` and ``st_reparse_tag`` attributes to ``os.stat``
on windows. Also follow the reparse logic of Python3.8.

.. branch: scoped-cffi-malloc

Adds a scoped way to malloc buffers to cffi and use it in ``ssl.read``
