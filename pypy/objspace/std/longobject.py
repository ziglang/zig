"""The builtin int type based on rbigint (the old long type)"""

import functools

from rpython.rlib.objectmodel import specialize
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.rbigint import SHIFT, _load_unsigned_digit, rbigint
from rpython.tool.sourcetools import func_renamer, func_with_new_name

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import oefmt
from pypy.interpreter.gateway import WrappedDefault, unwrap_spec
from pypy.objspace.std import newformat
from pypy.objspace.std.intobject import (
    HASH_BITS, HASH_MODULUS, W_AbstractIntObject, W_IntObject)
from pypy.objspace.std.util import (
    BINARY_OPS, CMP_OPS, COMMUTATIVE_OPS, IDTAG_LONG, IDTAG_SHIFT, wrap_parsestringerror)


def delegate_other(func):
    @functools.wraps(func)
    def delegated(self, space, w_other):
        if isinstance(w_other, W_IntObject):
            w_other = w_other.as_w_long(space)
        elif not isinstance(w_other, W_AbstractLongObject):
            return space.w_NotImplemented
        return func(self, space, w_other)
    return delegated


class W_AbstractLongObject(W_AbstractIntObject):

    __slots__ = ()

    def unwrap(self, space):
        return self.longval()

    def int(self, space):
        raise NotImplementedError

    def asbigint(self):
        raise NotImplementedError

    def descr_getnewargs(self, space):
        return space.newtuple([newlong(space, self.asbigint())])

    def descr_bit_length(self, space):
        bigint = space.bigint_w(self)
        try:
            return space.newint(bigint.bit_length())
        except OverflowError:
            raise oefmt(space.w_OverflowError, "too many digits in integer")

    def _truediv(self, space, w_other):
        try:
            f = self.asbigint().truediv(w_other.asbigint())
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError, "division by zero")
        except OverflowError:
            raise oefmt(space.w_OverflowError,
                        "integer division result too large for a float")
        return space.newfloat(f)

    @delegate_other
    def descr_truediv(self, space, w_other):
        return W_AbstractLongObject._truediv(self, space, w_other)

    @delegate_other
    def descr_rtruediv(self, space, w_other):
        return W_AbstractLongObject._truediv(w_other, space, self)

    def descr_format(self, space, w_format_spec):
        return newformat.run_formatter(space, w_format_spec,
                                       "format_int_or_long", self,
                                       newformat.LONG_KIND)

    def descr_hash(self, space):
        return space.newint(_hash_long(space, self.asbigint()))

    def descr_str(self, space):
        res = self.asbigint().str()
        return space.newutf8(res, len(res))
    descr_repr = descr_str


class W_LongObject(W_AbstractLongObject):
    """This is a wrapper of rbigint."""

    _immutable_fields_ = ['num']

    def __init__(self, num):
        self.num = num # instance of rbigint

    @staticmethod
    def fromint(space, intval):
        return W_LongObject(rbigint.fromint(intval))

    def longval(self):
        return self.num.tolong()

    def tofloat(self, space):
        try:
            return self.num.tofloat()
        except OverflowError:
            raise oefmt(space.w_OverflowError,
                        "int too large to convert to float")

    def toint(self):
        return self.num.toint()

    def _fits_int(self):
        return self.num.fits_int()

    @staticmethod
    def fromfloat(space, f):
        return newlong(space, rbigint.fromfloat(f))

    @staticmethod
    def fromlong(l):
        return W_LongObject(rbigint.fromlong(l))

    @staticmethod
    @specialize.argtype(0)
    def fromrarith_int(i):
        return W_LongObject(rbigint.fromrarith_int(i))

    def _int_w(self, space):
        try:
            return self.num.toint()
        except OverflowError:
            raise oefmt(space.w_OverflowError,
                        "int too large to convert to int")

    def uint_w(self, space):
        try:
            return self.num.touint()
        except ValueError:
            raise oefmt(space.w_ValueError,
                        "cannot convert negative integer to unsigned int")
        except OverflowError:
            raise oefmt(space.w_OverflowError,
                        "int too large to convert to unsigned int")

    def bigint_w(self, space, allow_conversion=True):
        return self.num

    def _bigint_w(self, space):
        return self.num

    def float_w(self, space, allow_conversion=True):
        return self.tofloat(space)

    def _float_w(self, space):
        return self.tofloat(space)

    def int(self, space):
        if type(self) is W_LongObject:
            return self
        if not space.is_overloaded(self, space.w_int, '__int__'):
            return W_LongObject(self.num)
        return W_Root.int(self, space)

    def asbigint(self):
        return self.num

    def __repr__(self):
        return '<W_LongObject(%d)>' % self.num.tolong()

    def descr_float(self, space):
        return space.newfloat(self.tofloat(space))

    def descr_bool(self, space):
        return space.newbool(self.num.tobool())

    @unwrap_spec(w_modulus=WrappedDefault(None))
    def descr_pow(self, space, w_exponent, w_modulus=None):
        from pypy.objspace.std.intobject import invmod
        if isinstance(w_exponent, W_IntObject):
            w_exponent = w_exponent.as_w_long(space)
        elif not isinstance(w_exponent, W_AbstractLongObject):
            return space.w_NotImplemented

        exponent = w_exponent.asbigint()
        if space.is_none(w_modulus):
            if exponent.sign < 0:
                self = self.descr_float(space)
                w_exponent = w_exponent.descr_float(space)
                return space.pow(self, w_exponent, space.w_None)
            return W_LongObject(self.num.pow(exponent))
        elif isinstance(w_modulus, W_IntObject):
            w_modulus = w_modulus.as_w_long(space)
        elif not isinstance(w_modulus, W_AbstractLongObject):
            return space.w_NotImplemented

        base = self.num
        if exponent.sign < 0:
            w_base = invmod(space, self, space.abs(w_modulus))
            if isinstance(w_base, W_IntObject):
                w_base = w_base.as_w_long(space)
            base = w_base.asbigint()

            exponent = exponent.neg()
        try:
            result = base.pow(exponent, w_modulus.asbigint())
        except ValueError:
            raise oefmt(space.w_ValueError, "pow 3rd argument cannot be 0")
        return W_LongObject(result)

    @unwrap_spec(w_modulus=WrappedDefault(None))
    def descr_rpow(self, space, w_base, w_modulus=None):
        if isinstance(w_base, W_IntObject):
            w_base = w_base.as_w_long(space)
        elif not isinstance(w_base, W_AbstractLongObject):
            return space.w_NotImplemented
        return w_base.descr_pow(space, self, w_modulus)

    def _make_descr_unaryop(opname):
        op = getattr(rbigint, opname)
        @func_renamer('descr_' + opname)
        def descr_unaryop(self, space):
            return W_LongObject(op(self.num))
        return descr_unaryop

    descr_neg = _make_descr_unaryop('neg')
    descr_abs = _make_descr_unaryop('abs')
    descr_invert = _make_descr_unaryop('invert')

    def _make_descr_cmp(opname):
        op = getattr(rbigint, opname)
        intop = getattr(rbigint, "int_" + opname)

        def descr_impl(self, space, w_other):
            if isinstance(w_other, W_IntObject):
                return space.newbool(intop(self.num, w_other.int_w(space)))
            elif not isinstance(w_other, W_AbstractLongObject):
                return space.w_NotImplemented
            return space.newbool(op(self.num, w_other.asbigint()))
        return func_with_new_name(descr_impl, "descr_" + opname)

    descr_lt = _make_descr_cmp('lt')
    descr_le = _make_descr_cmp('le')
    descr_eq = _make_descr_cmp('eq')
    descr_ne = _make_descr_cmp('ne')
    descr_gt = _make_descr_cmp('gt')
    descr_ge = _make_descr_cmp('ge')

    def descr_sub(self, space, w_other):
        if isinstance(w_other, W_IntObject):
            return W_LongObject(self.num.int_sub(w_other.int_w(space)))
        elif not isinstance(w_other, W_AbstractLongObject):
            return space.w_NotImplemented
        return W_LongObject(self.num.sub(w_other.asbigint()))

    @delegate_other
    def descr_rsub(self, space, w_other):
        return W_LongObject(w_other.asbigint().sub(self.num))

    def _make_generic_descr_binop(opname):
        if opname not in COMMUTATIVE_OPS:
            raise Exception("Not supported")

        methname = opname + '_' if opname in ('and', 'or') else opname
        descr_rname = 'descr_r' + opname
        op = getattr(rbigint, methname)
        intop = getattr(rbigint, "int_" + methname)

        @func_renamer('descr_' + opname)
        def descr_binop(self, space, w_other):
            if isinstance(w_other, W_IntObject):
                return W_LongObject(intop(self.num, w_other.int_w(space)))
            elif not isinstance(w_other, W_AbstractLongObject):
                return space.w_NotImplemented

            return W_LongObject(op(self.num, w_other.asbigint()))

        @func_renamer(descr_rname)
        def descr_rbinop(self, space, w_other):
            if isinstance(w_other, W_IntObject):
                return W_LongObject(intop(self.num, w_other.int_w(space)))
            elif not isinstance(w_other, W_AbstractLongObject):
                return space.w_NotImplemented

            return W_LongObject(op(w_other.asbigint(), self.num))

        return descr_binop, descr_rbinop

    descr_add, descr_radd = _make_generic_descr_binop('add')

    descr_mul, descr_rmul = _make_generic_descr_binop('mul')
    descr_and, descr_rand = _make_generic_descr_binop('and')
    descr_or, descr_ror = _make_generic_descr_binop('or')
    descr_xor, descr_rxor = _make_generic_descr_binop('xor')

    def _make_descr_binop(func, int_func):
        opname = func.__name__[1:]

        @func_renamer('descr_' + opname)
        def descr_binop(self, space, w_other):
            if isinstance(w_other, W_IntObject):
                return int_func(self, space, w_other.int_w(space))
            elif not isinstance(w_other, W_AbstractLongObject):
                return space.w_NotImplemented
            return func(self, space, w_other)

        @delegate_other
        @func_renamer('descr_r' + opname)
        def descr_rbinop(self, space, w_other):
            if not isinstance(w_other, W_LongObject):
                # coerce other W_AbstractLongObjects
                w_other = W_LongObject(w_other.asbigint())
            return func(w_other, space, self)

        return descr_binop, descr_rbinop

    def _lshift(self, space, w_other):
        if w_other.asbigint().sign < 0:
            raise oefmt(space.w_ValueError, "negative shift count")
        try:
            shift = w_other.asbigint().toint()
        except OverflowError:   # b too big
            if self.num.sign == 0:
                return self
            raise oefmt(space.w_OverflowError, "shift count too large")
        return W_LongObject(self.num.lshift(shift))

    def _int_lshift(self, space, other):
        if other < 0:
            raise oefmt(space.w_ValueError, "negative shift count")
        return W_LongObject(self.num.lshift(other))

    descr_lshift, descr_rlshift = _make_descr_binop(_lshift, _int_lshift)

    def _rshift(self, space, w_other):
        if w_other.asbigint().sign < 0:
            raise oefmt(space.w_ValueError, "negative shift count")
        try:
            shift = w_other.asbigint().toint()
        except OverflowError:
            if self.num.sign < 0:
                return space.newint(-1)
            return space.newint(0)
            raise oefmt(space.w_OverflowError, "shift count too large")
        return newlong(space, self.num.rshift(shift))

    def _int_rshift(self, space, other):
        if other < 0:
            raise oefmt(space.w_ValueError, "negative shift count")

        return newlong(space, self.num.rshift(other))
    descr_rshift, descr_rrshift = _make_descr_binop(_rshift, _int_rshift)

    def _floordiv(self, space, w_other):
        try:
            z = self.num.floordiv(w_other.asbigint())
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError,
                        "long division or modulo by zero")
        return newlong(space, z)

    def _int_floordiv(self, space, other):
        try:
            z = self.num.int_floordiv(other)
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError,
                        "integer division or modulo by zero")
        return newlong(space, z)
    descr_floordiv, descr_rfloordiv = _make_descr_binop(_floordiv, _int_floordiv)

    def _mod(self, space, w_other):
        try:
            z = self.num.mod(w_other.asbigint())
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError,
                        "integer division or modulo by zero")
        return newlong(space, z)

    def _int_mod(self, space, other):
        try:
            z = self.num.int_mod_int_result(other)
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError,
                        "long division or modulo by zero")
        return space.newint(z)
    descr_mod, descr_rmod = _make_descr_binop(_mod, _int_mod)

    def _divmod(self, space, w_other):
        try:
            div, mod = self.num.divmod(w_other.asbigint())
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError,
                        "integer division or modulo by zero")
        return space.newtuple([newlong(space, div), newlong(space, mod)])

    def _int_divmod(self, space, other):
        try:
            div, mod = self.num.int_divmod(other)
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError,
                        "long division or modulo by zero")
        return space.newtuple([newlong(space, div), newlong(space, mod)])

    descr_divmod, descr_rdivmod = _make_descr_binop(_divmod, _int_divmod)


# In _hash_long we would like to shift intermediate results by SHIFT.
# Since HASH_MODULUS is a Mersenne prime, the result is congruent
# to shifting by (SHIFT % HASH_BITS).  A smaller shift amount lets
# us apply extra optimizations to the hash function.
_HASH_SHIFT = SHIFT % HASH_BITS

def _hash_long(space, v):
    i = v.numdigits() - 1
    if i == -1:
        return 0

    # compute v % HASH_MODULUS
    x = _load_unsigned_digit(0)
    while i >= 0:
        # This computes (x << _HASH_SHIFT) + v.udigit(i) modulo HASH_MODULUS
        # efficiently and without overflow, as HASH_MODULUS is a Mersenne
        # prime.  See detailed explanation in CPython function long_hash
        # in longobject.c.
        # Basically, to compute (x << _HASH_SHIFT) modulo HASH_MODULUS,
        # we rotate it left by _HASH_SHIFT.  Then, if SHIFT <= HASH_BITS,
        # after adding v.udigit(i), the result is at most 2*HASH_MODULUS-1.
        x = ((x << _HASH_SHIFT) & HASH_MODULUS) + (x >> HASH_BITS - _HASH_SHIFT)
        x += v.udigit(i)
        if SHIFT > HASH_BITS:
            x = (x & HASH_MODULUS) + (x >> HASH_BITS)
        if x >= HASH_MODULUS:
            x -= HASH_MODULUS
        i -= 1
    h = intmask(intmask(x) * v.sign)
    return h - (h == -1)


def newlong(space, bigint):
    """Turn the bigint into a W_LongObject.  If withsmalllong is
    enabled, check if the bigint would fit in a smalllong, and return a
    W_SmallLongObject instead if it does.
    """
    if space.config.objspace.std.withsmalllong:
        try:
            z = bigint.tolonglong()
        except OverflowError:
            pass
        else:
            from pypy.objspace.std.smalllongobject import W_SmallLongObject
            return W_SmallLongObject(z)
    return W_LongObject(bigint)


def newlong_from_float(space, floatval):
    """Return a W_LongObject from an RPython float.

    Raises app-level exceptions on failure.
    """
    try:
        return W_LongObject.fromfloat(space, floatval)
    except OverflowError:
        raise oefmt(space.w_OverflowError,
                    "cannot convert float infinity to integer")
    except ValueError:
        raise oefmt(space.w_ValueError, "cannot convert float NaN to integer")


def newbigint(space, w_longtype, bigint):
    """Turn the bigint into a W_LongObject.  If withsmalllong is enabled,
    check if the bigint would fit in a smalllong, and return a
    W_SmallLongObject instead if it does.  Similar to newlong() in
    longobject.py, but takes an explicit w_longtype argument.
    """
    if (space.config.objspace.std.withsmalllong
        and space.is_w(w_longtype, space.w_int)):
        try:
            z = bigint.tolonglong()
        except OverflowError:
            pass
        else:
            from pypy.objspace.std.smalllongobject import W_SmallLongObject
            return W_SmallLongObject(z)
    w_obj = space.allocate_instance(W_LongObject, w_longtype)
    W_LongObject.__init__(w_obj, bigint)
    return w_obj
