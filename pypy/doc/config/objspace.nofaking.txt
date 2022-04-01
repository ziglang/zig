This options prevents the automagic borrowing of implementations of
modules and types not present in PyPy from CPython.

As such, it is required when translating, as then there is no CPython
to borrow from.  For running py.py it is useful for testing the
implementation of modules like "posix", but it makes everything even
slower than it is already.
