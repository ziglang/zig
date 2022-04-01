import time

from pypy.interpreter.error import oefmt, OperationError
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.baseobjspace import W_Root
from pypy.module.posix import interp_posix
from rpython.rlib.rarithmetic import r_uint, intmask, widen
from rpython.rlib import rbigint, rrandom, rstring

def descr_new__(space, w_subtype, __args__):
    w_anything = __args__.firstarg()
    x = space.allocate_instance(W_Random, w_subtype)
    x = space.interp_w(W_Random, x)
    W_Random.__init__(x, space, w_anything)
    return x


class W_Random(W_Root):
    def __init__(self, space, w_anything):
        self._rnd = rrandom.Random()
        self.seed(space, w_anything)

    def random(self, space):
        return space.newfloat(self._rnd.random())

    def seed(self, space, w_n=None):
        if space.is_none(w_n):
            # TODO: Use a non-blocking version of urandom
            try:
                w_n = interp_posix.urandom(space, 8)
            except OperationError as e:
                if not e.match(space, space.w_OSError):
                    raise
                w_n = space.newint(int(time.time() * 256))
        if space.isinstance_w(w_n, space.w_int):
            w_n = space.abs(w_n)
        else:
            n = space.hash_w(w_n)
            w_n = space.newint(r_uint(n))
        key = []
        w_one = space.newint(1)
        w_two = space.newint(2)
        w_thirtytwo = space.newint(32)
        # 0xffffffff
        w_masklower = space.sub(space.pow(w_two, w_thirtytwo, space.w_None),
                                w_one)
        while space.is_true(w_n):
            w_chunk = space.and_(w_n, w_masklower)
            chunk = space.uint_w(w_chunk)
            key.append(chunk)
            w_n = space.rshift(w_n, w_thirtytwo)
        if not key:
            key = [r_uint(0)]
        self._rnd.init_by_array(key)

    def getstate(self, space):
        state = [None] * (rrandom.N + 1)
        for i in range(rrandom.N):
            state[i] = space.newint(widen(self._rnd.state[i]))
        state[rrandom.N] = space.newlong(self._rnd.index)
        return space.newtuple(state)

    def setstate(self, space, w_state):
        if not space.isinstance_w(w_state, space.w_tuple):
            raise oefmt(space.w_TypeError, "state vector must be tuple")
        if space.len_w(w_state) != rrandom.N + 1:
            raise oefmt(space.w_ValueError, "state vector is the wrong size")
        w_zero = space.newint(0)
        # independent of platfrom, since the below condition is only
        # true on 32 bit platforms anyway
        w_add = space.pow(space.newint(2), space.newint(32), space.w_None)
        _state = [r_uint(0)] * rrandom.N
        for i in range(rrandom.N):
            w_item = space.getitem(w_state, space.newint(i))
            if space.is_true(space.lt(w_item, w_zero)):
                w_item = space.add(w_item, w_add)
            _state[i] = space.uint_w(w_item)
        w_item = space.getitem(w_state, space.newint(rrandom.N))
        index = space.int_w(w_item)
        if index < 0 or index > rrandom.N:
            raise oefmt(space.w_ValueError, "invalid state")
        self._rnd.state = _state
        self._rnd.index = index

    @unwrap_spec(k=int)
    def getrandbits(self, space, k):
        if k < 0:
            raise oefmt(space.w_ValueError,
                        "number of bits must be non-negative")
        if k == 0:
            return space.newint(0)
        bytes = ((k - 1) // 32 + 1) * 4
        bytesarray = rstring.StringBuilder(bytes)
        for i in range(0, bytes, 4):
            r = self._rnd.genrand32()
            if k < 32:
                r >>= (32 - k)
            bytesarray.append(chr(r & r_uint(0xff)))
            bytesarray.append(chr((r >> 8) & r_uint(0xff)))
            bytesarray.append(chr((r >> 16) & r_uint(0xff)))
            bytesarray.append(chr((r >> 24) & r_uint(0xff)))
            k -= 32

        # little endian order to match bytearray assignment order
        result = rbigint.rbigint.frombytes(
            bytesarray.build(), 'little', signed=False)
        return space.newlong_from_rbigint(result)


W_Random.typedef = TypeDef("Random",
    __new__ = interp2app(descr_new__),
    random = interp2app(W_Random.random),
    seed = interp2app(W_Random.seed),
    getstate = interp2app(W_Random.getstate),
    setstate = interp2app(W_Random.setstate),
    getrandbits = interp2app(W_Random.getrandbits),
)
