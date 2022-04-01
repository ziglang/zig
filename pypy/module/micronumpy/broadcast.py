import pypy.module.micronumpy.constants as NPY
from nditer import ConcreteIter, parse_op_flag, parse_op_arg
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.module.micronumpy import support
from pypy.module.micronumpy.base import W_NDimArray, convert_to_array, W_NumpyObject
from rpython.rlib import jit
from strides import calculate_broadcast_strides, shape_agreement_multiple

def descr_new_broadcast(space, w_subtype, __args__):
    return W_Broadcast(space, __args__.arguments_w)

class W_Broadcast(W_NumpyObject):
    """
    Implementation of numpy.broadcast.
    This class is a simplified version of nditer.W_NDIter with fixed iteration for broadcasted arrays.
    """

    def __init__(self, space, args):
        num_args = len(args)
        if not (2 <= num_args <= NPY.MAXARGS):
            raise oefmt(space.w_ValueError,
                                 "Need at least two and fewer than (%d) array objects.", NPY.MAXARGS)

        self.seq = [convert_to_array(space, w_elem)
                    for w_elem in args]

        self.op_flags = parse_op_arg(space, 'op_flags', space.w_None,
                                     len(self.seq), parse_op_flag)

        self.shape = shape_agreement_multiple(space, self.seq, shape=None)
        self.order = NPY.CORDER

        self.iters = []
        self.index = 0

        try:
            self.size = support.product_check(self.shape)
        except OverflowError as e:
            raise oefmt(space.w_ValueError, "broadcast dimensions too large.")
        for i in range(len(self.seq)):
            it = self.get_iter(space, i)
            it.contiguous = False
            self.iters.append((it, it.reset()))

        self.done = False
        pass

    def get_iter(self, space, i):
        arr = self.seq[i]
        imp = arr.implementation
        if arr.is_scalar():
            return ConcreteIter(imp, 1, [], [], [], self.op_flags[i], self)
        shape = self.shape

        backward = imp.order != self.order

        r = calculate_broadcast_strides(imp.strides, imp.backstrides, imp.shape,
                                        shape, backward)

        iter_shape = shape
        if len(shape) != len(r[0]):
            # shape can be shorter when using an external loop, just return a view
            iter_shape = imp.shape
        return ConcreteIter(imp, imp.get_size(), iter_shape, r[0], r[1],
                            self.op_flags[i], self)

    def descr_iter(self, space):
        return self

    def descr_get_shape(self, space):
        return space.newtuple([space.newint(i) for i in self.shape])

    def descr_get_size(self, space):
        return space.newint(self.size)

    def descr_get_index(self, space):
        return space.newint(self.index)

    def descr_get_numiter(self, space):
        return space.newint(len(self.iters))

    @jit.unroll_safe
    def descr_next(self, space):
        if self.index >= self.size:
            self.done = True
            raise OperationError(space.w_StopIteration, space.w_None)
        self.index += 1
        res = []
        for i, (it, st) in enumerate(self.iters):
            res.append(self._get_item(it, st))
            self.iters[i] = (it, it.next(st))
        if len(res) < 2:
            return res[0]
        return space.newtuple(res)

    def _get_item(self, it, st):
        return W_NDimArray(it.getoperand(st))


W_Broadcast.typedef = TypeDef("numpy.broadcast",
                              __new__=interp2app(descr_new_broadcast),
                              __iter__=interp2app(W_Broadcast.descr_iter),
                              next=interp2app(W_Broadcast.descr_next),
                              shape=GetSetProperty(W_Broadcast.descr_get_shape),
                              size=GetSetProperty(W_Broadcast.descr_get_size),
                              index=GetSetProperty(W_Broadcast.descr_get_index),
                              numiter=GetSetProperty(W_Broadcast.descr_get_numiter),
                              )
