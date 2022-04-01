"""
This module defines all the SpaceOperations used in rpython.flowspace.
"""

import __builtin__
import __future__
import operator
import sys
import types
from rpython.tool.pairtype import pair, DoubleDispatchRegistry
from rpython.rlib.unroll import unrolling_iterable, _unroller
from rpython.tool.sourcetools import compile2
from rpython.flowspace.model import (Constant, WrapException, const, Variable,
                                     SpaceOperation)
from rpython.flowspace.specialcase import register_flow_sc
from rpython.annotator.model import (
    SomeTuple, AnnotatorError, read_can_only_throw)
from rpython.annotator.argument import ArgumentsForTranslation
from rpython.flowspace.specialcase import SPECIAL_CASES


NOT_REALLY_CONST = {
    Constant(sys): {
        Constant('maxint'): True,
        Constant('maxunicode'): True,
        Constant('api_version'): True,
        Constant('exit'): True,
        Constant('exc_info'): True,
        Constant('getrefcount'): True,
        Constant('getdefaultencoding'): True,
        # this is an incomplete list of true constants.
        # if we add much more, a dedicated class
        # might be considered for special objects.
    }
}

# built-ins that can always raise exceptions
builtins_exceptions = {
    int: [ValueError],
    float: [ValueError],
    chr: [ValueError],
    unichr: [ValueError],
    unicode: [UnicodeDecodeError],
}


class _OpHolder(object):
    pass
op = _OpHolder()

func2op = {}

class HLOperationMeta(type):
    def __init__(cls, name, bases, attrdict):
        type.__init__(cls, name, bases, attrdict)
        if hasattr(cls, 'opname'):
            setattr(op, cls.opname, cls)
        if cls.dispatch == 1:
            cls._registry = {}
            cls._transform = {}
        elif cls.dispatch == 2:
            cls._registry = DoubleDispatchRegistry()
            cls._transform = DoubleDispatchRegistry()


class HLOperation(SpaceOperation):
    __metaclass__ = HLOperationMeta
    pure = False
    can_overflow = False
    dispatch = None  # number of arguments to dispatch on
                     # (None means special handling)

    def __init__(self, *args):
        self.args = list(args)
        self.result = Variable()
        self.offset = -1

    def replace(self, mapping):
        newargs = [arg.replace(mapping) for arg in self.args]
        newresult = self.result.replace(mapping)
        newop = type(self)(*newargs)
        newop.result = newresult
        newop.offset = self.offset
        return newop

    @classmethod
    def make_sc(cls):
        def sc_operator(ctx, *args_w):
            return cls(*args_w).eval(ctx)
        return sc_operator

    def eval(self, ctx):
        result = self.constfold()
        if result is not None:
            return result
        return ctx.do_op(self)

    def constfold(self):
        return None

    def consider(self, annotator):
        args_s = [annotator.annotation(arg) for arg in self.args]
        spec = type(self).get_specialization(*args_s)
        return spec(annotator, *self.args)

    def get_can_only_throw(self, annotator):
        return None

    def get_transformer(self, *args_s):
        return lambda *args: None

    def transform(self, annotator):
        args_s = [annotator.annotation(arg) for arg in self.args]
        transformer = self.get_transformer(*args_s)
        return transformer(annotator, *self.args)

class PureOperation(HLOperation):
    pure = True

    def constfold(self):
        args = []
        if all(w_arg.foldable() for w_arg in self.args):
            args = [w_arg.value for w_arg in self.args]
            # All arguments are constants: call the operator now
            try:
                result = self.pyfunc(*args)
            except Exception as e:
                from rpython.flowspace.flowcontext import FlowingError
                msg = "%s%r always raises %s: %s" % (
                    self.opname, tuple(args), type(e), e)
                raise FlowingError(msg)
            else:
                # don't try to constant-fold operations giving a 'long'
                # result.  The result is probably meant to be sent to
                # an intmask(), but the 'long' constant confuses the
                # annotator a lot.
                if self.can_overflow and type(result) is long:
                    pass
                # don't constant-fold getslice on lists, either
                elif self.opname == 'getslice' and type(result) is list:
                    pass
                # otherwise, fine
                else:
                    try:
                        return const(result)
                    except WrapException:
                        # type cannot sanely appear in flow graph,
                        # store operation with variable result instead
                        pass

class OverflowingOperation(PureOperation):
    can_overflow = True

    def ovfchecked(self):
        ovf = self.ovf_variant(*self.args)
        ovf.offset = self.offset
        return ovf

class SingleDispatchMixin(object):
    dispatch = 1

    @classmethod
    def register(cls, Some_cls):
        def decorator(func):
            cls._registry[Some_cls] = func
            return func
        return decorator

    @classmethod
    def _dispatch(cls, Some_cls):
        for c in Some_cls.__mro__:
            try:
                return cls._registry[c]
            except KeyError:
                pass
        raise AnnotatorError("Unknown operation")

    def get_can_only_throw(self, annotator):
        args_s = [annotator.annotation(v) for v in self.args]
        spec = type(self).get_specialization(*args_s)
        return read_can_only_throw(spec, args_s[0])

    @classmethod
    def get_specialization(cls, s_arg, *_ignored):
        try:
            impl = getattr(s_arg, cls.opname)

            def specialized(annotator, arg, *other_args):
                return impl(*[annotator.annotation(x) for x in other_args])
            try:
                specialized.can_only_throw = impl.can_only_throw
            except AttributeError:
                pass
            return specialized
        except AttributeError:
            return cls._dispatch(type(s_arg))

    @classmethod
    def register_transform(cls, Some_cls):
        def decorator(func):
            cls._transform[Some_cls] = func
            return func
        return decorator

    @classmethod
    def get_transformer(cls, s_arg, *_ignored):
        for c in type(s_arg).__mro__:
            try:
                return cls._transform[c]
            except KeyError:
                pass
        return lambda *args: None


class DoubleDispatchMixin(object):
    dispatch = 2

    @classmethod
    def register(cls, Some1, Some2):
        def decorator(func):
            cls._registry[Some1, Some2] = func
            return func
        return decorator

    @classmethod
    def get_specialization(cls, s_arg1, s_arg2, *_ignored):
        try:
            impl = getattr(pair(s_arg1, s_arg2), cls.opname)

            def specialized(annotator, arg1, arg2, *other_args):
                return impl(*[annotator.annotation(x) for x in other_args])
            try:
                specialized.can_only_throw = impl.can_only_throw
            except AttributeError:
                pass
            return specialized
        except AttributeError:
            return cls._registry[type(s_arg1), type(s_arg2)]

    def get_can_only_throw(self, annotator):
        args_s = [annotator.annotation(v) for v in self.args]
        spec = type(self).get_specialization(*args_s)
        return read_can_only_throw(spec, args_s[0], args_s[1])

    @classmethod
    def register_transform(cls, Some1, Some2):
        def decorator(func):
            cls._transform[Some1, Some2] = func
            return func
        return decorator

    @classmethod
    def get_transformer(cls, s_arg1, s_arg2, *_ignored):
        try:
            return cls._transform[type(s_arg1), type(s_arg2)]
        except KeyError:
            return lambda *args: None


def add_operator(name, arity, dispatch=None, pyfunc=None, pure=False, ovf=False):
    operator_func = getattr(operator, name, None)
    if dispatch == 1:
        bases = [SingleDispatchMixin]
    elif dispatch == 2:
        bases = [DoubleDispatchMixin]
    else:
        bases = []
    if ovf:
        assert pure
        base_cls = OverflowingOperation
    elif pure:
        base_cls = PureOperation
    else:
        base_cls = HLOperation
    bases.append(base_cls)
    cls = HLOperationMeta(name, tuple(bases), {'opname': name, 'arity': arity,
                                               'canraise': [],
                                               'dispatch': dispatch})
    if pyfunc is not None:
        func2op[pyfunc] = cls
    if operator_func:
        func2op[operator_func] = cls
    if pyfunc is not None:
        cls.pyfunc = staticmethod(pyfunc)
    elif operator_func is not None:
        cls.pyfunc = staticmethod(operator_func)
    if ovf:
        from rpython.rlib.rarithmetic import ovfcheck
        ovf_func = lambda *args: ovfcheck(cls.pyfunc(*args))
        add_operator(name + '_ovf', arity, dispatch, pyfunc=ovf_func)
        cls.ovf_variant = getattr(op, name + '_ovf')

# ____________________________________________________________

def new_style_type(x):
    """Simulate a situation where every class is new-style"""
    return getattr(x, '__class__', type(x))

def do_int(x):
    return x.__int__()

def do_index(x):
    return x.__index__()

def do_float(x):
    return x.__float__()

def do_long(x):
    return x.__long__()

def inplace_add(x, y):
    x += y
    return x

def inplace_sub(x, y):
    x -= y
    return x

def inplace_mul(x, y):
    x *= y
    return x

exec(compile2("""
def inplace_truediv(x, y):
    x /= y
    return x
""", flags=__future__.CO_FUTURE_DIVISION, dont_inherit=1))
#                     makes an INPLACE_TRUE_DIVIDE

def inplace_floordiv(x, y):
    x //= y
    return x

exec(compile2("""
def inplace_div(x, y):
    x /= y
    return x
""", flags=0, dont_inherit=1))    # makes an INPLACE_DIVIDE

def inplace_mod(x, y):
    x %= y
    return x

def inplace_pow(x, y):
    x **= y
    return x

def inplace_lshift(x, y):
    x <<= y
    return x

def inplace_rshift(x, y):
    x >>= y
    return x

def inplace_and(x, y):
    x &= y
    return x

def inplace_or(x, y):
    x |= y
    return x

def inplace_xor(x, y):
    x ^= y
    return x

def next(x):
    return x.next()

def get(x, y, z=None):
    return x.__get__(y, z)

def set(x, y, z):
    x.__set__(y, z)

def delete(x, y):
    x.__delete__(y)

def userdel(x):
    x.__del__()

# slicing: operator.{get,set,del}slice() don't support b=None or c=None
def do_getslice(a, b, c):
    return a[b:c]

def do_setslice(a, b, c, d):
    a[b:c] = d

def do_delslice(a, b, c):
    del a[b:c]

def unsupported(*args):
    raise ValueError("this is not supported")


add_operator('is_', 2, dispatch=2, pure=True)
add_operator('id', 1, dispatch=1, pyfunc=id)
add_operator('type', 1, dispatch=1, pyfunc=new_style_type, pure=True)
add_operator('issubtype', 2, dispatch=1, pyfunc=issubclass, pure=True)  # not for old-style classes
add_operator('isinstance', 2, dispatch=1, pyfunc=isinstance, pure=True)
add_operator('repr', 1, dispatch=1, pyfunc=repr, pure=True)
add_operator('str', 1, dispatch=1, pyfunc=str, pure=True)
add_operator('format', 2, pyfunc=unsupported)
add_operator('len', 1, dispatch=1, pyfunc=len, pure=True)
add_operator('hash', 1, dispatch=1, pyfunc=hash)
add_operator('setattr', 3, dispatch=1, pyfunc=setattr)
add_operator('delattr', 2, dispatch=1, pyfunc=delattr)
add_operator('getitem', 2, dispatch=2, pure=True)
add_operator('getitem_idx', 2, dispatch=2, pure=True)
add_operator('setitem', 3, dispatch=2)
add_operator('delitem', 2, dispatch=2)
add_operator('getslice', 3, dispatch=1, pyfunc=do_getslice, pure=True)
add_operator('setslice', 4, dispatch=1, pyfunc=do_setslice)
add_operator('delslice', 3, dispatch=1, pyfunc=do_delslice)
add_operator('trunc', 1, pyfunc=unsupported)
add_operator('pos', 1, dispatch=1, pure=True)
add_operator('neg', 1, dispatch=1, pure=True, ovf=True)
add_operator('bool', 1, dispatch=1, pyfunc=bool, pure=True)
op.is_true = op.nonzero = op.bool  # for llinterp
add_operator('abs', 1, dispatch=1, pyfunc=abs, pure=True, ovf=True)
add_operator('hex', 1, dispatch=1, pyfunc=hex, pure=True)
add_operator('oct', 1, dispatch=1, pyfunc=oct, pure=True)
add_operator('ord', 1, dispatch=1, pyfunc=ord, pure=True)
add_operator('invert', 1, dispatch=1, pure=True)
add_operator('add', 2, dispatch=2, pure=True, ovf=True)
add_operator('sub', 2, dispatch=2, pure=True, ovf=True)
add_operator('mul', 2, dispatch=2, pure=True, ovf=True)
add_operator('truediv', 2, dispatch=2, pure=True)
add_operator('floordiv', 2, dispatch=2, pure=True, ovf=True)
add_operator('div', 2, dispatch=2, pure=True, ovf=True)
add_operator('mod', 2, dispatch=2, pure=True, ovf=True)
add_operator('divmod', 2, pyfunc=divmod, pure=True)
add_operator('lshift', 2, dispatch=2, pure=True, ovf=True)
add_operator('rshift', 2, dispatch=2, pure=True)
add_operator('and_', 2, dispatch=2, pure=True)
add_operator('or_', 2, dispatch=2, pure=True)
add_operator('xor', 2, dispatch=2, pure=True)
add_operator('int', 1, dispatch=1, pyfunc=do_int, pure=True)
add_operator('index', 1, pyfunc=do_index, pure=True)
add_operator('float', 1, dispatch=1, pyfunc=do_float, pure=True)
add_operator('long', 1, dispatch=1, pyfunc=do_long, pure=True)
add_operator('inplace_add', 2, dispatch=2, pyfunc=inplace_add)
add_operator('inplace_sub', 2, dispatch=2, pyfunc=inplace_sub)
add_operator('inplace_mul', 2, dispatch=2, pyfunc=inplace_mul)
add_operator('inplace_truediv', 2, dispatch=2, pyfunc=inplace_truediv)
add_operator('inplace_floordiv', 2, dispatch=2, pyfunc=inplace_floordiv)
add_operator('inplace_div', 2, dispatch=2, pyfunc=inplace_div)
add_operator('inplace_mod', 2, dispatch=2, pyfunc=inplace_mod)
add_operator('inplace_pow', 2, pyfunc=inplace_pow)
add_operator('inplace_lshift', 2, dispatch=2, pyfunc=inplace_lshift)
add_operator('inplace_rshift', 2, dispatch=2, pyfunc=inplace_rshift)
add_operator('inplace_and', 2, dispatch=2, pyfunc=inplace_and)
add_operator('inplace_or', 2, dispatch=2, pyfunc=inplace_or)
add_operator('inplace_xor', 2, dispatch=2, pyfunc=inplace_xor)
add_operator('lt', 2, dispatch=2, pure=True)
add_operator('le', 2, dispatch=2, pure=True)
add_operator('eq', 2, dispatch=2, pure=True)
add_operator('ne', 2, dispatch=2, pure=True)
add_operator('gt', 2, dispatch=2, pure=True)
add_operator('ge', 2, dispatch=2, pure=True)
add_operator('cmp', 2, dispatch=2, pyfunc=cmp, pure=True)   # rich cmps preferred
add_operator('coerce', 2, dispatch=2, pyfunc=coerce, pure=True)
add_operator('contains', 2, pure=True)
add_operator('get', 3, pyfunc=get, pure=True)
add_operator('set', 3, pyfunc=set)
add_operator('delete', 2, pyfunc=delete)
add_operator('userdel', 1, pyfunc=userdel)
add_operator('buffer', 1, pyfunc=buffer, pure=True)   # see buffer.py
add_operator('yield_', 1)
add_operator('newslice', 3)
add_operator('hint', None, dispatch=1)

class Contains(SingleDispatchMixin, PureOperation):
    opname = 'contains'
    arity = 2
    pyfunc = staticmethod(operator.contains)

    # XXX "contains" clashes with SomeObject method
    @classmethod
    def get_specialization(cls, s_seq, s_elem):
        return cls._dispatch(type(s_seq))


class NewDict(HLOperation):
    opname = 'newdict'
    canraise = []

    def consider(self, annotator):
        return annotator.bookkeeper.newdict()


class NewTuple(PureOperation):
    opname = 'newtuple'
    pyfunc = staticmethod(lambda *args: args)
    canraise = []

    def consider(self, annotator):
        return SomeTuple(items=[annotator.annotation(arg) for arg in self.args])


class NewList(HLOperation):
    opname = 'newlist'
    canraise = []

    def consider(self, annotator):
        return annotator.bookkeeper.newlist(
                *[annotator.annotation(arg) for arg in self.args])


class NewSlice(HLOperation):
    opname = 'newslice'
    canraise = []

    def consider(self, annotator):
        raise AnnotatorError("Cannot use extended slicing in rpython")


class Pow(PureOperation):
    opname = 'pow'
    arity = 3
    can_overflow = False
    canraise = []
    pyfunc = pow

    def __init__(self, w_base, w_exponent, w_mod=const(None)):
        self.args = [w_base, w_exponent, w_mod]
        self.result = Variable()
        self.offset = -1


class Iter(SingleDispatchMixin, HLOperation):
    opname = 'iter'
    arity = 1
    can_overflow = False
    canraise = []
    pyfunc = staticmethod(iter)

    def constfold(self):
        w_iterable, = self.args
        if isinstance(w_iterable, Constant):
            iterable = w_iterable.value
            if isinstance(iterable, unrolling_iterable):
                return const(iterable.get_unroller())

class Next(SingleDispatchMixin, HLOperation):
    opname = 'next'
    arity = 1
    can_overflow = False
    canraise = [StopIteration, RuntimeError]
    pyfunc = staticmethod(next)

    def eval(self, ctx):
        w_iter, = self.args
        if isinstance(w_iter, Constant):
            it = w_iter.value
            if isinstance(it, _unroller):
                try:
                    v, next_unroller = it.step()
                except IndexError:
                    from rpython.flowspace.flowcontext import Raise
                    raise Raise(const(StopIteration()))
                else:
                    ctx.replace_in_stack(it, next_unroller)
                    return const(v)
        return HLOperation.eval(self, ctx)

class GetAttr(SingleDispatchMixin, HLOperation):
    opname = 'getattr'
    arity = 2
    can_overflow = False
    canraise = []
    pyfunc = staticmethod(getattr)

    def constfold(self):
        from rpython.flowspace.flowcontext import FlowingError
        if len(self.args) == 3:
            raise FlowingError(
                "getattr() with three arguments not supported: %s" % (self,))
        w_obj, w_name = self.args
        # handling special things like sys
        if (w_obj in NOT_REALLY_CONST and
                w_name not in NOT_REALLY_CONST[w_obj]):
            return
        if w_obj.foldable() and w_name.foldable():
            obj, name = w_obj.value, w_name.value
            try:
                result = getattr(obj, name)
            except Exception as e:
                etype = e.__class__
                msg = "getattr(%s, %s) always raises %s: %s" % (
                    obj, name, etype, e)
                raise FlowingError(msg)
            try:
                return const(result)
            except WrapException:
                pass

class CallOp(HLOperation):
    @property
    def canraise(self):
        w_callable = self.args[0]
        if isinstance(w_callable, Constant):
            c = w_callable.value
            if (isinstance(c, (types.BuiltinFunctionType,
                               types.BuiltinMethodType,
                               types.ClassType,
                               types.TypeType)) and
                    c.__module__ in ['__builtin__', 'exceptions']):
                return builtins_exceptions.get(c, [])
        # *any* exception for non-builtins
        return [Exception]

class SimpleCall(SingleDispatchMixin, CallOp):
    opname = 'simple_call'

    def eval(self, ctx):
        w_callable, args_w = self.args[0], self.args[1:]
        if isinstance(w_callable, Constant):
            fn = w_callable.value
            try:
                sc = SPECIAL_CASES[fn]   # TypeError if 'fn' not hashable
            except (KeyError, TypeError):
                pass
            else:
                return sc(ctx, *args_w)
        return ctx.do_op(self)

    def build_args(self, args_s):
        return ArgumentsForTranslation(list(args_s))


class CallArgs(SingleDispatchMixin, CallOp):
    opname = 'call_args'

    def eval(self, ctx):
        w_callable = self.args[0]
        if isinstance(w_callable, Constant):
            fn = w_callable.value
            try:
                sc = SPECIAL_CASES[fn]   # TypeError if 'fn' not hashable
            except (KeyError, TypeError):
                pass
            else:
                from rpython.flowspace.flowcontext import FlowingError
                raise FlowingError(
                    "should not call %r with keyword arguments" % (fn,))
        return ctx.do_op(self)

    def build_args(self, args_s):
        return ArgumentsForTranslation.fromshape(args_s[0].const,
                                                list(args_s[1:]))


# Other functions that get directly translated to SpaceOperators
func2op[type] = op.type
func2op[operator.truth] = op.bool
func2op[pow] = op.pow
func2op[operator.pow] = op.pow
func2op[__builtin__.iter] = op.iter
func2op[getattr] = op.getattr
func2op[__builtin__.next] = op.next

for fn, oper in func2op.items():
    register_flow_sc(fn)(oper.make_sc())


op_appendices = {
    OverflowError: 'ovf',
    IndexError: 'idx',
    KeyError: 'key',
    ZeroDivisionError: 'zer',
    ValueError: 'val',
}

# specifying IndexError, and KeyError beyond Exception,
# allows the annotator to be more precise, see test_reraiseAnything/KeyError in
# the annotator tests
op.getitem.canraise = [IndexError, KeyError, Exception]
op.getitem_idx.canraise = [IndexError, KeyError, Exception]
op.setitem.canraise = [IndexError, KeyError, Exception]
op.delitem.canraise = [IndexError, KeyError, Exception]
op.contains.canraise = [Exception]    # from an r_dict

def _add_exceptions(names, exc):
    for name in names.split():
        oper = getattr(op, name)
        lis = oper.canraise
        if exc in lis:
            raise ValueError("your list is causing duplication!")
        lis.append(exc)
        assert exc in op_appendices

def _add_except_ovf(names):
    # duplicate exceptions and add OverflowError
    for name in names.split():
        oper = getattr(op, name)
        oper_ovf = getattr(op, name + '_ovf')
        oper_ovf.canraise = list(oper.canraise)
        oper_ovf.canraise.append(OverflowError)

_add_exceptions("""div mod divmod truediv floordiv pow
                   inplace_div inplace_mod inplace_truediv
                   inplace_floordiv inplace_pow""", ZeroDivisionError)
_add_exceptions("""pow inplace_pow lshift inplace_lshift rshift
                   inplace_rshift""", ValueError)
_add_exceptions("""truediv divmod
                   inplace_add inplace_sub inplace_mul inplace_truediv
                   inplace_floordiv inplace_div inplace_mod inplace_pow
                   inplace_lshift""", OverflowError)  # without a _ovf version
_add_except_ovf("""neg abs add sub mul
                   floordiv div mod lshift""")   # with a _ovf version
_add_exceptions("""pow""",
                OverflowError)  # for the float case
del _add_exceptions, _add_except_ovf
