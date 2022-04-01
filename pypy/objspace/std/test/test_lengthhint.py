from pypy.module._collections.interp_deque import W_Deque
from pypy.module.itertools.interp_itertools import W_Repeat

class TestLengthHint:

    SIZE = 4
    ITEMS = range(SIZE)

    def _test_length_hint(self, w_obj, w_mutate=None):
        space = self.space
        assert space.length_hint(w_obj, 8) == self.SIZE

        w_iter = space.iter(w_obj)
        assert space.int_w(
            space.call_method(w_iter, '__length_hint__')) == self.SIZE
        assert space.length_hint(w_iter, 8) == self.SIZE

        space.next(w_iter)
        assert space.length_hint(w_iter, 8) == self.SIZE - 1

        if w_mutate is not None:
            # Test handling of collections that enforce length
            # immutability during iteration
            space.call_function(w_mutate)
            space.raises_w(space.w_RuntimeError, space.next, w_iter)
            assert space.length_hint(w_iter, 8) == 0

    def test_bytearray(self):
        space = self.space
        w_bytearray = space.call_function(space.w_bytearray,
                                          space.wrap(self.ITEMS))
        self._test_length_hint(w_bytearray)

    def test_dict(self):
        space = self.space
        w_dict = space.call_function(space.w_dict,
                                     space.wrap([(i, None) for i in self.ITEMS]))
        self._test_length_hint(w_dict)

    def test_dict_iterkeys(self):
        space = self.space
        w_iterkeys, w_mutate = space.fixedview(space.appexec([], """():
            d = dict.fromkeys(%r)
            return d.keys(), d.popitem
        """ % self.ITEMS), 2)
        self._test_length_hint(w_iterkeys, w_mutate)

    def test_dict_values(self):
        space = self.space
        w_itervalues, w_mutate = space.fixedview(space.appexec([], """():
            d = dict.fromkeys(%r)
            return d.values(), d.popitem
        """ % self.ITEMS), 2)
        self._test_length_hint(w_itervalues, w_mutate)

    def test_frozenset(self):
        space = self.space
        w_set = space.call_function(space.w_frozenset, space.wrap(self.ITEMS))
        self._test_length_hint(w_set)

    def test_set(self):
        space = self.space
        w_set = space.call_function(space.w_set, space.wrap(self.ITEMS))
        w_mutate = space.getattr(w_set, space.wrap('pop'))
        self._test_length_hint(w_set, w_mutate)

    def test_list(self):
        self._test_length_hint(self.space.wrap(self.ITEMS))

    def test_bytes(self):
        self._test_length_hint(self.space.newbytes('P' * self.SIZE))

    def test_bytearray(self):
        space = self.space
        w_bytearray = space.call_function(space.w_bytearray,
                                          space.newbytes('P' * self.SIZE))
        self._test_length_hint(w_bytearray)

    def test_str(self):
        self._test_length_hint(self.space.wrap('P' * self.SIZE))

    def test_unicode(self):
        self._test_length_hint(self.space.newutf8('Y' * self.SIZE, self.SIZE))

    def test_tuple(self):
        self._test_length_hint(self.space.wrap(tuple(self.ITEMS)))

    def test_reversed(self):
        # test the generic reversed iterator (w_foo lacks __reversed__)
        space = self.space
        w_foo = space.appexec([], """():
            class Foo(object):
                def __len__(self):
                    return %r
                def __getitem__(self, index):
                    if 0 <= index < %r:
                        return index
                    raise IndexError()
            return Foo()
        """ % (self.SIZE, self.SIZE))
        w_reversed = space.call_method(space.builtin, 'reversed', w_foo)
        assert space.int_w(
            space.call_method(w_reversed, '__length_hint__')) == self.SIZE
        self._test_length_hint(w_reversed)

    def test_reversedsequenceiterator(self):
        space = self.space
        w_reversed = space.call_method(space.builtin, 'reversed',
                                       space.wrap(self.ITEMS))
        assert space.int_w(
            space.call_method(w_reversed, '__length_hint__')) == self.SIZE
        self._test_length_hint(w_reversed)

    def test_range(self):
        space = self.space
        w_range = space.call_method(space.builtin, 'range',
                                     space.newint(self.SIZE))
        self._test_length_hint(w_range)

    def test_itertools_repeat(self):
        space = self.space
        self._test_length_hint(W_Repeat(space, space.wrap(22),
                                        space.wrap(self.SIZE)))

    def _setup_deque(self):
        space = self.space
        w_deque = W_Deque(space)
        space.call_method(w_deque, '__init__', space.wrap(self.ITEMS))
        w_mutate = space.getattr(w_deque, space.wrap('pop'))
        return w_deque, w_mutate

    def test_collections_deque(self):
        self._test_length_hint(*self._setup_deque())

    def test_collections_deque_rev(self):
        w_deque, w_mutate = self._setup_deque()
        self._test_length_hint(w_deque.reviter(), w_mutate)

    def test_default(self):
        space = self.space
        assert space.length_hint(space.w_False, 3) == 3

    def test_NotImplemented(self):
        space = self.space
        w_foo = space.appexec([], """():
            class Foo(object):
                def __length_hint__(self):
                    return NotImplemented
            return Foo()
        """)
        assert space.length_hint(w_foo, 3) == 3

    def test_invalid_hint(self):
        space = self.space
        w_foo = space.appexec([], """():
            class Foo(object):
                def __length_hint__(self):
                    return -1
            return Foo()
        """)
        space.raises_w(space.w_ValueError, space.length_hint, w_foo, 3)

    def test_exc(self):
        space = self.space
        w_foo = space.appexec([], """():
            class Foo(object):
                def __length_hint__(self):
                    1 / 0
            return Foo()
        """)
        space.raises_w(space.w_ZeroDivisionError, space.length_hint, w_foo, 3)
