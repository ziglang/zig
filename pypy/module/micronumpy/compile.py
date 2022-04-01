""" This is a set of tools for standalone compiling of numpy expressions.
It should not be imported by the module itself
"""
import re
import py
from pypy.interpreter import special
from pypy.interpreter.baseobjspace import InternalSpaceCache, W_Root, ObjSpace
from pypy.interpreter.error import oefmt
from rpython.rlib.objectmodel import specialize, instantiate
from rpython.rlib.nonconst import NonConstant
from rpython.rlib.rarithmetic import base_int
from pypy.module.micronumpy import boxes, ufuncs
from pypy.module.micronumpy.arrayops import where
from pypy.module.micronumpy.ndarray import W_NDimArray
from pypy.module.micronumpy.ctors import array
from pypy.module.micronumpy.descriptor import get_dtype_cache
from pypy.interpreter.miscutils import ThreadLocals, make_weak_value_dictionary
from pypy.interpreter.executioncontext import (ExecutionContext, ActionFlag,
    UserDelAction)
from pypy.interpreter.pyframe import PyFrame

class BogusBytecode(Exception):
    pass

class ArgumentMismatch(Exception):
    pass

class ArgumentNotAnArray(Exception):
    pass

class WrongFunctionName(Exception):
    pass

class TokenizerError(Exception):
    pass

class BadToken(Exception):
    pass

SINGLE_ARG_FUNCTIONS = ["sum", "prod", "max", "min", "all", "any",
                        "unegative", "flat", "tostring", "count_nonzero",
                        "argsort", "cumsum", "logical_xor_reduce"]
TWO_ARG_FUNCTIONS = ["dot", 'take', 'searchsorted', 'multiply']
TWO_ARG_FUNCTIONS_OR_NONE = ['view', 'astype', 'reshape']
THREE_ARG_FUNCTIONS = ['where']

class W_TypeObject(W_Root):
    def __init__(self, name):
        self.name = name

    def lookup(self, name):
        return self.getdictvalue(self, name)

    def getname(self, space):
        return self.name

class FakeSpace(ObjSpace):
    w_ValueError = W_TypeObject("ValueError")
    w_TypeError = W_TypeObject("TypeError")
    w_IndexError = W_TypeObject("IndexError")
    w_OverflowError = W_TypeObject("OverflowError")
    w_NotImplementedError = W_TypeObject("NotImplementedError")
    w_AttributeError = W_TypeObject("AttributeError")
    w_StopIteration = W_TypeObject("StopIteration")
    w_KeyError = W_TypeObject("KeyError")
    w_SystemExit = W_TypeObject("SystemExit")
    w_KeyboardInterrupt = W_TypeObject("KeyboardInterrupt")
    w_RuntimeError = W_TypeObject("RuntimeError")
    w_RecursionError = W_TypeObject("RecursionError")   # py3.5
    w_VisibleDeprecationWarning = W_TypeObject("VisibleDeprecationWarning")
    w_None = W_Root()

    w_bool = W_TypeObject("bool")
    w_int = W_TypeObject("int")
    w_float = W_TypeObject("float")
    w_list = W_TypeObject("list")
    w_long = W_TypeObject("long")
    w_tuple = W_TypeObject('tuple')
    w_slice = W_TypeObject("slice")
    w_bytes = W_TypeObject("str")
    w_text = w_bytes
    w_unicode = W_TypeObject("unicode")
    w_complex = W_TypeObject("complex")
    w_dict = W_TypeObject("dict")
    w_object = W_TypeObject("object")
    w_buffer = W_TypeObject("buffer")
    w_type = W_TypeObject("type")
    w_frozenset = W_TypeObject("frozenset")

    def __init__(self, config=None):
        """NOT_RPYTHON"""
        self.fromcache = InternalSpaceCache(self).getorbuild
        self.w_Ellipsis = special.Ellipsis()
        self.w_NotImplemented = special.NotImplemented()

        if config is None:
            from pypy.config.pypyoption import get_pypy_config
            config = get_pypy_config(translating=False)
        self.config = config

        self.interned_strings = make_weak_value_dictionary(self, str, W_Root)
        self.builtin = DictObject({})
        self.FrameClass = PyFrame
        self.threadlocals = ThreadLocals()
        self.actionflag = ActionFlag()    # changed by the signal module
        self.check_signal_action = None   # changed by the signal module

    def _freeze_(self):
        return True

    def is_none(self, w_obj):
        return w_obj is None or w_obj is self.w_None

    def issequence_w(self, w_obj):
        return isinstance(w_obj, ListObject) or isinstance(w_obj, W_NDimArray)

    def len(self, w_obj):
        return self.wrap(self.len_w(w_obj))

    def len_w(self, w_obj):
        if isinstance(w_obj, ListObject):
            return len(w_obj.items)
        elif isinstance(w_obj, DictObject):
            return len(w_obj.items)
        raise NotImplementedError

    def getattr(self, w_obj, w_attr):
        assert isinstance(w_attr, StringObject)
        if isinstance(w_obj, DictObject):
            return w_obj.getdictvalue(self, w_attr)
        return None

    def issubtype_w(self, w_sub, w_type):
        is_root(w_type)
        return NonConstant(True)

    def isinstance_w(self, w_obj, w_tp):
        try:
            return w_obj.tp == w_tp
        except AttributeError:
            return False

    def iter(self, w_iter):
        if isinstance(w_iter, ListObject):
            raise NotImplementedError
            #return IterObject(space, w_iter.items)
        elif isinstance(w_iter, DictObject):
            return IterDictObject(self, w_iter)

    def next(self, w_iter):
        return w_iter.next()

    def contains(self, w_iter, w_key):
        if isinstance(w_iter, DictObject):
            return self.wrap(w_key in w_iter.items)

        raise NotImplementedError

    def decode_index4(self, w_idx, size):
        if isinstance(w_idx, IntObject):
            return (self.int_w(w_idx), 0, 0, 1)
        else:
            assert isinstance(w_idx, SliceObject)
            start, stop, step = w_idx.start, w_idx.stop, w_idx.step
            if step == 0:
                return (0, size, 1, size)
            if start < 0:
                start += size
            if stop < 0:
                stop += size + 1
            if step < 0:
                start, stop = stop, start
                start -= 1
                stop -= 1
                lgt = (stop - start + 1) / step + 1
            else:
                lgt = (stop - start - 1) / step + 1
            return (start, stop, step, lgt)

    def unicode_from_object(self, w_item):
        # XXX
        return StringObject("")

    @specialize.argtype(1)
    def wrap(self, obj):
        if isinstance(obj, float):
            return FloatObject(obj)
        elif isinstance(obj, bool):
            return BoolObject(obj)
        elif isinstance(obj, int):
            return IntObject(obj)
        elif isinstance(obj, base_int):
            return LongObject(obj)
        elif isinstance(obj, W_Root):
            return obj
        elif isinstance(obj, str):
            return StringObject(obj)
        raise NotImplementedError

    def newtext(self, obj):
        return StringObject(obj)
    newbytes = newtext

    def newutf8(self, obj, l):
        raise NotImplementedError

    def newlist(self, items):
        return ListObject(items)

    def newcomplex(self, r, i):
        return ComplexObject(r, i)

    def newfloat(self, f):
        return FloatObject(f)

    def newslice(self, start, stop, step):
        return SliceObject(self.int_w(start), self.int_w(stop),
                           self.int_w(step))

    def le(self, w_obj1, w_obj2):
        assert isinstance(w_obj1, boxes.W_GenericBox)
        assert isinstance(w_obj2, boxes.W_GenericBox)
        return w_obj1.descr_le(self, w_obj2)

    def lt(self, w_obj1, w_obj2):
        assert isinstance(w_obj1, boxes.W_GenericBox)
        assert isinstance(w_obj2, boxes.W_GenericBox)
        return w_obj1.descr_lt(self, w_obj2)

    def ge(self, w_obj1, w_obj2):
        assert isinstance(w_obj1, boxes.W_GenericBox)
        assert isinstance(w_obj2, boxes.W_GenericBox)
        return w_obj1.descr_ge(self, w_obj2)

    def add(self, w_obj1, w_obj2):
        assert isinstance(w_obj1, boxes.W_GenericBox)
        assert isinstance(w_obj2, boxes.W_GenericBox)
        return w_obj1.descr_add(self, w_obj2)

    def sub(self, w_obj1, w_obj2):
        return self.wrap(1)

    def mul(self, w_obj1, w_obj2):
        assert isinstance(w_obj1, boxes.W_GenericBox)
        assert isinstance(w_obj2, boxes.W_GenericBox)
        return w_obj1.descr_mul(self, w_obj2)

    def pow(self, w_obj1, w_obj2, _):
        return self.wrap(1)

    def neg(self, w_obj1):
        return self.wrap(0)

    def repr(self, w_obj1):
        return self.wrap('fake')

    def getitem(self, obj, index):
        if isinstance(obj, DictObject):
            w_dict = obj.getdict(self)
            if w_dict is not None:
                try:
                    return w_dict[index]
                except KeyError as e:
                    raise oefmt(self.w_KeyError, "key error")

        assert isinstance(obj, ListObject)
        assert isinstance(index, IntObject)
        return obj.items[index.intval]

    def listview(self, obj, number=-1):
        assert isinstance(obj, ListObject)
        if number != -1:
            assert number == 2
            return [obj.items[0], obj.items[1]]
        return obj.items

    fixedview = listview

    def float(self, w_obj):
        if isinstance(w_obj, FloatObject):
            return w_obj
        assert isinstance(w_obj, boxes.W_GenericBox)
        return self.float(w_obj.descr_float(self))

    def float_w(self, w_obj, allow_conversion=True):
        assert isinstance(w_obj, FloatObject)
        return w_obj.floatval

    def int_w(self, w_obj, allow_conversion=True):
        if isinstance(w_obj, IntObject):
            return w_obj.intval
        elif isinstance(w_obj, FloatObject):
            return int(w_obj.floatval)
        elif isinstance(w_obj, SliceObject):
            raise oefmt(self.w_TypeError, "slice.")
        raise NotImplementedError

    def unpackcomplex(self, w_obj):
        if isinstance(w_obj, ComplexObject):
            return w_obj.r, w_obj.i
        raise NotImplementedError

    def index(self, w_obj):
        return self.wrap(self.int_w(w_obj))

    def bytes_w(self, w_obj):
        if isinstance(w_obj, StringObject):
            return w_obj.v
        raise NotImplementedError
    text_w = bytes_w

    def utf8_w(self, w_obj):
        # XXX
        if isinstance(w_obj, StringObject):
            return w_obj.v
        raise NotImplementedError

    def int(self, w_obj):
        if isinstance(w_obj, IntObject):
            return w_obj
        assert isinstance(w_obj, boxes.W_GenericBox)
        return self.int(w_obj.descr_int(self))

    def long(self, w_obj):
        if isinstance(w_obj, LongObject):
            return w_obj
        assert isinstance(w_obj, boxes.W_GenericBox)
        return self.int(w_obj.descr_long(self))

    def str(self, w_obj):
        if isinstance(w_obj, StringObject):
            return w_obj
        assert isinstance(w_obj, boxes.W_GenericBox)
        return self.str(w_obj.descr_str(self))

    def is_true(self, w_obj):
        assert isinstance(w_obj, BoolObject)
        return bool(w_obj.intval)

    def gt(self, w_lhs, w_rhs):
        return BoolObject(self.int_w(w_lhs) > self.int_w(w_rhs))

    def lt(self, w_lhs, w_rhs):
        return BoolObject(self.int_w(w_lhs) < self.int_w(w_rhs))

    def is_w(self, w_obj, w_what):
        return w_obj is w_what

    def eq_w(self, w_obj, w_what):
        return w_obj == w_what

    def issubtype(self, w_type1, w_type2):
        return BoolObject(True)

    def type(self, w_obj):
        if self.is_none(w_obj):
            return self.w_None
        try:
            return w_obj.tp
        except AttributeError:
            if isinstance(w_obj, W_NDimArray):
                return W_NDimArray
            return self.w_None

    def lookup(self, w_obj, name):
        w_type = self.type(w_obj)
        if not self.is_none(w_type):
            return w_type.lookup(name)

    def gettypefor(self, w_obj):
        return W_TypeObject(w_obj.typedef.name)

    def call_function(self, tp, w_dtype, *args):
        if tp is self.w_float:
            if isinstance(w_dtype, boxes.W_Float64Box):
                return FloatObject(float(w_dtype.value))
            if isinstance(w_dtype, boxes.W_Float32Box):
                return FloatObject(float(w_dtype.value))
            if isinstance(w_dtype, boxes.W_Int64Box):
                return FloatObject(float(int(w_dtype.value)))
            if isinstance(w_dtype, boxes.W_Int32Box):
                return FloatObject(float(int(w_dtype.value)))
            if isinstance(w_dtype, boxes.W_Int16Box):
                return FloatObject(float(int(w_dtype.value)))
            if isinstance(w_dtype, boxes.W_Int8Box):
                return FloatObject(float(int(w_dtype.value)))
            if isinstance(w_dtype, IntObject):
                return FloatObject(float(w_dtype.intval))
        if tp is self.w_int:
            if isinstance(w_dtype, FloatObject):
                return IntObject(int(w_dtype.floatval))

        return w_dtype

    @specialize.arg(2)
    def call_method(self, w_obj, s, *args):
        # XXX even the hacks have hacks
        if s == 'size': # used in _array() but never called by tests
            return IntObject(0)
        if s == '__buffer__':
            # descr___buffer__ does not exist on W_Root
            return self.w_None
        return getattr(w_obj, 'descr_' + s)(self, *args)

    @specialize.arg(1)
    def interp_w(self, tp, what):
        assert isinstance(what, tp)
        return what

    def allocate_instance(self, klass, w_subtype):
        return instantiate(klass)

    def newtuple(self, list_w):
        return ListObject(list_w)

    def newdict(self, module=True):
        return DictObject({})

    @specialize.argtype(1)
    def newint(self, i):
        if isinstance(i, IntObject):
            return i
        if isinstance(i, base_int):
            return LongObject(i)
        return IntObject(i)

    def setitem(self, obj, index, value):
        obj.items[index] = value

    def exception_match(self, w_exc_type, w_check_class):
        assert isinstance(w_exc_type, W_TypeObject)
        assert isinstance(w_check_class, W_TypeObject)
        return w_exc_type.name == w_check_class.name

    def warn(self, w_msg, w_warn_type):
        pass

def is_root(w_obj):
    assert isinstance(w_obj, W_Root)
is_root.expecting = W_Root

class FloatObject(W_Root):
    tp = FakeSpace.w_float
    def __init__(self, floatval):
        self.floatval = floatval

class BoolObject(W_Root):
    tp = FakeSpace.w_bool
    def __init__(self, boolval):
        self.intval = boolval
FakeSpace.w_True = BoolObject(True)
FakeSpace.w_False = BoolObject(False)


class IntObject(W_Root):
    tp = FakeSpace.w_int
    def __init__(self, intval):
        self.intval = intval

class LongObject(W_Root):
    tp = FakeSpace.w_long
    def __init__(self, intval):
        self.intval = intval

class ListObject(W_Root):
    tp = FakeSpace.w_list
    def __init__(self, items):
        self.items = items

class DictObject(W_Root):
    tp = FakeSpace.w_dict
    def __init__(self, items):
        self.items = items

    def getdict(self, space):
        return self.items

    def getdictvalue(self, space, key):
        return self.items[key]

    def descr_memoryview(self, space, buf):
        raise oefmt(space.w_TypeError, "error")

class IterDictObject(W_Root):
    def __init__(self, space, w_dict):
        self.space = space
        self.items = w_dict.items.items()
        self.i = 0

    def __iter__(self):
        return self

    def next(self):
        space = self.space
        if self.i >= len(self.items):
            raise oefmt(space.w_StopIteration, "stop iteration")
        self.i += 1
        return self.items[self.i-1][0]

class SliceObject(W_Root):
    tp = FakeSpace.w_slice
    def __init__(self, start, stop, step):
        self.start = start
        self.stop = stop
        self.step = step

class StringObject(W_Root):
    tp = FakeSpace.w_bytes
    def __init__(self, v):
        self.v = v

class ComplexObject(W_Root):
    tp = FakeSpace.w_complex
    def __init__(self, r, i):
        self.r = r
        self.i = i

class InterpreterState(object):
    def __init__(self, code):
        self.code = code
        self.variables = {}
        self.results = []

    def run(self, space):
        self.space = space
        for stmt in self.code.statements:
            stmt.execute(self)

class Node(object):
    def __eq__(self, other):
        return (self.__class__ == other.__class__ and
                self.__dict__ == other.__dict__)

    def __ne__(self, other):
        return not self == other

    def wrap(self, space):
        raise NotImplementedError

    def execute(self, interp):
        raise NotImplementedError

class Assignment(Node):
    def __init__(self, name, expr):
        self.name = name
        self.expr = expr

    def execute(self, interp):
        interp.variables[self.name] = self.expr.execute(interp)

    def __repr__(self):
        return "%r = %r" % (self.name, self.expr)

class ArrayAssignment(Node):
    def __init__(self, name, index, expr):
        self.name = name
        self.index = index
        self.expr = expr

    def execute(self, interp):
        arr = interp.variables[self.name]
        w_index = self.index.execute(interp)
        # cast to int
        if isinstance(w_index, FloatObject):
            w_index = IntObject(int(w_index.floatval))
        w_val = self.expr.execute(interp)
        assert isinstance(arr, W_NDimArray)
        arr.descr_setitem(interp.space, w_index, w_val)

    def __repr__(self):
        return "%s[%r] = %r" % (self.name, self.index, self.expr)

class Variable(Node):
    def __init__(self, name):
        self.name = name.strip(" ")

    def execute(self, interp):
        if self.name == 'None':
            return None
        return interp.variables[self.name]

    def __repr__(self):
        return 'v(%s)' % self.name

class Operator(Node):
    def __init__(self, lhs, name, rhs):
        self.name = name
        self.lhs = lhs
        self.rhs = rhs

    def execute(self, interp):
        w_lhs = self.lhs.execute(interp)
        if isinstance(self.rhs, SliceConstant):
            w_rhs = self.rhs.wrap(interp.space)
        else:
            w_rhs = self.rhs.execute(interp)
        if not isinstance(w_lhs, W_NDimArray):
            # scalar
            dtype = get_dtype_cache(interp.space).w_float64dtype
            w_lhs = W_NDimArray.new_scalar(interp.space, dtype, w_lhs)
        assert isinstance(w_lhs, W_NDimArray)
        if self.name == '+':
            w_res = w_lhs.descr_add(interp.space, w_rhs)
        elif self.name == '*':
            w_res = w_lhs.descr_mul(interp.space, w_rhs)
        elif self.name == '-':
            w_res = w_lhs.descr_sub(interp.space, w_rhs)
        elif self.name == '**':
            w_res = w_lhs.descr_pow(interp.space, w_rhs)
        elif self.name == '->':
            if isinstance(w_rhs, FloatObject):
                w_rhs = IntObject(int(w_rhs.floatval))
            assert isinstance(w_lhs, W_NDimArray)
            w_res = w_lhs.descr_getitem(interp.space, w_rhs)
            if isinstance(w_rhs, IntObject):
                if isinstance(w_res, boxes.W_Float64Box):
                    print "access", w_lhs, "[", w_rhs.intval, "] => ", float(w_res.value)
                if isinstance(w_res, boxes.W_Float32Box):
                    print "access", w_lhs, "[", w_rhs.intval, "] => ", float(w_res.value)
                if isinstance(w_res, boxes.W_Int64Box):
                    print "access", w_lhs, "[", w_rhs.intval, "] => ", int(w_res.value)
                if isinstance(w_res, boxes.W_Int32Box):
                    print "access", w_lhs, "[", w_rhs.intval, "] => ", int(w_res.value)
        else:
            raise NotImplementedError
        if (not isinstance(w_res, W_NDimArray) and
            not isinstance(w_res, boxes.W_GenericBox)):
            dtype = get_dtype_cache(interp.space).w_float64dtype
            w_res = W_NDimArray.new_scalar(interp.space, dtype, w_res)
        return w_res

    def __repr__(self):
        return '(%r %s %r)' % (self.lhs, self.name, self.rhs)

class NumberConstant(Node):
    def __init__(self, v):
        if isinstance(v, int):
            self.v = v
        elif isinstance(v, float):
            self.v = v
        else:
            assert isinstance(v, str)
            assert len(v) > 0
            c = v[-1]
            if c == 'f':
                self.v = float(v[:-1])
            elif c == 'i':
                self.v = int(v[:-1])
            else:
                self.v = float(v)

    def __repr__(self):
        return "Const(%s)" % self.v

    def wrap(self, space):
        return space.wrap(self.v)

    def execute(self, interp):
        return interp.space.wrap(self.v)

class ComplexConstant(Node):
    def __init__(self, r, i):
        self.r = float(r)
        self.i = float(i)

    def __repr__(self):
        return 'ComplexConst(%s, %s)' % (self.r, self.i)

    def wrap(self, space):
        return space.newcomplex(self.r, self.i)

    def execute(self, interp):
        return self.wrap(interp.space)

class RangeConstant(Node):
    def __init__(self, v):
        self.v = int(v)

    def execute(self, interp):
        w_list = interp.space.newlist(
            [interp.space.newfloat(float(i)) for i in range(self.v)]
        )
        dtype = get_dtype_cache(interp.space).w_float64dtype
        return array(interp.space, w_list, w_dtype=dtype, w_order=None)

    def __repr__(self):
        return 'Range(%s)' % self.v

class Code(Node):
    def __init__(self, statements):
        self.statements = statements

    def __repr__(self):
        return "\n".join([repr(i) for i in self.statements])

class ArrayConstant(Node):
    def __init__(self, items):
        self.items = items

    def wrap(self, space):
        return space.newlist([item.wrap(space) for item in self.items])

    def execute(self, interp):
        w_list = self.wrap(interp.space)
        return array(interp.space, w_list)

    def __repr__(self):
        return "[" + ", ".join([repr(item) for item in self.items]) + "]"

class SliceConstant(Node):
    def __init__(self, start, stop, step):
        self.start = start
        self.stop = stop
        self.step = step

    def wrap(self, space):
        return SliceObject(self.start, self.stop, self.step)

    def execute(self, interp):
        return SliceObject(self.start, self.stop, self.step)

    def __repr__(self):
        return 'slice(%s,%s,%s)' % (self.start, self.stop, self.step)

class ArrayClass(Node):
    def __init__(self):
        self.v = W_NDimArray

    def execute(self, interp):
       return self.v

    def __repr__(self):
        return '<class W_NDimArray>'

class DtypeClass(Node):
    def __init__(self, dt):
        self.v = dt

    def execute(self, interp):
        if self.v == 'int':
            dtype = get_dtype_cache(interp.space).w_int64dtype
        elif self.v == 'int8':
            dtype = get_dtype_cache(interp.space).w_int8dtype
        elif self.v == 'int16':
            dtype = get_dtype_cache(interp.space).w_int16dtype
        elif self.v == 'int32':
            dtype = get_dtype_cache(interp.space).w_int32dtype
        elif self.v == 'uint':
            dtype = get_dtype_cache(interp.space).w_uint64dtype
        elif self.v == 'uint8':
            dtype = get_dtype_cache(interp.space).w_uint8dtype
        elif self.v == 'uint16':
            dtype = get_dtype_cache(interp.space).w_uint16dtype
        elif self.v == 'uint32':
            dtype = get_dtype_cache(interp.space).w_uint32dtype
        elif self.v == 'float':
            dtype = get_dtype_cache(interp.space).w_float64dtype
        elif self.v == 'float32':
            dtype = get_dtype_cache(interp.space).w_float32dtype
        else:
            raise BadToken('unknown v to dtype "%s"' % self.v)
        return dtype

    def __repr__(self):
        return '<class %s dtype>' % self.v

class Execute(Node):
    def __init__(self, expr):
        self.expr = expr

    def __repr__(self):
        return repr(self.expr)

    def execute(self, interp):
        interp.results.append(self.expr.execute(interp))

class FunctionCall(Node):
    def __init__(self, name, args):
        self.name = name.strip(" ")
        self.args = args

    def __repr__(self):
        return "%s(%s)" % (self.name, ", ".join([repr(arg)
                                                 for arg in self.args]))

    def execute(self, interp):
        arr = self.args[0].execute(interp)
        if not isinstance(arr, W_NDimArray):
            raise ArgumentNotAnArray
        if self.name in SINGLE_ARG_FUNCTIONS:
            if len(self.args) != 1 and self.name != 'sum':
                raise ArgumentMismatch
            if self.name == "sum":
                if len(self.args)>1:
                    var = self.args[1]
                    if isinstance(var, DtypeClass):
                        w_res = arr.descr_sum(interp.space, None, var.execute(interp))
                    else:
                        w_res = arr.descr_sum(interp.space,
                                          self.args[1].execute(interp))

                else:
                    w_res = arr.descr_sum(interp.space)
            elif self.name == "prod":
                w_res = arr.descr_prod(interp.space)
            elif self.name == "max":
                w_res = arr.descr_max(interp.space)
            elif self.name == "min":
                w_res = arr.descr_min(interp.space)
            elif self.name == "any":
                w_res = arr.descr_any(interp.space)
            elif self.name == "all":
                w_res = arr.descr_all(interp.space)
            elif self.name == "cumsum":
                w_res = arr.descr_cumsum(interp.space)
            elif self.name == "logical_xor_reduce":
                logical_xor = ufuncs.get(interp.space).logical_xor
                w_res = logical_xor.reduce(interp.space, arr, None)
            elif self.name == "unegative":
                neg = ufuncs.get(interp.space).negative
                w_res = neg.call(interp.space, [arr], None, 'unsafe', None)
            elif self.name == "cos":
                cos = ufuncs.get(interp.space).cos
                w_res = cos.call(interp.space, [arr], None, 'unsafe', None)
            elif self.name == "flat":
                w_res = arr.descr_get_flatiter(interp.space)
            elif self.name == "argsort":
                w_res = arr.descr_argsort(interp.space)
            elif self.name == "tostring":
                arr.descr_tostring(interp.space)
                w_res = None
            else:
                assert False # unreachable code
        elif self.name in TWO_ARG_FUNCTIONS:
            if len(self.args) != 2:
                raise ArgumentMismatch
            arg = self.args[1].execute(interp)
            if not isinstance(arg, W_NDimArray):
                raise ArgumentNotAnArray
            if self.name == "dot":
                w_res = arr.descr_dot(interp.space, arg)
            elif self.name == 'multiply':
                w_res = arr.descr_mul(interp.space, arg)
            elif self.name == 'take':
                w_res = arr.descr_take(interp.space, arg)
            elif self.name == "searchsorted":
                w_res = arr.descr_searchsorted(interp.space, arg,
                                               interp.space.newtext('left'))
            else:
                assert False # unreachable code
        elif self.name in THREE_ARG_FUNCTIONS:
            if len(self.args) != 3:
                raise ArgumentMismatch
            arg1 = self.args[1].execute(interp)
            arg2 = self.args[2].execute(interp)
            if not isinstance(arg1, W_NDimArray):
                raise ArgumentNotAnArray
            if not isinstance(arg2, W_NDimArray):
                raise ArgumentNotAnArray
            if self.name == "where":
                w_res = where(interp.space, arr, arg1, arg2)
            else:
                assert False # unreachable code
        elif self.name in TWO_ARG_FUNCTIONS_OR_NONE:
            if len(self.args) != 2:
                raise ArgumentMismatch
            arg = self.args[1].execute(interp)
            if self.name == 'view':
                w_res = arr.descr_view(interp.space, arg)
            elif self.name == 'astype':
                w_res = arr.descr_astype(interp.space, arg)
            elif self.name == 'reshape':
                w_arg = self.args[1]
                assert isinstance(w_arg, ArrayConstant)
                order = -1
                w_res = arr.reshape(interp.space, w_arg.wrap(interp.space), order)
            else:
                assert False
        else:
            raise WrongFunctionName
        if isinstance(w_res, W_NDimArray):
            return w_res
        if isinstance(w_res, FloatObject):
            dtype = get_dtype_cache(interp.space).w_float64dtype
        elif isinstance(w_res, IntObject):
            dtype = get_dtype_cache(interp.space).w_int64dtype
        elif isinstance(w_res, BoolObject):
            dtype = get_dtype_cache(interp.space).w_booldtype
        elif isinstance(w_res, boxes.W_GenericBox):
            dtype = w_res.get_dtype(interp.space)
        else:
            dtype = None
        return W_NDimArray.new_scalar(interp.space, dtype, w_res)

_REGEXES = [
    ('-?[\d\.]+(i|f)?', 'number'),
    ('\[', 'array_left'),
    (':', 'colon'),
    ('\w+', 'identifier'),
    ('\]', 'array_right'),
    ('(->)|[\+\-\*\/]+', 'operator'),
    ('=', 'assign'),
    (',', 'comma'),
    ('\|', 'pipe'),
    ('\(', 'paren_left'),
    ('\)', 'paren_right'),
]
REGEXES = []

for r, name in _REGEXES:
    REGEXES.append((re.compile(r' *(' + r + ')'), name))
del _REGEXES

class Token(object):
    def __init__(self, name, v):
        self.name = name
        self.v = v

    def __repr__(self):
        return '(%s, %s)' % (self.name, self.v)

empty = Token('', '')

class TokenStack(object):
    def __init__(self, tokens):
        self.tokens = tokens
        self.c = 0

    def pop(self):
        token = self.tokens[self.c]
        self.c += 1
        return token

    def get(self, i):
        if self.c + i >= len(self.tokens):
            return empty
        return self.tokens[self.c + i]

    def remaining(self):
        return len(self.tokens) - self.c

    def push(self):
        self.c -= 1

    def __repr__(self):
        return repr(self.tokens[self.c:])

class Parser(object):
    def tokenize(self, line):
        tokens = []
        while True:
            for r, name in REGEXES:
                m = r.match(line)
                if m is not None:
                    g = m.group(0)
                    tokens.append(Token(name, g))
                    line = line[len(g):]
                    if not line:
                        return TokenStack(tokens)
                    break
            else:
                raise TokenizerError(line)

    def parse_number_or_slice(self, tokens):
        start_tok = tokens.pop()
        if start_tok.name == 'colon':
            start = 0
        else:
            if tokens.get(0).name != 'colon':
                return NumberConstant(start_tok.v)
            start = int(start_tok.v)
            tokens.pop()
        if not tokens.get(0).name in ['colon', 'number']:
            stop = -1
            step = 1
        else:
            next = tokens.pop()
            if next.name == 'colon':
                stop = -1
                step = int(tokens.pop().v)
            else:
                stop = int(next.v)
                if tokens.get(0).name == 'colon':
                    tokens.pop()
                    step = int(tokens.pop().v)
                else:
                    step = 1
        return SliceConstant(start, stop, step)


    def parse_expression(self, tokens, accept_comma=False):
        stack = []
        while tokens.remaining():
            token = tokens.pop()
            if token.name == 'identifier':
                if tokens.remaining() and tokens.get(0).name == 'paren_left':
                    stack.append(self.parse_function_call(token.v, tokens))
                elif token.v.strip(' ') == 'ndarray':
                    stack.append(ArrayClass())
                elif token.v.strip(' ') == 'int':
                    stack.append(DtypeClass('int'))
                elif token.v.strip(' ') == 'int8':
                    stack.append(DtypeClass('int8'))
                elif token.v.strip(' ') == 'int16':
                    stack.append(DtypeClass('int16'))
                elif token.v.strip(' ') == 'int32':
                    stack.append(DtypeClass('int32'))
                elif token.v.strip(' ') == 'int64':
                    stack.append(DtypeClass('int'))
                elif token.v.strip(' ') == 'uint':
                    stack.append(DtypeClass('uint'))
                elif token.v.strip(' ') == 'uint8':
                    stack.append(DtypeClass('uint8'))
                elif token.v.strip(' ') == 'uint16':
                    stack.append(DtypeClass('uint16'))
                elif token.v.strip(' ') == 'uint32':
                    stack.append(DtypeClass('uint32'))
                elif token.v.strip(' ') == 'uint64':
                    stack.append(DtypeClass('uint'))
                elif token.v.strip(' ') == 'float':
                    stack.append(DtypeClass('float'))
                elif token.v.strip(' ') == 'float32':
                    stack.append(DtypeClass('float32'))
                elif token.v.strip(' ') == 'float64':
                    stack.append(DtypeClass('float'))
                else:
                    stack.append(Variable(token.v.strip(' ')))
            elif token.name == 'array_left':
                stack.append(ArrayConstant(self.parse_array_const(tokens)))
            elif token.name == 'operator':
                stack.append(Variable(token.v))
            elif token.name == 'number' or token.name == 'colon':
                tokens.push()
                stack.append(self.parse_number_or_slice(tokens))
            elif token.name == 'pipe':
                stack.append(RangeConstant(tokens.pop().v))
                end = tokens.pop()
                assert end.name == 'pipe'
            elif token.name == 'paren_left':
                stack.append(self.parse_complex_constant(tokens))
            elif accept_comma and token.name == 'comma':
                continue
            else:
                tokens.push()
                break
        if accept_comma:
            return stack
        stack.reverse()
        lhs = stack.pop()
        while stack:
            op = stack.pop()
            assert isinstance(op, Variable)
            rhs = stack.pop()
            lhs = Operator(lhs, op.name, rhs)
        return lhs

    def parse_function_call(self, name, tokens):
        args = []
        tokens.pop() # lparen
        while tokens.get(0).name != 'paren_right':
            args += self.parse_expression(tokens, accept_comma=True)
        return FunctionCall(name, args)

    def parse_complex_constant(self, tokens):
        r = tokens.pop()
        assert r.name == 'number'
        assert tokens.pop().name == 'comma'
        i = tokens.pop()
        assert i.name == 'number'
        assert tokens.pop().name == 'paren_right'
        return ComplexConstant(r.v, i.v)

    def parse_array_const(self, tokens):
        elems = []
        while True:
            token = tokens.pop()
            if token.name == 'number':
                elems.append(NumberConstant(token.v))
            elif token.name == 'array_left':
                elems.append(ArrayConstant(self.parse_array_const(tokens)))
            elif token.name == 'paren_left':
                elems.append(self.parse_complex_constant(tokens))
            else:
                raise BadToken()
            token = tokens.pop()
            if token.name == 'array_right':
                return elems
            assert token.name == 'comma'

    def parse_statement(self, tokens):
        if (tokens.get(0).name == 'identifier' and
            tokens.get(1).name == 'assign'):
            lhs = tokens.pop().v
            tokens.pop()
            rhs = self.parse_expression(tokens)
            return Assignment(lhs, rhs)
        elif (tokens.get(0).name == 'identifier' and
              tokens.get(1).name == 'array_left'):
            name = tokens.pop().v
            tokens.pop()
            index = self.parse_expression(tokens)
            tokens.pop()
            tokens.pop()
            return ArrayAssignment(name, index, self.parse_expression(tokens))
        return Execute(self.parse_expression(tokens))

    def parse(self, code):
        statements = []
        for line in code.split("\n"):
            if '#' in line:
                line = line.split('#', 1)[0]
            line = line.strip(" ")
            if line:
                tokens = self.tokenize(line)
                statements.append(self.parse_statement(tokens))
        return Code(statements)

def numpy_compile(code):
    parser = Parser()
    return InterpreterState(parser.parse(code))
