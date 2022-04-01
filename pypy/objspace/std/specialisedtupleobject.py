from pypy.interpreter.error import oefmt
from pypy.objspace.std.tupleobject import (W_AbstractTupleObject,
    XXPRIME_1, XXPRIME_2, XXPRIME_5, xxrotate, uhash_type)
from pypy.objspace.std.util import negate
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.unroll import unrolling_iterable
from rpython.tool.sourcetools import func_with_new_name
from rpython.rlib.longlong2float import float2longlong


class NotSpecialised(Exception):
    pass


def make_specialised_class(typetuple):
    assert type(typetuple) == tuple
    wraps = []
    for typ in typetuple:
        if typ == int:
            wraps.append(lambda space, x: space.newint(x))
        elif typ == float:
            wraps.append(lambda space, x: space.newfloat(x))
        elif typ == object:
            wraps.append(lambda space, w_x: w_x)
        else:
            assert 0

    typelen = len(typetuple)
    iter_n = unrolling_iterable(range(typelen))

    class cls(W_AbstractTupleObject):
        _immutable_fields_ = ['value%s' % i for i in iter_n]

        def __init__(self, space, *values):
            self.space = space
            assert len(values) == typelen
            for i in iter_n:
                obj = values[i]
                val_type = typetuple[i]
                if val_type == int:
                    assert isinstance(obj, int)
                elif val_type == float:
                    assert isinstance(obj, float)
                elif val_type == str:
                    assert isinstance(obj, str)
                elif val_type == object:
                    pass
                else:
                    raise AssertionError
                setattr(self, 'value%s' % i, obj)

        def length(self):
            return typelen

        def tolist(self):
            list_w = [None] * typelen
            for i in iter_n:
                value = getattr(self, 'value%s' % i)
                value = wraps[i](self.space, value)
                list_w[i] = value
            return list_w

        # same source code, but builds and returns a resizable list
        getitems_copy = func_with_new_name(tolist, 'getitems_copy')

        def descr_hash(self, space):
            acc = XXPRIME_5

            for i in iter_n:
                value = getattr(self, 'value%s' % i)
                if typetuple[i] == object:
                    lane = uhash_type(space.int_w(space.hash(value)))
                elif typetuple[i] == float:
                    # get the correct hash for float which is an
                    # integer & other less frequent cases
                    from pypy.objspace.std.floatobject import _hash_float
                    lane = uhash_type(_hash_float(space, value))
                elif typetuple[i] == int:
                    # hash for int which is different from the hash
                    # given by rpython
                    from pypy.objspace.std.intobject import _hash_int
                    lane = uhash_type(_hash_int(value))
                else:
                    raise NotImplementedError

                acc += lane * XXPRIME_2
                acc = xxrotate(acc)
                acc *= XXPRIME_1

            acc += typelen ^ (XXPRIME_5 ^ uhash_type(3527539))
            acc += (acc == uhash_type(-1)) * uhash_type(1546275796 + 1)
            return space.newint(intmask(acc))

        def descr_eq(self, space, w_other):
            if not isinstance(w_other, W_AbstractTupleObject):
                return space.w_NotImplemented
            if not isinstance(w_other, cls):
                if typelen != w_other.length():
                    return space.w_False
                for i in iter_n:
                    myval = getattr(self, 'value%s' % i)
                    otherval = w_other.getitem(space, i)
                    myval = wraps[i](self.space, myval)
                    if not space.eq_w(myval, otherval):
                        return space.w_False
                return space.w_True

            for i in iter_n:
                myval = getattr(self, 'value%s' % i)
                otherval = getattr(w_other, 'value%s' % i)
                if typetuple[i] == object:
                    if not self.space.eq_w(myval, otherval):
                        return space.w_False
                else:
                    if myval != otherval:
                        if typetuple[i] == float:
                            # issue with NaNs, which should be equal here
                            if (float2longlong(myval) ==
                                float2longlong(otherval)):
                                continue
                        return space.w_False
            return space.w_True

        descr_ne = negate(descr_eq)

        def getitem(self, space, index):
            if index < 0:
                index += typelen
            for i in iter_n:
                if index == i:
                    value = getattr(self, 'value%s' % i)
                    value = wraps[i](self.space, value)
                    return value
            raise oefmt(space.w_IndexError, "tuple index out of range")

    cls.__name__ = ('W_SpecialisedTupleObject_' +
                    ''.join([t.__name__[0] for t in typetuple]))
    _specialisations.append(cls)
    return cls

# ---------- current specialized versions ----------

_specialisations = []
Cls_ii = make_specialised_class((int, int))
Cls_oo = make_specialised_class((object, object))
Cls_ff = make_specialised_class((float, float))

def makespecialisedtuple(space, list_w):
    from pypy.objspace.std.listobject import is_plain_int1, plain_int_w
    from pypy.objspace.std.floatobject import W_FloatObject
    if len(list_w) == 2:
        w_arg1, w_arg2 = list_w
        if is_plain_int1(w_arg1):
            if is_plain_int1(w_arg2):
                return Cls_ii(space, plain_int_w(space, w_arg1),
                                     plain_int_w(space, w_arg2))
        elif type(w_arg1) is W_FloatObject:
            if type(w_arg2) is W_FloatObject:
                return Cls_ff(space, space.float_w(w_arg1), space.float_w(w_arg2))
        return Cls_oo(space, w_arg1, w_arg2)
    else:
        raise NotSpecialised

# --------------------------------------------------
# Special code based on list strategies to implement zip(),
# here with two list arguments only.  This builds a zipped
# list that differs from what the app-level code would build:
# if the source lists contain sometimes ints/floats and
# sometimes not, here we will use uniformly 'Cls_oo' instead
# of using 'Cls_ii' or 'Cls_ff' for the elements that match.
# This is a trade-off, but it looks like a good idea to keep
# the list uniform for the JIT---not to mention, it is much
# faster to move the decision out of the loop.

@specialize.arg(1)
def _build_zipped_spec(space, Cls, lst1, lst2):
    length = min(len(lst1), len(lst2))
    return [Cls(space, lst1[i], lst2[i]) for i in range(length)]

def _build_zipped_spec_oo(space, w_list1, w_list2):
    strat1 = w_list1.strategy
    strat2 = w_list2.strategy
    length = min(strat1.length(w_list1), strat2.length(w_list2))
    return [Cls_oo(space, strat1.getitem(w_list1, i),
                          strat2.getitem(w_list2, i)) for i in range(length)]

def _build_zipped_unspec(space, w_list1, w_list2):
    strat1 = w_list1.strategy
    strat2 = w_list2.strategy
    length = min(strat1.length(w_list1), strat2.length(w_list2))
    return [space.newtuple([strat1.getitem(w_list1, i),
                            strat2.getitem(w_list2, i)]) for i in range(length)]

def specialized_zip_2_lists(space, w_list1, w_list2):
    from pypy.objspace.std.listobject import W_ListObject
    if type(w_list1) is not W_ListObject or type(w_list2) is not W_ListObject:
        raise oefmt(space.w_TypeError, "expected two exact lists")

    if space.config.objspace.std.withspecialisedtuple:
        intlist1 = w_list1.getitems_int()
        if intlist1 is not None:
            intlist2 = w_list2.getitems_int()
            if intlist2 is not None:
                lst_w = _build_zipped_spec(
                        space, Cls_ii, intlist1, intlist2)
                return space.newlist(lst_w)
        else:
            floatlist1 = w_list1.getitems_float()
            if floatlist1 is not None:
                floatlist2 = w_list2.getitems_float()
                if floatlist2 is not None:
                    lst_w = _build_zipped_spec(
                        space, Cls_ff, floatlist1, floatlist2)
                    return space.newlist(lst_w)

        lst_w = _build_zipped_spec_oo(space, w_list1, w_list2)
        return space.newlist(lst_w)

    else:
        lst_w = _build_zipped_unspec(space, w_list1, w_list2)
        return space.newlist(lst_w)
