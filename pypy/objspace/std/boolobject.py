"""The builtin bool implementation"""

import operator

from rpython.rlib.rarithmetic import r_uint
from rpython.tool.sourcetools import func_renamer, func_with_new_name

from pypy.interpreter.gateway import WrappedDefault, interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef
from pypy.objspace.std.intobject import W_AbstractIntObject, W_IntObject


class W_BoolObject(W_IntObject):

    def __init__(self, boolval):
        self.intval = int(not not boolval)

    def __nonzero__(self):
        raise Exception("you cannot do that, you must use space.is_true()")

    def __repr__(self):
        """representation for debugging purposes"""
        return "%s(%s)" % (self.__class__.__name__, bool(self.intval))

    def is_w(self, space, w_other):
        return self is w_other

    def immutable_unique_id(self, space):
        return None

    def unwrap(self, space):
        return bool(self.intval)

    def uint_w(self, space):
        return r_uint(self.intval)

    def int(self, space):
        return space.newint(self.intval)

    @staticmethod
    @unwrap_spec(w_obj=WrappedDefault(False))
    def descr_new(space, w_booltype, w_obj):
        "Create and return a new object.  See help(type) for accurate signature."
        space.w_bool.check_user_subclass(w_booltype)
        return space.newbool(space.is_true(w_obj))

    def descr_repr(self, space):
        return space.newtext('True' if self.intval else 'False')
    descr_str = func_with_new_name(descr_repr, 'descr_str')

    def descr_bool(self, space):
        return self

    def _make_bitwise_binop(opname):
        descr_name = 'descr_' + opname
        int_op = getattr(W_IntObject, descr_name)
        op = getattr(operator,
                     opname + '_' if opname in ('and', 'or') else opname)

        @func_renamer(descr_name)
        def descr_binop(self, space, w_other):
            if not isinstance(w_other, W_BoolObject):
                return int_op(self, space, w_other)
            a = bool(self.intval)
            b = bool(w_other.intval)
            return space.newbool(op(a, b))

        @func_renamer('descr_r' + opname)
        def descr_rbinop(self, space, w_other):
            return descr_binop(self, space, w_other)

        return descr_binop, descr_rbinop

    descr_and, descr_rand = _make_bitwise_binop('and')
    descr_or, descr_ror = _make_bitwise_binop('or')
    descr_xor, descr_rxor = _make_bitwise_binop('xor')


W_BoolObject.w_False = W_BoolObject(False)
W_BoolObject.w_True = W_BoolObject(True)


W_BoolObject.typedef = TypeDef("bool", W_IntObject.typedef,
    __doc__ = """bool(x) -> bool

Returns True when the argument x is true, False otherwise.
The builtins True and False are the only two instances of the class bool.
The class bool is a subclass of the class int, and cannot be subclassed.""",
    __new__ = interp2app(W_BoolObject.descr_new),
    __repr__ = interp2app(W_BoolObject.descr_repr,
                          doc=W_AbstractIntObject.descr_repr.__doc__),
    __str__ = interp2app(W_BoolObject.descr_str,
                         doc=W_AbstractIntObject.descr_str.__doc__),
    __bool__ = interp2app(W_BoolObject.descr_bool,
                             doc=W_AbstractIntObject.descr_bool.__doc__),

    __and__ = interp2app(W_BoolObject.descr_and,
                         doc=W_AbstractIntObject.descr_and.__doc__),
    __rand__ = interp2app(W_BoolObject.descr_rand,
                          doc=W_AbstractIntObject.descr_rand.__doc__),
    __or__ = interp2app(W_BoolObject.descr_or,
                        doc=W_AbstractIntObject.descr_or.__doc__),
    __ror__ = interp2app(W_BoolObject.descr_ror,
                         doc=W_AbstractIntObject.descr_ror.__doc__),
    __xor__ = interp2app(W_BoolObject.descr_xor,
                         doc=W_AbstractIntObject.descr_xor.__doc__),
    __rxor__ = interp2app(W_BoolObject.descr_rxor,
                          doc=W_AbstractIntObject.descr_rxor.__doc__),
    )
W_BoolObject.typedef.acceptable_as_base_class = False
