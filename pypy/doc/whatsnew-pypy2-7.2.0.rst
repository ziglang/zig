===========================
What's new in PyPy2.7 7.2.0
===========================

.. this is a revision shortly after release-pypy-7.1.0
.. startrev: d3aefbf6dae7

.. branch: Twirrim/minor-typo-fix-1553456951526

Fix typo

.. branch: jit-cleanup

Remove rpython.jit.metainterp.typesystem and clean up related code in rpython/jit/

.. branch: datetime_api_27

Add ``DateTime_FromTimestamp`` and ``Date_FromTimestamp``

.. branch: semlock-deadlock

Test and reduce the probability of a deadlock when acquiring a semaphore by
moving global state changes closer to the actual aquire.

.. branch: shadowstack-issue2722

Make the shadowstack size more dynamic

.. branch: cffi-libs

Move _ssl and _hashlib from rpython to a cffi-based module, like on python3.
Reduces the number of problematic linked-in libraries (libssl, libcrypto)

.. branch: fix-vmprof-memory-tracking

Fix a bug that prevent memory-tracking in vmprof working on PyPy.

.. branch: optimizeopt-cleanup

Cleanup optimizeopt

.. branch: copystrcontents-in-rewrite

Remove ``copystrcontent`` and ``copyunicodecontent`` in the backends.
Instead, replace it in ``rewrite.py`` with a direct call to ``memcpy()`` and
new basic operation, ``load_effective_address``, which the backend can
even decide not to implement.

.. branch: arm64

Add a JIT backend for ARM64 (aarch64)

.. branch: fix-test-vmprof-closed-file


.. branch: fix_darwin_list_dir_test

.. branch: apptest-file

New mechanism for app-level testing using -D to test all apptest_*.py files

.. branch: feature_closed_prop_to_rfile

Add RFile.closed

.. branch: cryptograhpt-2.7

Update vendored cryptography used for _ssl to 2.7

.. branch: compile_ncurses_tcl_tk_suse_latest

Check for headers and runtime libraries in more locations to support other linuxes

.. branch: openssl-for-macos

Update _ssl on macos to statically link to openssl-1.1.1c

.. branch: json-decoder-maps

Much faster and more memory-efficient JSON decoding. The resulting
dictionaries that come out of the JSON decoder have faster lookups too.

