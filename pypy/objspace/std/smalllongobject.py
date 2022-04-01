"""Implementation of the int type based on r_longlong.

Useful for 32-bit applications manipulating values a bit larger than
fits in an 'int'.
"""
import operator

from rpython.rlib.rarithmetic import LONGLONG_BIT, intmask, r_longlong, r_uint
from rpython.rlib.rbigint import rbigint
from rpython.tool.sourcetools import func_renamer, func_with_new_name

from pypy.interpreter.error import oefmt
from pypy.interpreter.gateway import WrappedDefault, unwrap_spec
from pypy.objspace.std.intobject import W_IntObject
from pypy.objspace.std.longobject import W_AbstractLongObject, W_LongObject
from pypy.objspace.std.util import COMMUTATIVE_OPS

# XXX: breaks translation
#LONGLONG_MIN = r_longlong(-1 << (LONGLONG_BIT - 1))


class W_SmallLongObject(W_AbstractLongObject):

    _immutable_fields_ = ['longlong']

    def __init__(self, value):
        assert isinstance(value, r_longlong)
        self.longlong = value

    @staticmethod
    def fromint(value):
        return W_SmallLongObject(r_longlong(value))

    @staticmethod
    def frombigint(bigint):
        return W_SmallLongObject(bigint.tolonglong())

    def asbigint(self):
        return rbigint.fromrarith_int(self.longlong)

    def longval(self):
        return self.longlong

    def __repr__(self):
        return '<W_SmallLongObject(%d)>' % self.longlong

    def _int_w(self, space):
        a = self.longlong
        b = intmask(a)
        if b == a:
            return b
        raise oefmt(space.w_OverflowError,
                    "long int too large to convert to int")

    def uint_w(self, space):
        a = self.longlong
        if a < 0:
            raise oefmt(space.w_ValueError,
                        "cannot convert negative integer to unsigned int")
        b = r_uint(a)
        if r_longlong(b) == a:
            return b
        raise oefmt(space.w_OverflowError,
                    "long int too large to convert to unsigned int")

    def bigint_w(self, space, allow_conversion=True):
        return self.asbigint()

    def _bigint_w(self, space):
        return self.asbigint()

    def _float_w(self, space):
        return float(self.longlong)

    def int(self, space):
        if type(self) is W_SmallLongObject:
            return self
        if not space.is_overloaded(self, space.w_int, '__int__'):
            return W_LongObject(self.num)
        return W_Root.int(self, space)

    def descr_float(self, space):
        return space.newfloat(float(self.longlong))

    def descr_neg(self, space):
        a = self.longlong
        try:
            if a == r_longlong(-1 << (LONGLONG_BIT-1)):
                raise OverflowError
            x = -a
        except OverflowError:
            self = _small2long(space, self)
            return self.descr_neg(space)
        return W_SmallLongObject(x)

    def descr_abs(self, space):
        return self if self.longlong >= 0 else self.descr_neg(space)

    def descr_bool(self, space):
        return space.newbool(bool(self.longlong))

    def descr_invert(self, space):
        x = ~self.longlong
        return W_SmallLongObject(x)

    @unwrap_spec(w_modulus=WrappedDefault(None))
    def descr_pow(self, space, w_exponent, w_modulus=None):
        if isinstance(w_exponent, W_AbstractLongObject):
            self = _small2long(space, self)
            return self.descr_pow(space, w_exponent, w_modulus)
        elif not isinstance(w_exponent, W_IntObject):
            return space.w_NotImplemented

        x = self.longlong
        y = space.int_w(w_exponent)

        if space.is_none(w_modulus):
            try:
                return _pow(space, x, y, r_longlong(0))
            except ValueError:
                self = self.descr_float(space)
                return space.pow(self, w_exponent, space.w_None)
            except OverflowError:
                self = _small2long(space, self)
                return self.descr_pow(space, w_exponent, w_modulus)
        elif isinstance(w_modulus, W_IntObject):
            w_modulus = w_modulus.as_w_long(space)
        elif not isinstance(w_modulus, W_AbstractLongObject):
            return space.w_NotImplemented
        elif not isinstance(w_modulus, W_SmallLongObject):
            self = _small2long(space, self)
            return self.descr_pow(space, w_exponent, w_modulus)

        z = w_modulus.longlong
        if z == 0:
            raise oefmt(space.w_ValueError, "pow() 3rd argument cannot be 0")
        if y < 0:
            # don't implement with smalllong
            self = _small2long(space, self)
            return self.descr_pow(space, w_exponent, w_modulus)
        try:
            return _pow(space, x, y, z)
        except ValueError:
            self = self.descr_float(space)
            return space.pow(self, w_exponent, w_modulus)
        except OverflowError:
            self = _small2long(space, self)
            return self.descr_pow(space, w_exponent, w_modulus)

    @unwrap_spec(w_modulus=WrappedDefault(None))
    def descr_rpow(self, space, w_base, w_modulus=None):
        if isinstance(w_base, W_IntObject):
            # Defer to w_base<W_SmallLongObject>.descr_pow
            w_base = w_base.descr_long(space)
        elif not isinstance(w_base, W_AbstractLongObject):
            return space.w_NotImplemented
        return w_base.descr_pow(space, self, w_modulus)

    def _make_descr_cmp(opname):
        op = getattr(operator, opname)
        bigint_op = getattr(rbigint, opname)
        @func_renamer('descr_' + opname)
        def descr_cmp(self, space, w_other):
            if isinstance(w_other, W_IntObject):
                result = op(self.longlong, w_other.int_w(space))
            elif not isinstance(w_other, W_AbstractLongObject):
                return space.w_NotImplemented
            elif isinstance(w_other, W_SmallLongObject):
                result = op(self.longlong, w_other.longlong)
            else:
                result = bigint_op(self.asbigint(), w_other.asbigint())
            return space.newbool(result)
        return descr_cmp

    descr_lt = _make_descr_cmp('lt')
    descr_le = _make_descr_cmp('le')
    descr_eq = _make_descr_cmp('eq')
    descr_ne = _make_descr_cmp('ne')
    descr_gt = _make_descr_cmp('gt')
    descr_ge = _make_descr_cmp('ge')

    def _make_descr_binop(func, ovf=True):
        opname = func.__name__[1:]
        descr_name, descr_rname = 'descr_' + opname, 'descr_r' + opname
        long_op = getattr(W_LongObject, descr_name)

        @func_renamer(descr_name)
        def descr_binop(self, space, w_other):
            if isinstance(w_other, W_IntObject):
                w_other = w_other.as_w_long(space)
            elif not isinstance(w_other, W_AbstractLongObject):
                return space.w_NotImplemented
            elif not isinstance(w_other, W_SmallLongObject):
                self = _small2long(space, self)
                return long_op(self, space, w_other)

            if ovf:
                try:
                    return func(self, space, w_other)
                except OverflowError:
                    self = _small2long(space, self)
                    w_other = _small2long(space, w_other)
                    return long_op(self, space, w_other)
            else:
                return func(self, space, w_other)

        if opname in COMMUTATIVE_OPS:
            @func_renamer(descr_rname)
            def descr_rbinop(self, space, w_other):
                return descr_binop(self, space, w_other)
            return descr_binop, descr_rbinop

        long_rop = getattr(W_LongObject, descr_rname)
        @func_renamer(descr_rname)
        def descr_rbinop(self, space, w_other):
            if isinstance(w_other, W_IntObject):
                w_other = w_other.as_w_long(space)
            elif not isinstance(w_other, W_AbstractLongObject):
                return space.w_NotImplemented
            elif not isinstance(w_other, W_SmallLongObject):
                self = _small2long(space, self)
                return long_rop(self, space, w_other)

            if ovf:
                try:
                    return func(w_other, space, self)
                except OverflowError:
                    self = _small2long(space, self)
                    w_other = _small2long(space, w_other)
                    return long_rop(self, space, w_other)
            else:
                return func(w_other, space, self)

        return descr_binop, descr_rbinop

    def _add(self, space, w_other):
        x = self.longlong
        y = w_other.longlong
        z = x + y
        if ((z ^ x) & (z ^ y)) < 0:
            raise OverflowError
        return W_SmallLongObject(z)
    descr_add, descr_radd = _make_descr_binop(_add)

    def _sub(self, space, w_other):
        x = self.longlong
        y = w_other.longlong
        z = x - y
        if ((z ^ x) & (z ^ ~y)) < 0:
            raise OverflowError
        return W_SmallLongObject(z)
    descr_sub, descr_rsub = _make_descr_binop(_sub)

    def _mul(self, space, w_other):
        x = self.longlong
        y = w_other.longlong
        z = _llong_mul_ovf(x, y)
        return W_SmallLongObject(z)
    descr_mul, descr_rmul = _make_descr_binop(_mul)

    def _floordiv(self, space, w_other):
        x = self.longlong
        y = w_other.longlong
        try:
            if y == -1 and x == r_longlong(-1 << (LONGLONG_BIT-1)):
                raise OverflowError
            z = x // y
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError, "integer division by zero")
        return W_SmallLongObject(z)
    descr_floordiv, descr_rfloordiv = _make_descr_binop(_floordiv)

    def _mod(self, space, w_other):
        x = self.longlong
        y = w_other.longlong
        try:
            if y == -1 and x == r_longlong(-1 << (LONGLONG_BIT-1)):
                raise OverflowError
            z = x % y
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError, "integer modulo by zero")
        return W_SmallLongObject(z)
    descr_mod, descr_rmod = _make_descr_binop(_mod)

    def _divmod(self, space, w_other):
        x = self.longlong
        y = w_other.longlong
        try:
            if y == -1 and x == r_longlong(-1 << (LONGLONG_BIT-1)):
                raise OverflowError
            z = x // y
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError, "integer divmod by zero")
        # no overflow possible
        m = x % y
        return space.newtuple([W_SmallLongObject(z), W_SmallLongObject(m)])
    descr_divmod, descr_rdivmod = _make_descr_binop(_divmod)

    def _lshift(self, space, w_other):
        a = self.longlong
        # May overflow
        b = space.int_w(w_other)
        if r_uint(b) < LONGLONG_BIT: # 0 <= b < LONGLONG_BIT
            c = a << b
            if a != (c >> b):
                raise OverflowError
            return W_SmallLongObject(c)
        if b < 0:
            raise oefmt(space.w_ValueError, "negative shift count")
        # b >= LONGLONG_BIT
        if a == 0:
            return self
        raise OverflowError
    descr_lshift, descr_rlshift = _make_descr_binop(_lshift)

    def _rshift(self, space, w_other):
        a = self.longlong
        # May overflow
        b = space.int_w(w_other)
        if r_uint(b) >= LONGLONG_BIT: # not (0 <= b < LONGLONG_BIT)
            if b < 0:
                raise oefmt(space.w_ValueError, "negative shift count")
            # b >= LONGLONG_BIT
            if a == 0:
                return self
            a = -1 if a < 0 else 0
        else:
            a = a >> b
        return W_SmallLongObject(a)
    descr_rshift, descr_rrshift = _make_descr_binop(_rshift, ovf=False)

    def _and(self, space, w_other):
        a = self.longlong
        b = w_other.longlong
        res = a & b
        return W_SmallLongObject(res)
    descr_and, descr_rand = _make_descr_binop(_and, ovf=False)

    def _or(self, space, w_other):
        a = self.longlong
        b = w_other.longlong
        res = a | b
        return W_SmallLongObject(res)
    descr_or, descr_ror = _make_descr_binop(_or, ovf=False)

    def _xor(self, space, w_other):
        a = self.longlong
        b = w_other.longlong
        res = a ^ b
        return W_SmallLongObject(res)
    descr_xor, descr_rxor = _make_descr_binop(_xor, ovf=False)


def _llong_mul_ovf(a, b):
    # xxx duplication of the logic from translator/c/src/int.h
    longprod = a * b
    doubleprod = float(a) * float(b)
    doubled_longprod = float(longprod)

    # Fast path for normal case:  small multiplicands, and no info
    # is lost in either method.
    if doubled_longprod == doubleprod:
        return longprod

    # Somebody somewhere lost info.  Close enough, or way off?  Note
    # that a != 0 and b != 0 (else doubled_longprod == doubleprod == 0).
    # The difference either is or isn't significant compared to the
    # true value (of which doubleprod is a good approximation).
    diff = doubled_longprod - doubleprod
    absdiff = abs(diff)
    absprod = abs(doubleprod)
    # absdiff/absprod <= 1/32 iff
    # 32 * absdiff <= absprod -- 5 good bits is "close enough"
    if 32.0 * absdiff <= absprod:
        return longprod
    raise OverflowError("integer multiplication")


def _small2long(space, w_small):
    return W_LongObject(w_small.asbigint())


def _pow(space, iv, iw, iz):
    if iw < 0:
        if iz != 0:
            raise oefmt(space.w_ValueError,
                        "pow() 2nd argument cannot be negative when 3rd "
                        "argument specified")
        raise ValueError
    temp = iv
    ix = r_longlong(1)
    while iw > 0:
        if iw & 1:
            ix = _llong_mul_ovf(ix, temp)
        iw >>= 1   # Shift exponent down by 1 bit
        if iw == 0:
            break
        temp = _llong_mul_ovf(temp, temp) # Square the value of temp
        if iz:
            # If we did a multiplication, perform a modulo
            ix %= iz
            temp %= iz
    if iz:
        ix %= iz
    return W_SmallLongObject(ix)
