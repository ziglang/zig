"""High performance data structures

Note that PyPy also contains a built-in module '_collections' which will hide
this one if compiled in.

THIS ONE IS BOGUS in the sense that it is NOT THREAD-SAFE!  It is provided
only as documentation nowadays.  Please don't run in production a PyPy
without the '_collections' built-in module.  The built-in module is
correctly thread-safe, like it is on CPython.
"""
#
# Copied and completed from the sandbox of CPython
#   (nondist/sandbox/collections/pydeque.py rev 1.1, Raymond Hettinger)
#

try:
    from _thread import _get_ident as _thread_ident
except ImportError:
    def _thread_ident():
        return -1


n = 30
LFTLNK = n
RGTLNK = n+1
BLOCKSIZ = n+2

# The deque's size limit is d.maxlen.  The limit can be zero or positive, or
# None.  After an item is added to a deque, we check to see if the size has
# grown past the limit. If it has, we get the size back down to the limit by
# popping an item off of the opposite end.  The methods that can trigger this
# are append(), appendleft(), extend(), and extendleft().

class deque(object):

    def __new__(cls, iterable=(), *args, **kw):
        self = super(deque, cls).__new__(cls)
        self.clear()
        return self

    def __init__(self, iterable=(), maxlen=None):
        self.clear()
        if maxlen is not None:
            if maxlen < 0:
                raise ValueError("maxlen must be non-negative")
        self._maxlen = maxlen
        add = self.append
        for elem in iterable:
            add(elem)

    @property
    def maxlen(self):
        return self._maxlen

    def clear(self):
        self.right = self.left = [None] * BLOCKSIZ
        self.rightndx = n//2   # points to last written element
        self.leftndx = n//2+1
        self.length = 0
        self.state = 0

    def append(self, x):
        self.state += 1
        self.rightndx += 1
        if self.rightndx == n:
            newblock = [None] * BLOCKSIZ
            self.right[RGTLNK] = newblock
            newblock[LFTLNK] = self.right
            self.right = newblock
            self.rightndx = 0
        self.length += 1
        self.right[self.rightndx] = x
        if self.maxlen is not None and self.length > self.maxlen:
            self.popleft()

    def appendleft(self, x):
        self.state += 1
        self.leftndx -= 1
        if self.leftndx == -1:
            newblock = [None] * BLOCKSIZ
            self.left[LFTLNK] = newblock
            newblock[RGTLNK] = self.left
            self.left = newblock
            self.leftndx = n-1
        self.length += 1
        self.left[self.leftndx] = x
        if self.maxlen is not None and self.length > self.maxlen:
            self.pop()

    def extend(self, iterable):
        if iterable is self:
            iterable = list(iterable)
        for elem in iterable:
            self.append(elem)

    def extendleft(self, iterable):
        if iterable is self:
            iterable = list(iterable)
        for elem in iterable:
            self.appendleft(elem)

    def pop(self):
        if self.left is self.right and self.leftndx > self.rightndx:
            raise IndexError("pop from an empty deque")
        x = self.right[self.rightndx]
        self.right[self.rightndx] = None
        self.length -= 1
        self.rightndx -= 1
        self.state += 1
        if self.rightndx == -1:
            prevblock = self.right[LFTLNK]
            if prevblock is None:
                # the deque has become empty; recenter instead of freeing block
                self.rightndx = n//2
                self.leftndx = n//2+1
            else:
                prevblock[RGTLNK] = None
                self.right[LFTLNK] = None
                self.right = prevblock
                self.rightndx = n-1
        return x

    def popleft(self):
        if self.left is self.right and self.leftndx > self.rightndx:
            raise IndexError("pop from an empty deque")
        x = self.left[self.leftndx]
        self.left[self.leftndx] = None
        self.length -= 1
        self.leftndx += 1
        self.state += 1
        if self.leftndx == n:
            prevblock = self.left[RGTLNK]
            if prevblock is None:
                # the deque has become empty; recenter instead of freeing block
                self.rightndx = n//2
                self.leftndx = n//2+1
            else:
                prevblock[LFTLNK] = None
                self.left[RGTLNK] = None
                self.left = prevblock
                self.leftndx = 0
        return x

    def count(self, value):
        c = 0
        for item in self:
            if item == value:
                c += 1
        return c

    def remove(self, value):
        # Need to defend mutating or failing comparisons
        i = 0
        try:
            for i in range(len(self)):
                if self[0] == value:
                    self.popleft()
                    return
                self.append(self.popleft())
            i += 1
            raise ValueError("deque.remove(x): x not in deque")
        finally:
            self.rotate(i)

    def rotate(self, n=1):
        length = len(self)
        if length <= 1:
            return
        halflen = length >> 1
        if n > halflen or n < -halflen:
            n %= length
            if n > halflen:
                n -= length
            elif n < -halflen:
                n += length
        while n > 0:
            self.appendleft(self.pop())
            n -= 1
        while n < 0:
            self.append(self.popleft())
            n += 1

    def reverse(self):
        "reverse *IN PLACE*"
        leftblock = self.left
        rightblock = self.right
        leftindex = self.leftndx
        rightindex = self.rightndx
        for i in range(self.length // 2):
            # Validate that pointers haven't met in the middle
            assert leftblock != rightblock or leftindex < rightindex

            # Swap
            (rightblock[rightindex], leftblock[leftindex]) = (
                leftblock[leftindex], rightblock[rightindex])

            # Advance left block/index pair
            leftindex += 1
            if leftindex == n:
                leftblock = leftblock[RGTLNK]
                assert leftblock is not None
                leftindex = 0

            # Step backwards with the right block/index pair
            rightindex -= 1
            if rightindex == -1:
                rightblock = rightblock[LFTLNK]
                assert rightblock is not None
                rightindex = n - 1

    def __repr__(self):
        threadlocalattr = '__repr' + str(_thread_ident())
        if threadlocalattr in self.__dict__:
            return '%s([...])' % (self.__class__.__name__,)
        else:
            self.__dict__[threadlocalattr] = True
            try:
                if self.maxlen is not None:
                    return '%s(%r, maxlen=%s)' % (self.__class__.__name__, list(self), self.maxlen)
                else:
                    return '%s(%r)' % (self.__class__.__name__, list(self))
            finally:
                del self.__dict__[threadlocalattr]

    def __iter__(self):
        return deque_iterator(self, self._iter_impl)

    def _iter_impl(self, original_state, giveup):
        if self.state != original_state:
            giveup()
        block = self.left
        while block:
            l, r = 0, n
            if block is self.left:
                l = self.leftndx
            if block is self.right:
                r = self.rightndx + 1
            for elem in block[l:r]:
                yield elem
                if self.state != original_state:
                    giveup()
            block = block[RGTLNK]

    def __reversed__(self):
        return deque_iterator(self, self._reversed_impl)

    def _reversed_impl(self, original_state, giveup):
        if self.state != original_state:
            giveup()
        block = self.right
        while block:
            l, r = 0, n
            if block is self.left:
                l = self.leftndx
            if block is self.right:
                r = self.rightndx + 1
            for elem in reversed(block[l:r]):
                yield elem
                if self.state != original_state:
                    giveup()
            block = block[LFTLNK]

    def __len__(self):
        #sum = 0
        #block = self.left
        #while block:
        #    sum += n
        #    block = block[RGTLNK]
        #return sum + self.rightndx - self.leftndx + 1 - n
        return self.length

    def __getref(self, index):
        if index >= 0:
            block = self.left
            while block:
                l, r = 0, n
                if block is self.left:
                    l = self.leftndx
                if block is self.right:
                    r = self.rightndx + 1
                span = r-l
                if index < span:
                    return block, l+index
                index -= span
                block = block[RGTLNK]
        else:
            block = self.right
            while block:
                l, r = 0, n
                if block is self.left:
                    l = self.leftndx
                if block is self.right:
                    r = self.rightndx + 1
                negative_span = l-r
                if index >= negative_span:
                    return block, r+index
                index -= negative_span
                block = block[LFTLNK]
        raise IndexError("deque index out of range")

    def __getitem__(self, index):
        block, index = self.__getref(index)
        return block[index]

    def __setitem__(self, index, value):
        block, index = self.__getref(index)
        block[index] = value

    def __delitem__(self, index):
        length = len(self)
        if index >= 0:
            if index >= length:
                raise IndexError("deque index out of range")
            self.rotate(-index)
            self.popleft()
            self.rotate(index)
        else:
            index = ~index
            if index >= length:
                raise IndexError("deque index out of range")
            self.rotate(index)
            self.pop()
            self.rotate(-index)

    def __reduce_ex__(self, proto):
        return type(self), ((), self.maxlen), None, iter(self)

    __hash__ = None

    def __copy__(self):
        return self.__class__(self, self.maxlen)

    # XXX make comparison more efficient
    def __eq__(self, other):
        if isinstance(other, deque):
            return list(self) == list(other)
        else:
            return NotImplemented

    def __ne__(self, other):
        if isinstance(other, deque):
            return list(self) != list(other)
        else:
            return NotImplemented

    def __lt__(self, other):
        if isinstance(other, deque):
            return list(self) < list(other)
        else:
            return NotImplemented

    def __le__(self, other):
        if isinstance(other, deque):
            return list(self) <= list(other)
        else:
            return NotImplemented

    def __gt__(self, other):
        if isinstance(other, deque):
            return list(self) > list(other)
        else:
            return NotImplemented

    def __ge__(self, other):
        if isinstance(other, deque):
            return list(self) >= list(other)
        else:
            return NotImplemented

    def __iadd__(self, other):
        self.extend(other)
        return self

class deque_iterator(object):

    def __init__(self, deq, itergen):
        self.counter = len(deq)
        def giveup():
            self.counter = 0
            raise RuntimeError("deque mutated during iteration")
        self._gen = itergen(deq.state, giveup)

    def __next__(self):
        res = next(self._gen)
        self.counter -= 1
        return res

    def __iter__(self):
        return self

class defaultdict(dict):
    __slots__ = ["default_factory"]

    def __init__(self, *args, **kwds):
        if len(args) > 0:
            default_factory = args[0]
            args = args[1:]
            if not callable(default_factory) and default_factory is not None:
                raise TypeError("first argument must be callable")
        else:
            default_factory = None
        self.default_factory = default_factory
        super(defaultdict, self).__init__(*args, **kwds)

    def __missing__(self, key):
        # from defaultdict docs
        if self.default_factory is None:
            raise KeyError(key)
        self[key] = value = self.default_factory()
        return value

    def __repr__(self, recurse=set()):
        if id(self) in recurse:
            return "%s(...)" % (self.__class__.__name__,)
        try:
            recurse.add(id(self))
            return "%s(%s, %s)" % (self.__class__.__name__, repr(self.default_factory), super(defaultdict, self).__repr__())
        finally:
            recurse.remove(id(self))

    def copy(self):
        return type(self)(self.default_factory, self)

    def __copy__(self):
        return self.copy()

    def __reduce__(self):
        """
        __reduce__ must return a 5-tuple as follows:

           - factory function
           - tuple of args for the factory function
           - additional state (here None)
           - sequence iterator (here None)
           - dictionary iterator (yielding successive (key, value) pairs

           This API is used by pickle.py and copy.py.
        """
        return (type(self), (self.default_factory,), None, None,
                iter(self.items()))
