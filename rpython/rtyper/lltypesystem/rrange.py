from rpython.rtyper.lltypesystem.lltype import Ptr, GcStruct, Signed, malloc, Void
from rpython.rtyper.rrange import AbstractRangeRepr, AbstractRangeIteratorRepr
from rpython.rtyper.error import TyperError

# ____________________________________________________________
#
#  Concrete implementation of RPython lists that are returned by range()
#  and never mutated afterwards:
#
#    struct range {
#        Signed start, stop;    // step is always constant
#    }
#
#    struct rangest {
#        Signed start, stop, step;    // rare case, for completeness
#    }

def ll_length(l):
    if l.step > 0:
        lo = l.start
        hi = l.stop
        step = l.step
    else:
        lo = l.stop
        hi = l.start
        step = -l.step
    if hi <= lo:
        return 0
    n = (hi - lo - 1) // step + 1
    return n

def ll_getitem_fast(l, index):
    return l.start + index * l.step

RANGEST = GcStruct("range", ("start", Signed), ("stop", Signed), ("step", Signed),
                    adtmeths = {
                        "ll_length":ll_length,
                        "ll_getitem_fast":ll_getitem_fast,
                    },
                    hints = {'immutable': True})
RANGESTITER = GcStruct("range", ("next", Signed), ("stop", Signed), ("step", Signed))

class RangeRepr(AbstractRangeRepr):

    RANGEST = Ptr(RANGEST)
    RANGESTITER = Ptr(RANGESTITER)

    getfield_opname = "getfield"

    def __init__(self, step, *args):
        self.RANGE = Ptr(GcStruct("range", ("start", Signed), ("stop", Signed),
                adtmeths = {
                    "ll_length":ll_length,
                    "ll_getitem_fast":ll_getitem_fast,
                    "step":step,
                },
                hints = {'immutable': True}))
        self.RANGEITER = Ptr(GcStruct("range", ("next", Signed), ("stop", Signed)))
        AbstractRangeRepr.__init__(self, step, *args)
        self.ll_newrange = ll_newrange
        self.ll_newrangest = ll_newrangest

    def make_iterator_repr(self, variant=None):
        if variant is not None:
            raise TyperError("unsupported %r iterator over a range list" %
                             (variant,))
        return RangeIteratorRepr(self)


def ll_newrange(RANGE, start, stop):
    l = malloc(RANGE.TO)
    l.start = start
    l.stop = stop
    return l

def ll_newrangest(start, stop, step):
    if step == 0:
        raise ValueError
    l = malloc(RANGEST)
    l.start = start
    l.stop = stop
    l.step = step
    return l

class RangeIteratorRepr(AbstractRangeIteratorRepr):

    def __init__(self, *args):
        AbstractRangeIteratorRepr.__init__(self, *args)
        self.ll_rangeiter = ll_rangeiter

def ll_rangeiter(ITERPTR, rng):
    iter = malloc(ITERPTR.TO)
    iter.next = rng.start
    iter.stop = rng.stop
    if ITERPTR.TO is RANGESTITER:
        iter.step = rng.step
    return iter

