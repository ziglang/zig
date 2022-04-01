"""Slice object"""

import sys
from pypy.interpreter import gateway
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.typedef import GetSetProperty, TypeDef
from rpython.rlib.objectmodel import specialize
from rpython.rlib import jit


class W_SliceObject(W_Root):
    _immutable_fields_ = ['w_start', 'w_stop', 'w_step']

    def __init__(self, w_start, w_stop, w_step):
        assert w_start is not None
        assert w_stop is not None
        assert w_step is not None
        self.w_start = w_start
        self.w_stop = w_stop
        self.w_step = w_step

    def unwrap(w_slice, space):
        return slice(space.unwrap(w_slice.w_start), space.unwrap(w_slice.w_stop), space.unwrap(w_slice.w_step))

    def indices3(w_slice, space, length):
        if space.is_w(w_slice.w_step, space.w_None):
            step = 1
        else:
            step = _eval_slice_index(space, w_slice.w_step)
            if step == 0:
                raise oefmt(space.w_ValueError, "slice step cannot be zero")
        if space.is_w(w_slice.w_start, space.w_None):
            if step < 0:
                start = length - 1
            else:
                start = 0
        else:
            start = _eval_slice_index(space, w_slice.w_start)
            if start < 0:
                start += length
                if start < 0:
                    if step < 0:
                        start = -1
                    else:
                        start = 0
            elif start >= length:
                if step < 0:
                    start = length - 1
                else:
                    start = length
        if space.is_w(w_slice.w_stop, space.w_None):
            if step < 0:
                stop = -1
            else:
                stop = length
        else:
            stop = _eval_slice_index(space, w_slice.w_stop)
            if stop < 0:
                stop += length
                if stop < 0:
                    if step < 0:
                        stop = -1
                    else:
                        stop = 0
            elif stop >= length:
                if step < 0:
                    stop = length - 1
                else:
                    stop = length
        return start, stop, step

    def indices4(w_slice, space, length):
        start, stop, step = w_slice.indices3(space, length)
        if (step < 0 and stop >= start) or (step > 0 and start >= stop):
            slicelength = 0
        elif step < 0:
            slicelength = (stop - start + 1) / step + 1
        else:
            slicelength = (stop - start - 1) / step + 1
        return start, stop, step, slicelength

    def __repr__(self):
        return "<W_SliceObject(%r, %r, %r)>" % (
            self.w_start, self.w_stop, self.w_step)

    @staticmethod
    def descr__new__(space, w_slicetype, args_w):
        from pypy.objspace.std.sliceobject import W_SliceObject
        w_start = space.w_None
        w_stop = space.w_None
        w_step = space.w_None
        if len(args_w) == 1:
            w_stop, = args_w
        elif len(args_w) == 2:
            w_start, w_stop = args_w
        elif len(args_w) == 3:
            w_start, w_stop, w_step = args_w
        elif len(args_w) > 3:
            raise oefmt(space.w_TypeError, "slice() takes at most 3 arguments")
        else:
            raise oefmt(space.w_TypeError, "slice() takes at least 1 argument")
        w_obj = space.allocate_instance(W_SliceObject, w_slicetype)
        W_SliceObject.__init__(w_obj, w_start, w_stop, w_step)
        return w_obj

    def descr_repr(self, space):
        return space.newtext("slice(%s, %s, %s)" % (
            space.text_w(space.repr(self.w_start)),
            space.text_w(space.repr(self.w_stop)),
            space.text_w(space.repr(self.w_step))))

    def descr__reduce__(self, space):
        from pypy.objspace.std.sliceobject import W_SliceObject
        assert isinstance(self, W_SliceObject)
        return space.newtuple([
            space.type(self),
            space.newtuple([self.w_start, self.w_stop, self.w_step])])

    def descr_eq(self, space, w_other):
        # We need this because CPython considers that slice1 == slice1
        # is *always* True (e.g. even if slice1 was built with non-comparable
        # parameters
        if space.is_w(self, w_other):
            return space.w_True
        if not isinstance(w_other, W_SliceObject):
            return space.w_NotImplemented
        if space.eq_w(self.w_start, w_other.w_start) and \
           space.eq_w(self.w_stop, w_other.w_stop) and \
           space.eq_w(self.w_step, w_other.w_step):
            return space.w_True
        else:
            return space.w_False

    def descr_ne(self, space, w_other):
        if space.is_w(self, w_other):
            return space.w_False
        if not isinstance(w_other, W_SliceObject):
            return space.w_NotImplemented
        if space.eq_w(self.w_start, w_other.w_start) and \
           space.eq_w(self.w_stop, w_other.w_stop) and \
           space.eq_w(self.w_step, w_other.w_step):
            return space.w_False
        else:
            return space.w_True

    def descr_lt(self, space, w_other):
        if space.is_w(self, w_other):
            return space.w_False   # see comments in descr_eq()
        if not isinstance(w_other, W_SliceObject):
            return space.w_NotImplemented
        if space.eq_w(self.w_start, w_other.w_start):
            if space.eq_w(self.w_stop, w_other.w_stop):
                return space.lt(self.w_step, w_other.w_step)
            else:
                return space.lt(self.w_stop, w_other.w_stop)
        else:
            return space.lt(self.w_start, w_other.w_start)

    def descr_indices(self, space, w_length):
        """S.indices(len) -> (start, stop, stride)

        Assuming a sequence of length len, calculate the start and stop
        indices, and the stride length of the extended slice described by
        S. Out of bounds indices are clipped in a manner consistent with the
        handling of normal slices.
        """
        # like CPython 3.5, we duplicate this whole functionality for
        # this rarely-used method instead of using the existing logic
        # in indices3(), just to support 'slice(a,b,c).indices(d)' where
        # all of a, b, c and d are very large integers.
        return app_indices(space, self.w_start, self.w_stop,
                           self.w_step, w_length)

    @staticmethod
    def eval_slice_index(space, w_int):
        """Helper for cpyext"""
        return _eval_slice_index(space, w_int)


def slicewprop(name):
    def fget(space, w_obj):
        from pypy.objspace.std.sliceobject import W_SliceObject
        if not isinstance(w_obj, W_SliceObject):
            raise oefmt(space.w_TypeError, "descriptor is for 'slice'")
        return getattr(w_obj, name)
    return GetSetProperty(fget)

W_SliceObject.typedef = TypeDef("slice",
    __doc__ = '''slice([start,] stop[, step])

Create a slice object.  This is used for extended slicing (e.g. a[0:10:2]).''',
    __new__ = gateway.interp2app(W_SliceObject.descr__new__),
    __repr__ = gateway.interp2app(W_SliceObject.descr_repr),
    __hash__ = None,
    __reduce__ = gateway.interp2app(W_SliceObject.descr__reduce__),

    __eq__ = gateway.interp2app(W_SliceObject.descr_eq),
    __ne__ = gateway.interp2app(W_SliceObject.descr_ne),
    __lt__ = gateway.interp2app(W_SliceObject.descr_lt),

    start = slicewprop('w_start'),
    stop = slicewprop('w_stop'),
    step = slicewprop('w_step'),
    indices = gateway.interp2app(W_SliceObject.descr_indices),
)
W_SliceObject.typedef.acceptable_as_base_class = False


# utility functions
def _eval_slice_index(space, w_int):
    # note that it is the *callers* responsibility to check for w_None
    # otherwise you can get funny error messages
    try:
        return space.getindex_w(w_int, None) # clamp if long integer too large
    except OperationError as err:
        if not err.match(space, space.w_TypeError):
            raise
        raise oefmt(space.w_TypeError,
                    "slice indices must be integers or None or have an "
                    "__index__ method")

def adapt_lower_bound(space, size, w_index):
    index = _eval_slice_index(space, w_index)
    if index < 0:
        index = index + size
        if index < 0:
            index = 0
    assert index >= 0
    return index

def unwrap_start_stop(space, size, w_start, w_end):
    if space.is_none(w_start):
        start = 0
    else:
        start = adapt_lower_bound(space, size, w_start)

    if space.is_none(w_end):
        end = size
        assert end >= 0
    else:
        end = adapt_lower_bound(space, size, w_end)
    return start, end

def normalize_simple_slice(space, length, w_start, w_stop):
    """Helper for the {get,set,del}slice implementations."""
    # this returns a pair (start, stop) which is usable for slicing
    # a sequence of the given length in the most friendly way, i.e.
    # guaranteeing that 0 <= start <= stop <= length.
    start = space.int_w(w_start)
    stop = space.int_w(w_stop)
    assert length >= 0
    if start < 0:
        start = 0
    # hack for the JIT, for slices with no end specified:
    # this avoids the two comparisons that follow
    if jit.isconstant(stop) and stop == sys.maxint:
        pass
    else:
        if stop < start:
            stop = start
        if stop <= length:
            return start, stop
    # here is the case where 'stop' is larger than the list
    stop = length
    if jit.isconstant(start) and start == 0:
        pass    # no need to do the following check here
    elif start > stop:
        start = stop
    return start, stop


app = gateway.applevel("""
    from _operator import index

    def evaluate_slice_index(x):
        try:
            return index(x)
        except TypeError:
            raise TypeError("slice indices must be integers or "
                            "None or have an __index__ method")

    def _getlongindices(start, stop, step, length):
        if step is None:
            step = 1
        else:
            step = evaluate_slice_index(step)
            if step == 0:
                raise ValueError("slice step cannot be zero")

        # Find lower and upper bounds for start and stop.
        if step < 0:
            lower = -1
            upper = length - 1
        else:
            lower = 0
            upper = length

        # Compute start.
        if start is None:
            start = upper if step < 0 else lower
        else:
            start = evaluate_slice_index(start)
            if start < 0:
                start += length
                if start < lower:
                    start = lower
            else:
                if start > upper:
                    start = upper

        # Compute stop.
        if stop is None:
            stop = lower if step < 0 else upper
        else:
            stop = evaluate_slice_index(stop)
            if stop < 0:
                stop += length
                if stop < lower:
                    stop = lower
            else:
                if stop > upper:
                    stop = upper

        return (start, stop, step)

    def indices(start, stop, step, length):
        length = index(length)
        if length < 0:
            raise ValueError("length should not be negative")
        return _getlongindices(start, stop, step, length)

""", filename=__file__)

app_indices = app.interphook("indices")
