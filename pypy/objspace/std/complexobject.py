import math

from rpython.rlib import jit, rcomplex
from rpython.rlib.rarithmetic import intmask, r_ulonglong
from rpython.rlib.rbigint import rbigint
from rpython.rlib.rfloat import (
    DTSF_STR_PRECISION, formatd, string_to_float)
from rpython.rlib.rstring import ParseStringError
from rpython.tool.sourcetools import func_with_new_name

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import WrappedDefault, interp2app, unwrap_spec
from pypy.interpreter.typedef import GetSetProperty, TypeDef
from pypy.objspace.std import newformat
from pypy.objspace.std.floatobject import _hash_float, _remove_underscores
from pypy.objspace.std.unicodeobject import unicode_to_decimal_w

HASH_IMAG = 1000003


def _split_complex(s):
    slen = len(s)
    if slen == 0:
        raise ValueError
    realstart = 0
    realstop = 0
    imagstart = 0
    imagstop = 0
    imagsign = ' '
    i = 0
    # ignore whitespace at beginning and end
    while i < slen and s[i] == ' ':
        i += 1
    while slen > 0 and s[slen-1] == ' ':
        slen -= 1

    if s[i] == '(' and s[slen-1] == ')':
        i += 1
        slen -= 1
        # ignore whitespace after bracket
        while i < slen and s[i] == ' ':
            i += 1
        while slen > 0 and s[slen-1] == ' ':
            slen -= 1

    # extract first number
    realstart = i
    pc = s[i]
    while i < slen and s[i] != ' ':
        if s[i] in ('+', '-') and pc not in ('e', 'E') and i != realstart:
            break
        pc = s[i]
        i += 1

    realstop = i

    # return appropriate strings is only one number is there
    if i >= slen:
        newstop = realstop - 1
        if newstop < 0:
            raise ValueError
        if s[newstop] in ('j', 'J'):
            if realstart == newstop:
                imagpart = '1.0'
            elif realstart == newstop-1 and s[realstart] == '+':
                imagpart = '1.0'
            elif realstart == newstop-1 and s[realstart] == '-':
                imagpart = '-1.0'
            else:
                imagpart = s[realstart:newstop]
            return '0.0', imagpart
        else:
            return s[realstart:realstop], '0.0'

    # find sign for imaginary part
    if s[i] == '-' or s[i] == '+':
        imagsign = s[i]
    else:
        raise ValueError

    i += 1
    if i >= slen:
        raise ValueError

    imagstart = i
    pc = s[i]
    while i < slen and s[i] != ' ':
        if s[i] in ('+', '-') and pc not in ('e', 'E'):
            break
        pc = s[i]
        i += 1

    imagstop = i - 1
    if imagstop < 0:
        raise ValueError
    if s[imagstop] not in ('j', 'J'):
        raise ValueError
    if imagstop < imagstart:
        raise ValueError

    if i < slen:
        raise ValueError

    realpart = s[realstart:realstop]
    if imagstart == imagstop:
        imagpart = '1.0'
    else:
        imagpart = s[imagstart:imagstop]
    if imagsign == '-':
        imagpart = imagsign + imagpart

    return realpart, imagpart


def format_float(x, code, precision):
    # like float2string, except that the ".0" is not necessary
    if math.isinf(x):
        if x > 0.0:
            return "inf"
        else:
            return "-inf"
    elif math.isnan(x):
        return "nan"
    else:
        return formatd(x, code, precision)

def repr_format(x):
    return format_float(x, 'r', 0)

def str_format(x):
    return format_float(x, 'g', DTSF_STR_PRECISION)


def unpackcomplex(space, w_complex, strict_typing=True, firstarg=True):
    """
    convert w_complex into a complex and return the unwrapped (real, imag)
    tuple. If strict_typing==True, we also typecheck the value returned by
    __complex__ to actually be a complex (and not e.g. a float).
    See test___complex___returning_non_complex.
    """
    if type(w_complex) is W_ComplexObject:
        return (w_complex.realval, w_complex.imagval)
    #
    # test for a '__complex__' method, and call it if found.
    w_z = None
    w_method = space.lookup(w_complex, '__complex__')
    if w_method is not None:
        w_z = space.get_and_call_function(w_method, w_complex)
    #
    if w_z is not None:
        # __complex__() must return a complex
        # (XXX should not use isinstance here)
        if isinstance(w_z, W_ComplexObject):
            if type(w_z) is not W_ComplexObject:
                space.warn(
                    space.newtext("__complex__ returned non-complex (type %s).  The ability to return an instance of a strict subclass of complex is deprecated, and may be removed in a future version of Python." % (space.type(w_z).getname(space))),
                    space.w_DeprecationWarning
                )
            return (w_z.realval, w_z.imagval)
        raise oefmt(space.w_TypeError,
                    "__complex__() must return a complex number")

    # try to see whether it has an __index__
    if space.lookup(w_complex, '__index__') is not None:
        result = space.float_w(space.float(space.index(w_complex)))
        return (result, 0.0)

    #
    # no '__complex__' method, so we assume it is a float,
    # unless it is an instance of some subclass of complex.
    if space.isinstance_w(w_complex, space.gettypefor(W_ComplexObject)):
        real = space.float(space.getattr(w_complex, space.newtext("real")))
        imag = space.float(space.getattr(w_complex, space.newtext("imag")))
        return (space.float_w(real), space.float_w(imag))
    #
    # Check that it is not a string (on which space.float() would succeed).
    if (space.isinstance_w(w_complex, space.w_bytes) or
        space.isinstance_w(w_complex, space.w_unicode)):
        raise oefmt(space.w_TypeError,
                    "complex number expected, got '%T'", w_complex)
    #
    try:
        return (space.float_w(space.float(w_complex)), 0.0)
    except OperationError as e:
        if not e.match(space, space.w_TypeError):
            raise
        if firstarg:
            raise oefmt(space.w_TypeError,
                        "complex() first argument must be a string or a number, not '%T'",
                         w_complex)
        else:
            raise oefmt(space.w_TypeError,
                        "complex() second argument must be a number, not '%T'",
                         w_complex)



class W_ComplexObject(W_Root):
    _immutable_fields_ = ['realval', 'imagval']

    def __init__(self, realval=0.0, imgval=0.0):
        self.realval = float(realval)
        self.imagval = float(imgval)

    def unwrap(self, space):   # for tests only
        return complex(self.realval, self.imagval)

    def __repr__(self):
        """ representation for debugging purposes """
        return "<W_ComplexObject(%f, %f)>" % (self.realval, self.imagval)

    def as_tuple(self):
        return (self.realval, self.imagval)

    def sub(self, other):
        return W_ComplexObject(self.realval - other.realval,
                               self.imagval - other.imagval)

    def mul(self, other):
        r = self.realval * other.realval - self.imagval * other.imagval
        i = self.realval * other.imagval + self.imagval * other.realval
        return W_ComplexObject(r, i)

    def div(self, other):
        rr, ir = rcomplex.c_div(self.as_tuple(), other.as_tuple())
        return W_ComplexObject(rr, ir)

    def pow(self, other):
        rr, ir = rcomplex.c_pow(self.as_tuple(), other.as_tuple())
        return W_ComplexObject(rr, ir)

    def pow_small_int(self, n):
        if n >= 0:
            if jit.isconstant(n) and n == 2:
                return self.mul(self)
            return self.pow_positive_int(n)
        else:
            return w_one.div(self.pow_positive_int(-n))

    def pow_positive_int(self, n):
        mask = 1
        w_result = w_one
        while mask > 0 and n >= mask:
            if n & mask:
                w_result = w_result.mul(self)
            mask <<= 1
            self = self.mul(self)

        return w_result

    def is_w(self, space, w_other):
        from rpython.rlib.longlong2float import float2longlong
        if not isinstance(w_other, W_ComplexObject):
            return False
        if self.user_overridden_class or w_other.user_overridden_class:
            return self is w_other
        real1 = space.float_w(space.getattr(self, space.newtext("real")))
        real2 = space.float_w(space.getattr(w_other, space.newtext("real")))
        imag1 = space.float_w(space.getattr(self, space.newtext("imag")))
        imag2 = space.float_w(space.getattr(w_other, space.newtext("imag")))
        real1 = float2longlong(real1)
        real2 = float2longlong(real2)
        imag1 = float2longlong(imag1)
        imag2 = float2longlong(imag2)
        return real1 == real2 and imag1 == imag2

    def immutable_unique_id(self, space):
        if self.user_overridden_class:
            return None
        from rpython.rlib.longlong2float import float2longlong
        from pypy.objspace.std.util import IDTAG_COMPLEX as tag
        from pypy.objspace.std.util import IDTAG_SHIFT
        real = space.float_w(space.getattr(self, space.newtext("real")))
        imag = space.float_w(space.getattr(self, space.newtext("imag")))
        real_b = rbigint.fromrarith_int(float2longlong(real))
        imag_b = rbigint.fromrarith_int(r_ulonglong(float2longlong(imag)))
        val = real_b.lshift(64).or_(imag_b).lshift(IDTAG_SHIFT).int_or_(tag)
        return space.newlong_from_rbigint(val)

    def descr_int(self, space):
        raise oefmt(space.w_TypeError, "can't convert complex to int")

    def _to_complex(self, space, w_obj):
        if isinstance(w_obj, W_ComplexObject):
            return w_obj
        if space.isinstance_w(w_obj, space.w_int):
            w_float = space.float_w(w_obj)
            return W_ComplexObject(w_float, 0.0)
        if space.isinstance_w(w_obj, space.w_float):
            return W_ComplexObject(space.float_w(w_obj), 0.0)

    @staticmethod
    @unwrap_spec(w_real=WrappedDefault(0.0))
    def descr__new__(space, w_complextype, w_real, w_imag=None):
        # if w_real is already a complex number and there is no second
        # argument, return it.  Note that we cannot return w_real if
        # it is an instance of a *subclass* of complex, or if w_complextype
        # is itself a subclass of complex.
        noarg2 = w_imag is None
        if (noarg2 and space.is_w(w_complextype, space.w_complex)
            and space.is_w(space.type(w_real), space.w_complex)):
            return w_real

        if space.isinstance_w(w_real, space.w_text):
            # a string argument
            if not noarg2:
                raise oefmt(space.w_TypeError, "complex() can't take second"
                                               " arg if first is a string")
            unistr = unicode_to_decimal_w(space, w_real)
            try:
                unistr = _remove_underscores(unistr)
            except ValueError:
                raise oefmt(space.w_ValueError,
                            "complex() arg is a malformed string")
            try:
                realstr, imagstr = _split_complex(unistr)
            except ValueError:
                raise oefmt(space.w_ValueError,
                            "complex() arg is a malformed string")
            try:
                realval = string_to_float(realstr)
                imagval = string_to_float(imagstr)
            except ParseStringError:
                raise oefmt(space.w_ValueError,
                            "complex() arg is a malformed string")

        else:
            # non-string arguments
            realval, imagval = unpackcomplex(space, w_real)

            # now take w_imag into account
            if not noarg2:
                # complex(x, y) == x+y*j, even if 'y' is already a complex.
                realval2, imagval2 = unpackcomplex(space, w_imag,
                                                   firstarg=False)

                # try to preserve the signs of zeroes of realval and realval2
                if imagval2 != 0.0:
                    realval -= imagval2

                if imagval != 0.0:
                    imagval += realval2
                else:
                    imagval = realval2
        # done
        w_obj = space.allocate_instance(W_ComplexObject, w_complextype)
        W_ComplexObject.__init__(w_obj, realval, imagval)
        return w_obj

    def descr___getnewargs__(self, space):
        return space.newtuple([space.newfloat(self.realval),
                               space.newfloat(self.imagval)])

    def descr_repr(self, space):
        if self.realval == 0 and math.copysign(1., self.realval) == 1.:
            return space.newtext(repr_format(self.imagval) + 'j')
        sign = (math.copysign(1., self.imagval) == 1. or
                math.isnan(self.imagval)) and '+' or ''
        return space.newtext('(' + repr_format(self.realval)
                             + sign + repr_format(self.imagval) + 'j)')

    def descr_str(self, space):
        if self.realval == 0 and math.copysign(1., self.realval) == 1.:
            return space.newtext(str_format(self.imagval) + 'j')
        sign = (math.copysign(1., self.imagval) == 1. or
                math.isnan(self.imagval)) and '+' or ''
        return space.newtext('(' + str_format(self.realval)
                             + sign + str_format(self.imagval) + 'j)')

    def descr_hash(self, space):
        hashreal = _hash_float(space, self.realval)
        hashimg = _hash_float(space, self.imagval)   # 0 if self.imagval == 0
        h = intmask(hashreal + HASH_IMAG * hashimg)
        h -= (h == -1)
        return space.newint(h)

    def descr_coerce(self, space, w_other):
        w_other = self._to_complex(space, w_other)
        if w_other is None:
            return space.w_NotImplemented
        return space.newtuple([self, w_other])

    def descr_format(self, space, w_format_spec):
        return newformat.run_formatter(space, w_format_spec, "format_complex",
                                       self)

    def descr_bool(self, space):
        return space.newbool((self.realval != 0.0) or (self.imagval != 0.0))

    def descr_float(self, space):
        raise oefmt(space.w_TypeError, "can't convert complex to float")

    def descr_neg(self, space):
        return W_ComplexObject(-self.realval, -self.imagval)

    def descr_pos(self, space):
        return W_ComplexObject(self.realval, self.imagval)

    def descr_abs(self, space):
        try:
            return space.newfloat(math.hypot(self.realval, self.imagval))
        except OverflowError as e:
            raise OperationError(space.w_OverflowError, space.newtext(str(e)))

    def descr_eq(self, space, w_other):
        if isinstance(w_other, W_ComplexObject):
            return space.newbool((self.realval == w_other.realval) and
                                 (self.imagval == w_other.imagval))
        if (space.isinstance_w(w_other, space.w_int) or
            space.isinstance_w(w_other, space.w_float)):
            if self.imagval:
                return space.w_False
            return space.eq(space.newfloat(self.realval), w_other)
        return space.w_NotImplemented

    def descr_ne(self, space, w_other):
        if isinstance(w_other, W_ComplexObject):
            return space.newbool((self.realval != w_other.realval) or
                                 (self.imagval != w_other.imagval))
        if (space.isinstance_w(w_other, space.w_int) or
            space.isinstance_w(w_other, space.w_float)):
            if self.imagval:
                return space.w_True
            return space.ne(space.newfloat(self.realval), w_other)
        return space.w_NotImplemented

    def _fail_cmp(self, space, w_other):
        return space.w_NotImplemented

    def descr_add(self, space, w_rhs):
        w_rhs = self._to_complex(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        return W_ComplexObject(self.realval + w_rhs.realval,
                               self.imagval + w_rhs.imagval)

    def descr_radd(self, space, w_lhs):
        w_lhs = self._to_complex(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return W_ComplexObject(w_lhs.realval + self.realval,
                               w_lhs.imagval + self.imagval)

    def descr_sub(self, space, w_rhs):
        w_rhs = self._to_complex(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        return W_ComplexObject(self.realval - w_rhs.realval,
                               self.imagval - w_rhs.imagval)

    def descr_rsub(self, space, w_lhs):
        w_lhs = self._to_complex(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return W_ComplexObject(w_lhs.realval - self.realval,
                               w_lhs.imagval - self.imagval)

    def descr_mul(self, space, w_rhs):
        w_rhs = self._to_complex(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        return self.mul(w_rhs)

    def descr_rmul(self, space, w_lhs):
        w_lhs = self._to_complex(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return w_lhs.mul(self)

    def descr_truediv(self, space, w_rhs):
        w_rhs = self._to_complex(space, w_rhs)
        if w_rhs is None:
            return space.w_NotImplemented
        try:
            return self.div(w_rhs)
        except ZeroDivisionError as e:
            raise oefmt(space.w_ZeroDivisionError, "complex division by zero")

    def descr_rtruediv(self, space, w_lhs):
        w_lhs = self._to_complex(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        try:
            return w_lhs.div(self)
        except ZeroDivisionError as e:
            raise oefmt(space.w_ZeroDivisionError, "complex division by zero")

    def descr_floordiv(self, space, w_rhs):
        raise oefmt(space.w_TypeError, "can't take floor of complex number.")
    descr_rfloordiv = func_with_new_name(descr_floordiv, 'descr_rfloordiv')

    def descr_mod(self, space, w_rhs):
        raise oefmt(space.w_TypeError, "can't mod complex numbers.")
    descr_rmod = func_with_new_name(descr_mod, 'descr_rmod')

    def descr_divmod(self, space, w_rhs):
        raise oefmt(space.w_TypeError,
                    "can't take floor or mod of complex number.")
    descr_rdivmod = func_with_new_name(descr_divmod, 'descr_rdivmod')

    @unwrap_spec(w_third_arg=WrappedDefault(None))
    def descr_pow(self, space, w_exponent, w_third_arg):
        w_exponent = self._to_complex(space, w_exponent)
        if w_exponent is None:
            return space.w_NotImplemented
        if not space.is_w(w_third_arg, space.w_None):
            raise oefmt(space.w_ValueError, 'complex modulo')
        try:
            r = w_exponent.realval
            if (w_exponent.imagval == 0.0 and -100.0 <= r <= 100.0 and
                r == int(r)):
                w_p = self.pow_small_int(int(r))
            else:
                w_p = self.pow(w_exponent)
        except ZeroDivisionError:
            raise oefmt(space.w_ZeroDivisionError,
                        "0.0 to a negative or complex power")
        except OverflowError:
            raise oefmt(space.w_OverflowError, "complex exponentiation")
        return w_p

    @unwrap_spec(w_third_arg=WrappedDefault(None))
    def descr_rpow(self, space, w_lhs, w_third_arg):
        w_lhs = self._to_complex(space, w_lhs)
        if w_lhs is None:
            return space.w_NotImplemented
        return w_lhs.descr_pow(space, self, w_third_arg)

    def descr_conjugate(self, space):
        """(A+Bj).conjugate() -> A-Bj"""
        return space.newcomplex(self.realval, -self.imagval)


w_one = W_ComplexObject(1, 0)


def complexwprop(name, doc):
    def fget(space, w_obj):
        if not isinstance(w_obj, W_ComplexObject):
            raise oefmt(space.w_TypeError, "descriptor is for 'complex'")
        return space.newfloat(getattr(w_obj, name))
    return GetSetProperty(fget, doc=doc, cls=W_ComplexObject)

W_ComplexObject.typedef = TypeDef("complex",
    __doc__ = """complex(real[, imag]) -> complex number

Create a complex number from a real part and an optional imaginary part.
This is equivalent to (real + imag*1j) where imag defaults to 0.""",
    __new__ = interp2app(W_ComplexObject.descr__new__),
    __getnewargs__ = interp2app(W_ComplexObject.descr___getnewargs__),
    real = complexwprop('realval', doc="the real part of a complex number"),
    imag = complexwprop('imagval',
                        doc="the imaginary part of a complex number"),
    __repr__ = interp2app(W_ComplexObject.descr_repr),
    __str__ = interp2app(W_ComplexObject.descr_str),
    __hash__ = interp2app(W_ComplexObject.descr_hash),
    __format__ = interp2app(W_ComplexObject.descr_format),
    __bool__ = interp2app(W_ComplexObject.descr_bool),
    __int__ = interp2app(W_ComplexObject.descr_int),
    __float__ = interp2app(W_ComplexObject.descr_float),
    __neg__ = interp2app(W_ComplexObject.descr_neg),
    __pos__ = interp2app(W_ComplexObject.descr_pos),
    __abs__ = interp2app(W_ComplexObject.descr_abs),

    __eq__ = interp2app(W_ComplexObject.descr_eq),
    __ne__ = interp2app(W_ComplexObject.descr_ne),
    __lt__ = interp2app(W_ComplexObject._fail_cmp),
    __le__ = interp2app(W_ComplexObject._fail_cmp),
    __gt__ = interp2app(W_ComplexObject._fail_cmp),
    __ge__ = interp2app(W_ComplexObject._fail_cmp),

    __add__ = interp2app(W_ComplexObject.descr_add),
    __radd__ = interp2app(W_ComplexObject.descr_radd),
    __sub__ = interp2app(W_ComplexObject.descr_sub),
    __rsub__ = interp2app(W_ComplexObject.descr_rsub),
    __mul__ = interp2app(W_ComplexObject.descr_mul),
    __rmul__ = interp2app(W_ComplexObject.descr_rmul),
    __truediv__ = interp2app(W_ComplexObject.descr_truediv),
    __rtruediv__ = interp2app(W_ComplexObject.descr_rtruediv),
    __floordiv__ = interp2app(W_ComplexObject.descr_floordiv),
    __rfloordiv__ = interp2app(W_ComplexObject.descr_rfloordiv),
    __mod__ = interp2app(W_ComplexObject.descr_mod),
    __rmod__ = interp2app(W_ComplexObject.descr_rmod),
    __divmod__ = interp2app(W_ComplexObject.descr_divmod),
    __rdivmod__ = interp2app(W_ComplexObject.descr_rdivmod),
    __pow__ = interp2app(W_ComplexObject.descr_pow),
    __rpow__ = interp2app(W_ComplexObject.descr_rpow),

    conjugate = interp2app(W_ComplexObject.descr_conjugate),
)
