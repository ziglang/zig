import operator
from pypy.interpreter.error import OperationError, oefmt, oefmt_attribute_error
from pypy.interpreter.baseobjspace import ObjSpace
from pypy.interpreter.function import Function, Method, FunctionWithFixedCode
from pypy.interpreter.argument import Arguments
from pypy.interpreter.typedef import default_identity_hash
from rpython.tool.sourcetools import compile2, func_with_new_name
from rpython.rlib.objectmodel import specialize
from rpython.rlib import jit

@specialize.memo()
def object_getattribute(space):
    "Utility that returns the app-level descriptor object.__getattribute__."
    return space.lookup_in_type(space.w_object, '__getattribute__')

@specialize.memo()
def object_setattr(space):
    "Utility that returns the app-level descriptor object.__setattr__."
    return space.lookup_in_type(space.w_object, '__setattr__')

@specialize.memo()
def object_delattr(space):
    "Utility that returns the app-level descriptor object.__delattr__."
    return space.lookup_in_type(space.w_object, '__delattr__')

@specialize.memo()
def object_hash(space):
    "Utility that returns the app-level descriptor object.__hash__."
    return space.lookup_in_type(space.w_object, '__hash__')

@specialize.memo()
def type_eq(space):
    "Utility that returns the app-level descriptor type.__eq__."
    return space.lookup_in_type(space.w_type, '__eq__')

@specialize.memo()
def list_iter(space):
    "Utility that returns the app-level descriptor list.__iter__."
    return space.lookup_in_type(space.w_list, '__iter__')

@specialize.memo()
def tuple_iter(space):
    "Utility that returns the app-level descriptor tuple.__iter__."
    return space.lookup_in_type(space.w_tuple, '__iter__')

@specialize.memo()
def unicode_iter(space):
    "Utility that returns the app-level descriptor str.__iter__."
    return space.lookup_in_type(space.w_unicode, '__iter__')

@specialize.memo()
def dict_getitem(space):
    "Utility that returns the app-level descriptor dict.__getitem__."
    return space.lookup_in_type(space.w_dict, '__getitem__')


def raiseattrerror(space, w_obj, w_name, w_descr=None):
    # space.repr always returns an encodable string.
    if w_descr is None:
        raise oefmt_attribute_error(space,
                    w_obj, w_name, "'%T' object has no attribute %R")
    else:
        raise oefmt(space.w_AttributeError,
                    "'%T' object attribute %R is read-only", w_obj, w_name)

def get_attribute_name(space, w_obj, w_name):
    try:
        return space.text_w(w_name)
    except OperationError as e:
        if e.match(space, space.w_UnicodeEncodeError):
            raiseattrerror(space, w_obj, w_name)
        raise

def _same_class_w(space, w_obj1, w_obj2, w_typ1, w_typ2):
    return space.is_w(w_typ1, w_typ2)


class Object(object):
    def descr__getattribute__(space, w_obj, w_name):
        name = get_attribute_name(space, w_obj, w_name)
        w_descr = space.lookup(w_obj, name)
        if w_descr is not None:
            if space.is_data_descr(w_descr):
                # Only override if __get__ is defined, too, for compatibility
                # with CPython.
                w_get = space.lookup(w_descr, "__get__")
                if w_get is not None:
                    w_type = space.type(w_obj)
                    return space.get_and_call_function(w_get, w_descr, w_obj,
                                                       w_type)
        w_value = w_obj.getdictvalue(space, name)
        if w_value is not None:
            return w_value
        if w_descr is not None:
            typ = type(w_descr)
            if typ is Function or typ is FunctionWithFixedCode:
                # This shortcut is necessary if w_obj is None.  Otherwise e.g.
                # None.__eq__ would return an unbound function because calling
                # __get__ with None as the first argument returns the attribute
                # as if it was accessed through the owner (type(None).__eq__).
                return Method(space, w_descr, w_obj)
            return space.get(w_descr, w_obj)
        raiseattrerror(space, w_obj, w_name)

    def descr__setattr__(space, w_obj, w_name, w_value):
        name = get_attribute_name(space, w_obj, w_name)
        w_descr = space.lookup(w_obj, name)
        if w_descr is not None:
            if space.is_data_descr(w_descr):
                space.set(w_descr, w_obj, w_value)
                return
        if w_obj.setdictvalue(space, name, w_value):
            return
        raiseattrerror(space, w_obj, w_name, w_descr)

    def descr__delattr__(space, w_obj, w_name):
        name = get_attribute_name(space, w_obj, w_name)
        w_descr = space.lookup(w_obj, name)
        if w_descr is not None:
            if space.is_data_descr(w_descr):
                space.delete(w_descr, w_obj)
                return
        if w_obj.deldictvalue(space, name):
            return
        raiseattrerror(space, w_obj, w_name, w_descr)

    def descr__init__(space, w_obj, __args__):
        pass

def get_printable_location(itergreenkey, w_itemtype):
    return "DescrOperation.contains [%s, %s]" % (
            itergreenkey.iterator_greenkey_printable(),
            w_itemtype.getname(w_itemtype.space))

contains_jitdriver = jit.JitDriver(name='contains',
        greens=['itergreenkey', 'w_itemtype'], reds='auto',
        get_printable_location=get_printable_location)

class DescrOperation(object):
    # This is meant to be a *mixin*.

    def is_data_descr(space, w_obj):
        return (space.lookup(w_obj, '__set__') is not None or
                space.lookup(w_obj, '__delete__') is not None)

    def get_and_call_args(space, w_descr, w_obj, args):
        # a special case for performance and to avoid infinite recursion
        if isinstance(w_descr, Function):
            return w_descr.call_obj_args(w_obj, args)
        else:
            w_impl = space.get(w_descr, w_obj)
            return space.call_args(w_impl, args)

    def get_and_call_function(space, w_descr, w_obj, *args_w):
        typ = type(w_descr)
        # a special case for performance and to avoid infinite recursion
        # (possibly; but note issue3255 in the get() metehod, which might
        # also remove the infinite recursion here)
        if typ is Function or typ is FunctionWithFixedCode:
            # isinstance(typ, Function) would not be correct here:
            # for a BuiltinFunction we must not use that shortcut, because a
            # builtin function binds differently than a normal function
            # see test_builtin_as_special_method_is_not_bound
            # in interpreter/test/test_function.py

            # the fastcall paths are purely for performance, but the resulting
            # increase of speed is huge
            return w_descr.funccall(w_obj, *args_w)
        else:
            args = Arguments(space, list(args_w))
            w_impl = space.get(w_descr, w_obj)
            return space.call_args(w_impl, args)

    def call_args(space, w_obj, args):
        # two special cases for performance
        if isinstance(w_obj, Function):
            return w_obj.call_args(args)
        if isinstance(w_obj, Method):
            return w_obj.call_args(args)
        w_descr = space.lookup(w_obj, '__call__')
        if w_descr is None:
            raise oefmt(space.w_TypeError,
                        "'%T' object is not callable", w_obj)
        return space.get_and_call_args(w_descr, w_obj, args)

    def get(space, w_descr, w_obj, w_type=None):
        w_get = space.lookup(w_descr, '__get__')
        if w_get is None:
            return w_descr
        if w_type is None:
            w_type = space.type(w_obj)
        # special case: don't use get_and_call_function() here.
        # see test_issue3255 in apptest_descriptor.py
        return space.call_function(w_get, w_descr, w_obj, w_type)

    def set(space, w_descr, w_obj, w_val):
        w_set = space.lookup(w_descr, '__set__')
        if w_set is None:
            raise oefmt(space.w_AttributeError,
                        "'%T' object is not a descriptor with set", w_descr)
        return space.get_and_call_function(w_set, w_descr, w_obj, w_val)

    def delete(space, w_descr, w_obj):
        w_delete = space.lookup(w_descr, '__delete__')
        if w_delete is None:
            raise oefmt(space.w_AttributeError,
                        "'%T' object is not a descriptor with delete", w_descr)
        return space.get_and_call_function(w_delete, w_descr, w_obj)

    def getattr(space, w_obj, w_name):
        # may be overridden in StdObjSpace
        w_descr = space.lookup(w_obj, '__getattribute__')
        return space._handle_getattribute(w_descr, w_obj, w_name)

    def _handle_getattribute(space, w_descr, w_obj, w_name):
        try:
            if w_descr is None:   # obscure case
                raise OperationError(space.w_AttributeError, space.w_None)
            return space.get_and_call_function(w_descr, w_obj, w_name)
        except OperationError as e:
            if not e.match(space, space.w_AttributeError):
                raise
            w_descr = space.lookup(w_obj, '__getattr__')
            if w_descr is None:
                raise
            return space.get_and_call_function(w_descr, w_obj, w_name)

    def setattr(space, w_obj, w_name, w_val):
        w_descr = space.lookup(w_obj, '__setattr__')
        if w_descr is None:
            raise oefmt(space.w_AttributeError,
                        "'%T' object is readonly", w_obj)
        return space.get_and_call_function(w_descr, w_obj, w_name, w_val)

    def delattr(space, w_obj, w_name):
        w_descr = space.lookup(w_obj, '__delattr__')
        if w_descr is None:
            raise oefmt(space.w_AttributeError,
                        "'%T' object does not support attribute removal",
                        w_obj)
        return space.get_and_call_function(w_descr, w_obj, w_name)

    def is_true(space, w_obj):
        w_descr = space.lookup(w_obj, "__bool__")
        if w_descr is None:
            w_descr = space.lookup(w_obj, "__len__")
            if w_descr is None:
                return True
            # call __len__
            w_res = space.get_and_call_function(w_descr, w_obj)
            return space._check_len_result(space.index(w_res)) != 0
        # call __bool__
        w_res = space.get_and_call_function(w_descr, w_obj)
        # more shortcuts for common cases
        if space.is_w(w_res, space.w_False):
            return False
        if space.is_w(w_res, space.w_True):
            return True
        w_restype = space.type(w_res)
        # Note there is no check for bool here because the only possible
        # instances of bool are w_False and w_True, which are checked above.
        raise oefmt(space.w_TypeError,
                    "__bool__ should return bool, returned %T", w_obj)

    def nonzero(space, w_obj):
        if space.is_true(w_obj):
            return space.w_True
        else:
            return space.w_False

    def _len(space, w_obj):
        w_descr = space.lookup(w_obj, '__len__')
        if w_descr is None:
            raise oefmt(space.w_TypeError, "'%T' has no length", w_obj)
        return space.get_and_call_function(w_descr, w_obj)

    def len_w(space, w_obj):
        w_res = space._len(w_obj)
        return space._check_len_result(space.index(w_res))

    def len(space, w_obj):
        w_res = space.index(space._len(w_obj))
        # check for error or overflow
        space._check_len_result(w_res)
        return w_res

    def _check_len_result(space, w_int):
        # Will complain if result is too big.
        assert space.isinstance_w(w_int, space.w_int)
        if space.is_true(space.lt(w_int, space.newint(0))):
            raise oefmt(space.w_ValueError, "__len__() should return >= 0")
        result = space.getindex_w(w_int, space.w_OverflowError)
        assert result >= 0
        return result

    def is_iterable(space, w_obj):
        w_descr = space.lookup(w_obj, '__iter__')
        if w_descr is None:
            if space.type(w_obj).flag_map_or_seq != 'M':
                w_descr = space.lookup(w_obj, '__getitem__')
            if w_descr is None:
                return False
        return True

    def iter(space, w_obj):
        w_descr = space.lookup(w_obj, '__iter__')
        if w_descr is None:
            if space.type(w_obj).flag_map_or_seq != 'M':
                w_descr = space.lookup(w_obj, '__getitem__')
            if w_descr is None:
                raise oefmt(space.w_TypeError,
                            "'%T' object is not iterable", w_obj)
            return space.newseqiter(w_obj)
        w_iter = space.get_and_call_function(w_descr, w_obj)
        w_next = space.lookup(w_iter, '__next__')
        if w_next is None:
            raise oefmt(space.w_TypeError, "iter() returned non-iterator")
        return w_iter

    def next(space, w_obj):
        w_descr = space.lookup(w_obj, '__next__')
        if w_descr is None:
            raise oefmt(space.w_TypeError,
                        "'%T' object is not an iterator", w_obj)
        return space.get_and_call_function(w_descr, w_obj)

    def getitem(space, w_obj, w_key):
        w_descr = space.lookup(w_obj, '__getitem__')
        if w_descr is None and space.isinstance_w(w_obj, space.w_type):
            # you've got to be kidding me :-( - cpython does the same
            if space.is_w(w_obj, space.w_type):
                from pypy.objspace.std.util import generic_alias_class_getitem
                return generic_alias_class_getitem(space, w_obj, w_key)
            try:
                w_descr = space.getattr(w_obj, space.newtext('__class_getitem__'))
            except OperationError as e:
                if e.match(space, space.w_AttributeError):
                    w_descr = None
                else:
                    raise e
        if w_descr is None:
            raise oefmt(space.w_TypeError,
                        "'%T' object is not subscriptable (key %R)",
                        w_obj, w_key)
        return space.get_and_call_function(w_descr, w_obj, w_key)

    def setitem(space, w_obj, w_key, w_val):
        w_descr = space.lookup(w_obj, '__setitem__')
        if w_descr is None:
            raise oefmt(space.w_TypeError,
                        "'%T' object does not support item assignment", w_obj)
        return space.get_and_call_function(w_descr, w_obj, w_key, w_val)

    def delitem(space, w_obj, w_key):
        w_descr = space.lookup(w_obj, '__delitem__')
        if w_descr is None:
            raise oefmt(space.w_TypeError,
                        "'%T' object does not support item deletion", w_obj)
        return space.get_and_call_function(w_descr, w_obj, w_key)

    def format(space, w_obj, w_format_spec):
        w_descr = space.lookup(w_obj, '__format__')
        if w_descr is None:
            raise oefmt(space.w_TypeError,
                        "'%T' object does not define __format__", w_obj)
        w_res = space.get_and_call_function(w_descr, w_obj, w_format_spec)
        if not space.isinstance_w(w_res, space.w_unicode):
            raise oefmt(space.w_TypeError,
                        "%T.__format__ must return string, not %T",
                        w_obj, w_res)
        return w_res

    def pow(space, w_obj1, w_obj2, w_obj3):
        w_typ1 = space.type(w_obj1)
        w_typ2 = space.type(w_obj2)
        w_left_src, w_left_impl = space.lookup_in_type_where(w_typ1, '__pow__')
        if space.is_w(w_typ1, w_typ2):
            w_right_impl = None
        else:
            w_right_src, w_right_impl = space.lookup_in_type_where(w_typ2, '__rpow__')
            # sse binop_impl
            if (w_left_src is not w_right_src
                and space.issubtype_w(w_typ2, w_typ1)):
                if (w_left_src and w_right_src and
                    not space.abstract_issubclass_w(w_left_src, w_right_src) and
                    not space.abstract_issubclass_w(w_typ1, w_right_src)):
                    w_obj1, w_obj2 = w_obj2, w_obj1
                    w_left_impl, w_right_impl = w_right_impl, w_left_impl
        if w_left_impl is not None:
            if space.is_w(w_obj3, space.w_None):
                w_res = space.get_and_call_function(w_left_impl, w_obj1, w_obj2)
            else:
                w_res = space.get_and_call_function(w_left_impl, w_obj1, w_obj2, w_obj3)
            if _check_notimplemented(space, w_res):
                return w_res
        if w_right_impl is not None:
            if space.is_w(w_obj3, space.w_None):
                w_res = space.get_and_call_function(w_right_impl, w_obj2, w_obj1)
            else:
                w_res = space.get_and_call_function(w_right_impl, w_obj2, w_obj1,
                                                   w_obj3)
            if _check_notimplemented(space, w_res):
                return w_res

        raise oefmt(space.w_TypeError, "operands do not support **")

    def inplace_pow(space, w_lhs, w_rhs):
        w_impl = space.lookup(w_lhs, '__ipow__')
        if w_impl is not None:
            w_res = space.get_and_call_function(w_impl, w_lhs, w_rhs)
            if _check_notimplemented(space, w_res):
                return w_res
        return space.pow(w_lhs, w_rhs, space.w_None)

    def contains(space, w_container, w_item):
        w_descr = space.lookup(w_container, '__contains__')
        if w_descr is not None:
            w_result = space.get_and_call_function(w_descr, w_container, w_item)
            return space.nonzero(w_result)
        return space.sequence_contains(w_container, w_item)

    def sequence_contains(space, w_container, w_item):
        w_iter = space.iter(w_container)
        itergreenkey = space.iterator_greenkey(w_iter)
        w_itemtype = space.type(w_item)
        while 1:
            contains_jitdriver.jit_merge_point(itergreenkey=itergreenkey, w_itemtype=w_itemtype)
            try:
                w_next = space.next(w_iter)
            except OperationError as e:
                if not e.match(space, space.w_StopIteration):
                    raise
                return space.w_False
            if space.eq_w(w_next, w_item):
                return space.w_True

    def sequence_count(space, w_container, w_item):
        w_iter = space.iter(w_container)
        count = 0
        while 1:
            try:
                w_next = space.next(w_iter)
            except OperationError as e:
                if not e.match(space, space.w_StopIteration):
                    raise
                return space.newint(count)
            if space.eq_w(w_next, w_item):
                count += 1

    def sequence_index(space, w_container, w_item):
        w_iter = space.iter(w_container)
        index = 0
        while 1:
            try:
                w_next = space.next(w_iter)
            except OperationError as e:
                if not e.match(space, space.w_StopIteration):
                    raise
                raise oefmt(space.w_ValueError,
                            "sequence.index(x): x not in sequence")
            if space.eq_w(w_next, w_item):
                return space.newint(index)
            index += 1

    def hash_w(space, w_obj):
        """compute the unwrapped hash of w_obj"""
        w_hash = space.lookup(w_obj, '__hash__')
        if w_hash is None:
            # xxx there used to be logic about "do we have __eq__ or __cmp__"
            # here, but it does not really make sense, as 'object' has a
            # default __hash__.  This path should only be taken under very
            # obscure circumstances.
            return space.int_w(default_identity_hash(space, w_obj))
        if space.is_w(w_hash, space.w_None):
            raise oefmt(space.w_TypeError,
                        "unhashable type: '%T'", w_obj)
        w_result = space.get_and_call_function(w_hash, w_obj)
        if not space.isinstance_w(w_result, space.w_int):
            raise oefmt(space.w_TypeError,
                        "__hash__ method should return an integer not '%T'", w_result)

        from pypy.objspace.std.intobject import (
            W_AbstractIntObject, W_IntObject)
        if not isinstance(w_result, W_IntObject):
            # a non W_IntObject int, assume long-like
            assert isinstance(w_result, W_AbstractIntObject)
            w_result = w_result.descr_hash(space)
        result = space.int_w(w_result)
        # turn -1 into -2 without using a condition, which would
        # create a potential bridge in the JIT
        result -= (result == -1)
        return result

    def hash(space, w_obj):
        return space.newint(space.hash_w(w_obj))

    def issubtype_w(space, w_sub, w_type):
        return space._type_issubtype(w_sub, w_type)

    def issubtype(space, w_sub, w_type):
        return space.newbool(space._type_issubtype(w_sub, w_type))

    @specialize.arg_or_var(2)
    def isinstance_w(space, w_inst, w_type):
        return space._type_isinstance(w_inst, w_type)

    @specialize.arg_or_var(2)
    def isinstance(space, w_inst, w_type):
        return space.newbool(space.isinstance_w(w_inst, w_type))

    def index(space, w_obj):
        if space.isinstance_w(w_obj, space.w_int):
            return w_obj
        w_impl = space.lookup(w_obj, '__index__')
        if w_impl is None:
            raise oefmt(space.w_TypeError,
                        "'%T' object cannot be interpreted as an integer",
                        w_obj)
        w_result = space.get_and_call_function(w_impl, w_obj)

        if space.is_w(space.type(w_result), space.w_int):
            return w_result
        if space.isinstance_w(w_result, space.w_int):
            tp = space.type(w_result).name
            space.warn(space.newtext(
                "__index__ returned non-int (type %s).  "
                "The ability to return an instance of a strict subclass of int "
                "is deprecated, and may be removed in a future version of "
                "Python." % (tp,)), space.w_DeprecationWarning)
            return w_result
        raise oefmt(space.w_TypeError,
                    "__index__ returned non-int (type %T)", w_result)


# helpers

def _check_notimplemented(space, w_obj):
    return not space.is_w(w_obj, space.w_NotImplemented)

def _invoke_binop(space, w_impl, w_obj1, w_obj2):
    if w_impl is not None:
        w_res = space.get_and_call_function(w_impl, w_obj1, w_obj2)
        if _check_notimplemented(space, w_res):
            return w_res
    return None

class PrintCache(object):
    def __init__(self, space):
        self.w_print = space.getattr(space.builtin, space.newtext("print"))
def _call_binop_impl(space, w_obj1, w_obj2, left, right, seq_bug_compat):
    w_typ1 = space.type(w_obj1)
    w_typ2 = space.type(w_obj2)
    w_left_src, w_left_impl = space.lookup_in_type_where(w_typ1, left)
    if space.is_w(w_typ1, w_typ2):
        w_right_impl = None
    else:
        w_right_src, w_right_impl = space.lookup_in_type_where(w_typ2, right)
        # the logic to decide if the reverse operation should be tried
        # before the direct one is very obscure.  For now, and for
        # sanity reasons, we just compare the two places where the
        # __xxx__ and __rxxx__ methods where found by identity.
        # Note that space.is_w() is potentially not happy if one of them
        # is None...
        if w_right_src and (w_left_src is not w_right_src) and w_left_src:
            # 'seq_bug_compat' is for cpython bug-to-bug compatibility:
            # see objspace/std/test/test_unicodeobject.*concat_overrides
            # and objspace/test/test_descrobject.*rmul_overrides.
            # For cases like "unicode + string subclass".
            if ((seq_bug_compat and w_typ1.flag_sequence_bug_compat
                                and not w_typ2.flag_sequence_bug_compat)
                    # the non-bug-compat part is the following check:
                    or space.issubtype_w(w_typ2, w_typ1)):
                if (not space.abstract_issubclass_w(w_left_src, w_right_src) and
                    not space.abstract_issubclass_w(w_typ1, w_right_src)):
                    w_obj1, w_obj2 = w_obj2, w_obj1
                    w_left_impl, w_right_impl = w_right_impl, w_left_impl

    w_res = _invoke_binop(space, w_left_impl, w_obj1, w_obj2)
    if w_res is not None:
        return w_res
    return _invoke_binop(space, w_right_impl, w_obj2, w_obj1)

# regular methods def helpers

def _make_binop_impl(symbol, specialnames):
    left, right = specialnames
    errormsg = "unsupported operand type(s) for %s: '%%N' and '%%N'" % (
        symbol.replace('%', '%%'),)
    seq_bug_compat = (symbol == '+' or symbol == '*')

    printerrormsg = None
    if symbol == ">>":
        printerrormsg = errormsg + '. Did you mean "print(<message>, file=<output_stream>)"?'
    if symbol == "-":
        printerrormsg = errormsg + '. Did you mean "print(<-number>)"?'

    def binop_impl(space, w_obj1, w_obj2):
        w_res = _call_binop_impl(space, w_obj1, w_obj2, left, right, seq_bug_compat)
        if w_res is not None:
            return w_res
        w_typ1 = space.type(w_obj1)
        w_typ2 = space.type(w_obj2)
        if printerrormsg is not None and w_obj1 is space.fromcache(PrintCache).w_print:
            raise oefmt(space.w_TypeError, printerrormsg, w_typ1, w_typ2)
        raise oefmt(space.w_TypeError, errormsg, w_typ1, w_typ2)

    return func_with_new_name(binop_impl, "binop_%s_impl"%left.strip('_'))

def _invoke_comparison(space, w_descr, w_obj1, w_obj2):
    if w_descr is not None:
        # a special case for performance (see get_and_call_function) but
        # also avoids binding via __get__ when unnecessary; in
        # particular when w_obj1 is None, __get__(None, type(None))
        # won't actually bind =]
        typ = type(w_descr)
        if typ is Function or typ is FunctionWithFixedCode:
            w_res = w_descr.funccall(w_obj1, w_obj2)
        else:
            try:
                w_impl = space.get(w_descr, w_obj1)
            except OperationError as e:
                # see testForExceptionsRaisedInInstanceGetattr2 in
                # test_class
                if not e.match(space, space.w_AttributeError):
                    raise
                return None
            else:
                w_res = space.call_function(w_impl, w_obj2)
        if _check_notimplemented(space, w_res):
            return w_res
    return None

def _make_comparison_impl(symbol, specialnames):
    left, right = specialnames
    op = getattr(operator, left)
    def comparison_impl(space, w_obj1, w_obj2):
        w_orig_obj1 = w_obj1
        w_orig_obj2 = w_obj2
        w_typ1 = space.type(w_obj1)
        w_typ2 = space.type(w_obj2)
        w_left_src, w_left_impl = space.lookup_in_type_where(w_typ1, left)
        w_first = w_obj1
        w_second = w_obj2

        w_right_src, w_right_impl = space.lookup_in_type_where(w_typ2,right)
        if space.is_w(w_typ1, w_typ2):
            # if the type is the same, then don't reverse: try
            # left first, right next.
            pass
        elif space.issubtype_w(w_typ2, w_typ1):
            # if typ2 is a subclass of typ1.
            w_obj1, w_obj2 = w_obj2, w_obj1
            w_left_impl, w_right_impl = w_right_impl, w_left_impl

        w_res = _invoke_comparison(space, w_left_impl, w_obj1, w_obj2)
        if w_res is not None:
            return w_res
        w_res = _invoke_comparison(space, w_right_impl, w_obj2, w_obj1)
        if w_res is not None:
            return w_res
        #
        # we did not find any special method, let's do the default logic for
        # == and !=
        if left == '__eq__':
            if space.is_w(w_obj1, w_obj2):
                return space.w_True
            else:
                return space.w_False
        elif left == '__ne__':
            if space.is_w(w_obj1, w_obj2):
                return space.w_False
            else:
                return space.w_True
        #
        # if we arrived here, they are unorderable
        raise oefmt(space.w_TypeError,
                    "'%s' not supported between instances of '%T' and '%T'",
                    symbol, w_orig_obj1, w_orig_obj2)

    return func_with_new_name(comparison_impl, 'comparison_%s_impl'%left.strip('_'))

def _make_inplace_impl(symbol, specialnames):
    specialname, = specialnames
    assert specialname.startswith('__i') and specialname.endswith('__')
    noninplacespacemethod = specialname[3:-2]
    if noninplacespacemethod in ['or', 'and']:
        noninplacespacemethod += '_'     # not too clean
    seq_bug_compat = (symbol == '+=' or symbol == '*=')
    rhs_method = '__r' + specialname[3:]
    lhs_method = '__' + specialname[3:]
    errormsg = "unsupported operand type(s) for %s: '%%N' and '%%N'" % (
        symbol.replace('%', '%%'),)

    def inplace_impl(space, w_lhs, w_rhs):
        w_impl = space.lookup(w_lhs, specialname)
        if w_impl is not None:
            # 'seq_bug_compat' is for cpython bug-to-bug compatibility:
            # see objspace/test/test_descrobject.*rmul_overrides.
            # For cases like "list += object-overriding-__radd__".
            if (seq_bug_compat and space.type(w_lhs).flag_sequence_bug_compat
                           and not space.type(w_rhs).flag_sequence_bug_compat):
                w_res = _invoke_binop(space, space.lookup(w_rhs, rhs_method),
                                      w_rhs, w_lhs)
                if w_res is not None:
                    return w_res
                # xxx if __radd__ is defined but returns NotImplemented,
                # then it might be called again below.  Oh well, too bad.
                # Anyway that's a case where we're likely to end up in
                # a TypeError.
            #
            w_res = space.get_and_call_function(w_impl, w_lhs, w_rhs)
            if _check_notimplemented(space, w_res):
                return w_res

        w_res = _call_binop_impl(space, w_lhs, w_rhs, lhs_method,
                                 rhs_method, seq_bug_compat)
        if w_res is not None:
            return w_res

        w_typ1 = space.type(w_lhs)
        w_typ2 = space.type(w_rhs)
        raise oefmt(space.w_TypeError, errormsg, w_typ1, w_typ2)

    return func_with_new_name(inplace_impl, 'inplace_%s_impl'%specialname.strip('_'))

def _make_unaryop_impl(symbol, specialnames):
    specialname, = specialnames
    errormsg = "unsupported operand type for unary %s: '%%T'" % symbol
    def unaryop_impl(space, w_obj):
        w_impl = space.lookup(w_obj, specialname)
        if w_impl is None:
            raise oefmt(space.w_TypeError, errormsg, w_obj)
        return space.get_and_call_function(w_impl, w_obj)
    return func_with_new_name(unaryop_impl, 'unaryop_%s_impl'%specialname.strip('_'))

# the following seven operations are really better to generate with
# string-templating (and maybe we should consider this for
# more of the above manually-coded operations as well)

for targetname, specialname, checkerspec in [
    ('float', '__float__', ("space.w_float",))]:

    l = ["space.isinstance_w(w_result, %s)" % x
                for x in checkerspec]
    checker = " or ".join(l)
    msg = "unsupported operand type for %(targetname)s(): '%%T'"
    msg = msg % locals()
    source = """if 1:
        def %(targetname)s(space, w_obj):
            w_impl = space.lookup(w_obj, %(specialname)r)
            if w_impl is None:
                raise oefmt(space.w_TypeError,
                            %(msg)r,
                            w_obj)
            w_result = space.get_and_call_function(w_impl, w_obj)

            if %(checker)s:
                return w_result
            raise oefmt(space.w_TypeError,
                        "%(specialname)s returned non-%(targetname)s (type "
                        "'%%T')", w_result)
        assert not hasattr(DescrOperation, %(targetname)r)
        DescrOperation.%(targetname)s = %(targetname)s
        del %(targetname)s
        \n""" % locals()
    exec compile2(source)

for targetname, specialname in [
    ('str', '__str__'),
    ('repr', '__repr__')]:

    source = """if 1:
        def %(targetname)s(space, w_obj):
            w_impl = space.lookup(w_obj, %(specialname)r)
            if w_impl is None:
                raise oefmt(space.w_TypeError,
                            "unsupported operand type for %(targetname)s(): "
                            "'%%T'", w_obj)
            w_result = space.get_and_call_function(w_impl, w_obj)
            if space.isinstance_w(w_result, space.w_unicode):
                return w_result

            raise oefmt(space.w_TypeError,
                        "%(specialname)s returned non-string (type "
                        "'%%T')", w_result)
        assert not hasattr(DescrOperation, %(targetname)r)
        DescrOperation.%(targetname)s = %(targetname)s
        del %(targetname)s
        \n""" % locals()
    exec compile2(source)

# add default operation implementations for all still missing ops

for _name, _symbol, _arity, _specialnames in ObjSpace.MethodTable:
    if not hasattr(DescrOperation, _name):
        _impl_maker = None
        if _arity == 2 and _name in ['lt', 'le', 'gt', 'ge', 'ne', 'eq']:
            #print "comparison", _specialnames
            _impl_maker = _make_comparison_impl
        elif _arity == 2 and _name.startswith('inplace_'):
            #print "inplace", _specialnames
            _impl_maker = _make_inplace_impl
        elif _arity == 2 and len(_specialnames) == 2:
            #print "binop", _specialnames
            _impl_maker = _make_binop_impl
        elif _arity == 1 and len(_specialnames) == 1 and _name != 'int':
            #print "unaryop", _specialnames
            _impl_maker = _make_unaryop_impl
        if _impl_maker:
            setattr(DescrOperation,_name,_impl_maker(_symbol,_specialnames))
        elif _name not in ['is_', 'id','type','issubtype', 'int',
                           # not really to be defined in DescrOperation
                           'ord', 'unichr', 'unicode']:
            raise Exception("missing def for operation %s" % _name)
