"""
A general way to flatten deeply recursive algorithms by delaying some
parts until later.
"""

try:
    from thread import _local as TlsClass
except ImportError:
    class TlsClass(object):
        pass


class FlattenRecursion(TlsClass):

    def __init__(self):
        self.later = None

    def __call__(self, func, *args, **kwds):
        """Call func(*args, **kwds), either now, or, if we're recursing,
        then the call will be done later by the first level.
        """
        if self.later is not None:
            self.later.append((func, args, kwds))
        else:
            self.later = lst = []
            try:
                func(*args, **kwds)
                for func, args, kwds in lst:
                    func(*args, **kwds)
            finally:
                self.later = None
