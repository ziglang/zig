# XXX Check for win64:
# The win64 port of PyPy/RPython requires sys.maxint == sys.maxsize,
# this differs from the CPython implementation
# see comment at the top of rpython.rlib.rarithmetic for details
import sys
if hasattr(sys, "maxint") and hasattr(sys, "maxsize"):
    if sys.maxint != sys.maxsize:
        raise Exception(
            "Translating on win64 requires either a modified CPython "
            "(so-called CPython64/64) or a working win64 build of PyPy2.")
