from rpython.tool.uid import uid

# Support for explicit specialization: in code using global constants
# that are instances of SpecTag, code paths are not merged when
# the same variable holds a different SpecTag instance.

class SpecTag(object):
    __slots__ = ()

    def __repr__(self):
        return '%s(0x%x)' % (self.__class__.__name__, uid(self))

    def _freeze_(self):
        return True


# 'for' iteration over iterables wrapped in an instance
# of unrolling_iterable will be unrolled by the flow space,
# like in:
#     names = unrolling_iterable(['a', 'b', 'c'])
#     def f(x):
#         for name in names:
#             setattr(x, name, 0)

class unrolling_iterable(SpecTag):

    def __init__(self, iterable):
        self._items = list(iterable)
        self._head = _unroller(self._items)

    def __iter__(self):
        return iter(self._items)

    def get_unroller(self):
        return self._head


class _unroller(SpecTag):

    def __init__(self, items, i=0):
        self._items = items
        self._i = i
        self._next = None

    def step(self):
        v = self._items[self._i]
        if self._next is None:
            self._next = _unroller(self._items, self._i+1)
        return v, self._next
