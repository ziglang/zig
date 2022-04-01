
class AbstractShrinkList(object):
    """A mixin base class.  You should subclass it and add a method
    must_keep().  Behaves like a list with the method append(), and
    you can read *for reading* the list of items by calling items().
    The twist is that occasionally append() will throw away the
    items for which must_keep() returns False.  (It does so without
    changing the order.)

    See also rpython.rlib.rweaklist.
    """
    _mixin_ = True

    def __init__(self):
        self._list = []
        self._next_shrink = 16

    def append(self, x):
        self._do_shrink()
        self._list.append(x)

    def items(self):
        return self._list

    def _do_shrink(self):
        if len(self._list) >= self._next_shrink:
            rest = 0
            for x in self._list:
                if self.must_keep(x):
                    self._list[rest] = x
                    rest += 1
            del self._list[rest:]
            self._next_shrink = 16 + 2 * rest

    def must_keep(self, x):
        raise NotImplementedError
