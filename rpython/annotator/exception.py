from rpython.rlib import rstackovf

# the exceptions that can be implicitely raised by some operations
standardexceptions = set([TypeError, OverflowError, ValueError,
    ZeroDivisionError, MemoryError, IOError, OSError, StopIteration, KeyError,
    IndexError, AssertionError, RuntimeError, UnicodeDecodeError,
    UnicodeEncodeError, NotImplementedError, rstackovf._StackOverflow])
