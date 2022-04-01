"""
Disabled for now.  This should run at app-level, too.
"""
import pickle

class Picklable(object):
    def __init__(self, a=555):
        self.a = a
    def __eq__(self, other):
        return self.a == other.a
    def __str__(self):
        return '%s(%r)' % (self.__class__.__name__, self.a)
    __repr__ = __str__

class PicklableSpecial2(Picklable):
    def __reduce__(self):
        return self.__class__, (self.a,)

class PicklableSpecial3(Picklable):
    def __reduce__(self):
        return self.__class__, (), self.a
    def __setstate__(self, a):
        self.a = a

class PicklableSpecial4(Picklable):
    def __reduce_ex__(self, proto):
        return self.__class__, (), self.a
    def __setstate__(self, a):
        self.a = a

def _pickle_some(x):
    for proto in range(pickle.HIGHEST_PROTOCOL + 1):
        s = pickle.dumps(x, proto)
        y = pickle.loads(s)
        assert x == y

_pickle_some(Picklable(5))
_pickle_some(PicklableSpecial2(66))
_pickle_some(PicklableSpecial3(7))
_pickle_some(PicklableSpecial4(17))
