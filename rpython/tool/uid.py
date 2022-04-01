import math
import struct

HUGEVAL_BYTES = struct.calcsize('P')
HUGEVAL = 256 ** HUGEVAL_BYTES


def fixid(result):
    if result < 0:
        result += HUGEVAL
    return result

uid = id    # guaranteed to be positive from CPython 2.5 onwards


class Hashable(object):
    """
    A Hashable instance encapsulates any object, but is always usable as a
    key in dictionaries.  This is based on id() for mutable objects and on
    real hash/compare for immutable ones.
    """
    __slots__ = ["key", "value"]

    def __init__(self, value):
        self.value = value     # a concrete value
        # try to be smart about constant mutable or immutable values
        key = type(self.value), self.value  # to avoid confusing e.g. 0 and 0.0
        #
        # we also have to avoid confusing 0.0 and -0.0 (needed e.g. for
        # translating the cmath module)
        if key[0] is float and not self.value:
            if math.copysign(1., self.value) == -1.:    # -0.0
                key = (float, "-0.0")
        #
        try:
            hash(key)
        except TypeError:
            key = id(self.value)
        self.key = key

    def __eq__(self, other):
        return self.__class__ is other.__class__ and self.key == other.key

    def __ne__(self, other):
        return not (self == other)

    def __hash__(self):
        return hash(self.key)

    def __repr__(self):
        return '(%s)' % (self,)

    def __str__(self):
        # try to limit the size of the repr to make it more readable
        r = repr(self.value)
        if (r.startswith('<') and r.endswith('>') and
                hasattr(self.value, '__name__')):
            r = '%s %s' % (type(self.value).__name__, self.value.__name__)
        elif len(r) > 60 or (len(r) > 30 and type(self.value) is not str):
            r = r[:22] + '...' + r[-7:]
        return r
