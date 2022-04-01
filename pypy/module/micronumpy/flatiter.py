from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.module.micronumpy import loop
from pypy.module.micronumpy.base import convert_to_array
from pypy.module.micronumpy.concrete import BaseConcreteArray
from .ndarray import W_NDimArray


class FakeArrayImplementation(BaseConcreteArray):
    """ The sole purpose of this class is to W_FlatIterator can behave
    like a real array for descr_eq and friends
    """
    def __init__(self, base):
        self._base = base
        self.dtype = base.get_dtype()
        self.shape = [base.get_size()]
        self.storage = self._base.implementation.storage
        self.order = base.get_order()

    def base(self):
        return self._base

    def get_shape(self):
        return self.shape

    def get_size(self):
        return self.base().get_size()

    def create_iter(self, shape=None, backward_broadcast=False):
        assert isinstance(self.base(), W_NDimArray)
        return self.base().create_iter()


class W_FlatIterator(W_NDimArray):
    def __init__(self, arr):
        self.base = arr
        self.iter, self.state = arr.create_iter()
        # this is needed to support W_NDimArray interface
        self.implementation = FakeArrayImplementation(self.base)

    def descr_base(self, space):
        return self.base

    def descr_index(self, space):
        return space.newint(self.state.index)

    def descr_coords(self, space):
        coords = self.iter.indices(self.state)
        return space.newtuple([space.newint(c) for c in coords])

    def descr_iter(self):
        return self

    def descr_len(self, space):
        return space.newint(self.iter.size)

    def descr_next(self, space):
        if self.iter.done(self.state):
            raise OperationError(space.w_StopIteration, space.w_None)
        w_res = self.iter.getitem(self.state)
        self.iter.next(self.state, mutate=True)
        return w_res

    def descr_getitem(self, space, w_idx):
        if not (space.isinstance_w(w_idx, space.w_int) or
                space.isinstance_w(w_idx, space.w_slice)):
            raise oefmt(space.w_IndexError, 'unsupported iterator index')
        try:
            start, stop, step, length = space.decode_index4(w_idx, self.iter.size)
            state = self.iter.goto(start)
            if length == 1:
                return self.iter.getitem(state)
            base = self.base
            res = W_NDimArray.from_shape(space, [length], base.get_dtype(),
                                         base.get_order(), w_instance=base)
            return loop.flatiter_getitem(res, self.iter, state, step)
        finally:
            self.iter.reset(self.state, mutate=True)

    def descr_setitem(self, space, w_idx, w_value):
        if not (space.isinstance_w(w_idx, space.w_int) or
                space.isinstance_w(w_idx, space.w_slice)):
            raise oefmt(space.w_IndexError, 'unsupported iterator index')
        start, stop, step, length = space.decode_index4(w_idx, self.iter.size)
        try:
            state = self.iter.goto(start)
            dtype = self.base.get_dtype()
            if length == 1:
                try:
                    val = dtype.coerce(space, w_value)
                except OperationError:
                    raise oefmt(space.w_ValueError, "Error setting single item of array.")
                self.iter.setitem(state, val)
                return
            arr = convert_to_array(space, w_value)
            loop.flatiter_setitem(space, dtype, arr, self.iter, state, step, length)
        finally:
            self.iter.reset(self.state, mutate=True)

    def descr___array_wrap__(self, space, obj, w_context=None):
        return obj

W_FlatIterator.typedef = TypeDef("numpy.flatiter",
    base = GetSetProperty(W_FlatIterator.descr_base),
    index = GetSetProperty(W_FlatIterator.descr_index),
    coords = GetSetProperty(W_FlatIterator.descr_coords),

    __iter__ = interp2app(W_FlatIterator.descr_iter),
    __len__ = interp2app(W_FlatIterator.descr_len),
    next = interp2app(W_FlatIterator.descr_next),

    __getitem__ = interp2app(W_FlatIterator.descr_getitem),
    __setitem__ = interp2app(W_FlatIterator.descr_setitem),

    __eq__ = interp2app(W_FlatIterator.descr_eq),
    __ne__ = interp2app(W_FlatIterator.descr_ne),
    __lt__ = interp2app(W_FlatIterator.descr_lt),
    __le__ = interp2app(W_FlatIterator.descr_le),
    __gt__ = interp2app(W_FlatIterator.descr_gt),
    __ge__ = interp2app(W_FlatIterator.descr_ge),
    __array_wrap__ = interp2app(W_NDimArray.descr___array_wrap__),
)
