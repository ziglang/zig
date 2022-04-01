import sys
from rpython.rlib.rarithmetic import ovfcheck, LONG_BIT, maxint, is_valid_int
from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.jit.metainterp.resoperation import rop, ResOperation
from rpython.jit.metainterp.optimizeopt.info import AbstractInfo, INFO_NONNULL,\
     INFO_UNKNOWN, INFO_NULL
from rpython.jit.metainterp.history import ConstInt


MAXINT = maxint
MININT = -maxint - 1

IS_64_BIT = sys.maxint > 2**32

def next_pow2_m1(n):
    """Calculate next power of 2 greater than n minus one."""
    n |= n >> 1
    n |= n >> 2
    n |= n >> 4
    n |= n >> 8
    n |= n >> 16
    if IS_64_BIT:
        n |= n >> 32
    return n


class IntBound(AbstractInfo):
    _attrs_ = ('has_upper', 'has_lower', 'upper', 'lower')

    def __init__(self, lower, upper):
        self.has_upper = True
        self.has_lower = True
        self.upper = upper
        self.lower = lower
        # check for unexpected overflows:
        if not we_are_translated():
            assert type(upper) is not long or is_valid_int(upper)
            assert type(lower) is not long or is_valid_int(lower)

    # Returns True if the bound was updated
    def make_le(self, other):
        if other.has_upper:
            return self.make_le_const(other.upper)
        return False

    def make_le_const(self, other):
        if not self.has_upper or other < self.upper:
            self.has_upper = True
            self.upper = other
            return True
        return False

    def make_lt(self, other):
        if other.has_upper:
            return self.make_lt_const(other.upper)
        return False

    def make_lt_const(self, other):
        try:
            other = ovfcheck(other - 1)
        except OverflowError:
            return False
        return self.make_le_const(other)

    def make_ge(self, other):
        if other.has_lower:
            return self.make_ge_const(other.lower)
        return False

    def make_ge_const(self, other):
        if not self.has_lower or other > self.lower:
            self.has_lower = True
            self.lower = other
            return True
        return False

    def make_gt_const(self, other):
        try:
            other = ovfcheck(other + 1)
        except OverflowError:
            return False
        return self.make_ge_const(other)

    def make_eq_const(self, intval):
        self.has_upper = True
        self.has_lower = True
        self.upper = intval
        self.lower = intval

    def make_gt(self, other):
        if other.has_lower:
            return self.make_gt_const(other.lower)
        return False

    def is_constant(self):
        return self.has_upper and self.has_lower and self.lower == self.upper

    def getint(self):
        assert self.is_constant()
        return self.lower

    def equal(self, value):
        if not self.is_constant():
            return False
        return self.lower == value

    def bounded(self):
        return self.has_lower and self.has_upper

    def known_lt_const(self, other):
        if self.has_upper:
            return self.upper < other
        return False

    def known_le_const(self, other):
        if self.has_upper:
            return self.upper <= other
        return False

    def known_gt_const(self, other):
        if self.has_lower:
            return self.lower > other
        return False

    def known_ge_const(self, other):
        if self.has_upper:
            return self.upper >= other
        return False

    def known_lt(self, other):
        if other.has_lower:
            return self.known_lt_const(other.lower)
        return False

    def known_le(self, other):
        if other.has_lower:
            return self.known_le_const(other.lower)
        return False

    def known_gt(self, other):
        return other.known_lt(self)

    def known_ge(self, other):
        return other.known_le(self)

    def known_nonnegative(self):
        return self.has_lower and 0 <= self.lower

    def intersect(self, other):
        r = False
        if other.has_lower:
            if self.make_ge_const(other.lower):
                r = True
        if other.has_upper:
            if self.make_le_const(other.upper):
                r = True
        return r

    def intersect_const(self, lower, upper):
        r = self.make_ge_const(lower)
        if self.make_le_const(upper):
            r = True
        return r

    def add(self, offset):
        res = self.clone()
        try:
            res.lower = ovfcheck(res.lower + offset)
        except OverflowError:
            res.has_lower = False
        try:
            res.upper = ovfcheck(res.upper + offset)
        except OverflowError:
            res.has_upper = False
        return res

    def mul(self, value):
        return self.mul_bound(IntBound(value, value))

    def add_bound(self, other):
        res = self.clone()
        if other.has_upper:
            try:
                res.upper = ovfcheck(res.upper + other.upper)
            except OverflowError:
                res.has_upper = False
        else:
            res.has_upper = False
        if other.has_lower:
            try:
                res.lower = ovfcheck(res.lower + other.lower)
            except OverflowError:
                res.has_lower = False
        else:
            res.has_lower = False
        return res

    def sub_bound(self, other):
        res = self.clone()
        if other.has_lower:
            try:
                res.upper = ovfcheck(res.upper - other.lower)
            except OverflowError:
                res.has_upper = False
        else:
            res.has_upper = False
        if other.has_upper:
            try:
                res.lower = ovfcheck(res.lower - other.upper)
            except OverflowError:
                res.has_lower = False
        else:
            res.has_lower = False
        return res

    def mul_bound(self, other):
        if self.has_upper and self.has_lower and \
           other.has_upper and other.has_lower:
            try:
                vals = (ovfcheck(self.upper * other.upper),
                        ovfcheck(self.upper * other.lower),
                        ovfcheck(self.lower * other.upper),
                        ovfcheck(self.lower * other.lower))
                return IntBound(min4(vals), max4(vals))
            except OverflowError:
                return IntUnbounded()
        else:
            return IntUnbounded()

    def py_div_bound(self, other):
        if self.has_upper and self.has_lower and \
           other.has_upper and other.has_lower and \
           not other.contains(0):
            try:
                # this gives the bounds for 'int_py_div', so use the
                # Python-style handling of negative numbers and not
                # the C-style one
                vals = (ovfcheck(self.upper / other.upper),
                        ovfcheck(self.upper / other.lower),
                        ovfcheck(self.lower / other.upper),
                        ovfcheck(self.lower / other.lower))
                return IntBound(min4(vals), max4(vals))
            except OverflowError:
                return IntUnbounded()
        else:
            return IntUnbounded()

    def mod_bound(self, other):
        r = IntUnbounded()
        if other.is_constant():
            val = other.getint()
            if val >= 0:        # with Python's modulo:  0 <= (x % pos) < pos
                r.make_ge_const(0)
                r.make_lt_const(val)
            else:               # with Python's modulo:  neg < (x % neg) <= 0
                r.make_gt_const(val)
                r.make_le_const(0)
        return r

    def lshift_bound(self, other):
        if self.bounded() and other.bounded() and \
           other.known_nonnegative() and \
           other.known_lt_const(LONG_BIT):
            try:
                vals = (ovfcheck(self.upper << other.upper),
                        ovfcheck(self.upper << other.lower),
                        ovfcheck(self.lower << other.upper),
                        ovfcheck(self.lower << other.lower))
                return IntBound(min4(vals), max4(vals))
            except (OverflowError, ValueError):
                return IntUnbounded()
        else:
            return IntUnbounded()

    def rshift_bound(self, other):
        if self.bounded() and other.bounded() and \
           other.known_nonnegative() and \
           other.known_lt_const(LONG_BIT):
            vals = (self.upper >> other.upper,
                    self.upper >> other.lower,
                    self.lower >> other.upper,
                    self.lower >> other.lower)
            return IntBound(min4(vals), max4(vals))
        else:
            return IntUnbounded()

    def and_bound(self, other):
        pos1 = self.known_nonnegative()
        pos2 = other.known_nonnegative()
        r = IntUnbounded()
        if pos1 or pos2:
            r.make_ge_const(0)
        if pos1:
            r.make_le(self)
        if pos2:
            r.make_le(other)
        return r

    def or_bound(self, other):
        r = IntUnbounded()
        if self.known_nonnegative() and \
                other.known_nonnegative():
            if self.has_upper and other.has_upper:
                mostsignificant = self.upper | other.upper
                r.intersect(IntBound(0, next_pow2_m1(mostsignificant)))
            else:
                r.make_ge_const(0)
        return r

    def invert_bound(self):
        res = self.clone()
        res.has_upper = False
        if self.has_lower:
            res.upper = ~self.lower
            res.has_upper = True
        res.has_lower = False
        if self.has_upper:
            res.lower = ~self.upper
            res.has_lower = True
        return res

    def neg_bound(self):
        res = self.clone()
        res.has_upper = False
        if self.has_lower:
            try:
                res.upper = ovfcheck(-self.lower)
                res.has_upper = True
            except OverflowError:
                pass
        res.has_lower = False
        if self.has_upper:
            try:
                res.lower = ovfcheck(-self.upper)
                res.has_lower = True
            except OverflowError:
                pass
        return res

    def contains(self, val):
        if not we_are_translated():
            assert not isinstance(val, long)
        if not isinstance(val, int):
            if ((not self.has_lower or self.lower == MININT) and
                not self.has_upper or self.upper == MAXINT):
                return True # workaround for address as int
        if self.has_lower and val < self.lower:
            return False
        if self.has_upper and val > self.upper:
            return False
        return True

    def contains_bound(self, other):
        assert isinstance(other, IntBound)
        if other.has_lower:
            if not self.contains(other.lower):
                return False
        elif self.has_lower:
            return False
        if other.has_upper:
            if not self.contains(other.upper):
                return False
        elif self.has_upper:
            return False
        return True

    def __repr__(self):
        if self.has_lower:
            l = '%d' % self.lower
        else:
            l = '-Inf'
        if self.has_upper:
            u = '%d' % self.upper
        else:
            u = 'Inf'
        return '%s <= x <= %s' % (l, u)

    def clone(self):
        res = IntBound(self.lower, self.upper)
        res.has_lower = self.has_lower
        res.has_upper = self.has_upper
        return res

    def make_guards(self, box, guards, optimizer):
        if self.is_constant():
            guards.append(ResOperation(rop.GUARD_VALUE,
                                       [box, ConstInt(self.upper)]))
            return
        if self.has_lower and self.lower > MININT:
            bound = self.lower
            op = ResOperation(rop.INT_GE, [box, ConstInt(bound)])
            guards.append(op)
            op = ResOperation(rop.GUARD_TRUE, [op])
            guards.append(op)
        if self.has_upper and self.upper < MAXINT:
            bound = self.upper
            op = ResOperation(rop.INT_LE, [box, ConstInt(bound)])
            guards.append(op)
            op = ResOperation(rop.GUARD_TRUE, [op])
            guards.append(op)

    def is_bool(self):
        return (self.bounded() and self.known_nonnegative() and
                self.known_le_const(1))

    def make_bool(self):
        self.intersect(IntBound(0, 1))

    def getconst(self):
        if not self.is_constant():
            raise Exception("not a constant")
        return ConstInt(self.getint())

    def getnullness(self):
        if self.known_gt_const(0) or \
           self.known_lt_const(0):
            return INFO_NONNULL
        if self.known_nonnegative() and \
           self.known_le_const(0):
            return INFO_NULL
        return INFO_UNKNOWN

def IntUpperBound(upper):
    b = IntBound(lower=0, upper=upper)
    b.has_lower = False
    return b

def IntLowerBound(lower):
    b = IntBound(upper=0, lower=lower)
    b.has_upper = False
    return b

def IntUnbounded():
    b = IntBound(upper=0, lower=0)
    b.has_lower = False
    b.has_upper = False
    return b

def ConstIntBound(value):
    return IntBound(value, value)

def min4(t):
    return min(min(t[0], t[1]), min(t[2], t[3]))

def max4(t):
    return max(max(t[0], t[1]), max(t[2], t[3]))
