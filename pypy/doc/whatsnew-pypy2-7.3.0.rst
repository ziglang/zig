===========================
What's new in PyPy2.7 7.3.0
===========================

.. this is a revision shortly after release-pypy-7.2.0
.. startrev: a511d86377d6 

.. branch: fix-descrmismatch-crash

Fix segfault when calling descr-methods with no arguments

.. branch: https-readme

Convert http -> https in README.rst

.. branch: license-update

Update list directories in LICENSE

.. branch: allow-forcing-no-embed

When packaging, allow suppressing embedded dependencies via
PYPY_NO_EMBED_DEPENDENCIES

.. branch: int-test-is-zero

.. branch: cppyy-dev

Upgraded the built-in ``_cppyy`` module to ``cppyy-backend 1.10.6``, which
provides, among others, better template resolution, stricter ``enum`` handling,
anonymous struct/unions, cmake fragments for distribution, optimizations for
PODs, and faster wrapper calls.

.. branch: backport-decode_timeval_ns-py3.7

Backport ``rtime.decode_timeval_ns`` from py3.7 to rpython

.. branch: kill-asmgcc

Completely remove the deprecated translation option ``--gcrootfinder=asmgcc``
because it no longer works with a recent enough ``gcc``.
