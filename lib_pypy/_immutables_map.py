import collections.abc
import itertools
import reprlib
import sys


__all__ = ('Map',)


# Thread-safe counter.
_mut_id = itertools.count(1).__next__


# Python version of _map.c.  The topmost comment there explains
# all datastructures and algorithms.
# The code here follows C code closely on purpose to make
# debugging and testing easier.


def map_hash(o):
    x = hash(o)
    return (x & 0xffffffff) ^ ((x >> 32) & 0xffffffff)


def map_mask(hash, shift):
    return (hash >> shift) & 0x01f


def map_bitpos(hash, shift):
    return 1 << map_mask(hash, shift)


def map_bitcount(v):
    v = v - ((v >> 1) & 0x55555555)
    v = (v & 0x33333333) + ((v >> 2) & 0x33333333)
    v = (v & 0x0F0F0F0F) + ((v >> 4) & 0x0F0F0F0F)
    v = v + (v >> 8)
    v = (v + (v >> 16)) & 0x3F
    return v


def map_bitindex(bitmap, bit):
    return map_bitcount(bitmap & (bit - 1))


W_EMPTY, W_NEWNODE, W_NOT_FOUND = range(3)
void = object()


class BitmapNode:

    def __init__(self, size, bitmap, array, mutid):
        self.size = size
        self.bitmap = bitmap
        assert isinstance(array, list) and len(array) == size
        self.array = array
        self.mutid = mutid

    def clone(self, mutid):
        return BitmapNode(self.size, self.bitmap, self.array.copy(), mutid)

    def assoc(self, shift, hash, key, val, mutid):
        bit = map_bitpos(hash, shift)
        idx = map_bitindex(self.bitmap, bit)

        if self.bitmap & bit:
            key_idx = 2 * idx
            val_idx = key_idx + 1

            key_or_null = self.array[key_idx]
            val_or_node = self.array[val_idx]

            if key_or_null is None:
                sub_node, added = val_or_node.assoc(
                    shift + 5, hash, key, val, mutid)
                if val_or_node is sub_node:
                    return self, added

                if mutid and mutid == self.mutid:
                    self.array[val_idx] = sub_node
                    return self, added
                else:
                    ret = self.clone(mutid)
                    ret.array[val_idx] = sub_node
                    return ret, added

            if key == key_or_null:
                if val is val_or_node:
                    return self, False

                if mutid and mutid == self.mutid:
                    self.array[val_idx] = val
                    return self, False
                else:
                    ret = self.clone(mutid)
                    ret.array[val_idx] = val
                    return ret, False

            existing_key_hash = map_hash(key_or_null)
            if existing_key_hash == hash:
                sub_node = CollisionNode(
                    4, hash, [key_or_null, val_or_node, key, val], mutid)
            else:
                sub_node = BitmapNode(0, 0, [], mutid)
                sub_node, _ = sub_node.assoc(
                    shift + 5, existing_key_hash,
                    key_or_null, val_or_node,
                    mutid)
                sub_node, _ = sub_node.assoc(
                    shift + 5, hash, key, val,
                    mutid)

            if mutid and mutid == self.mutid:
                self.array[key_idx] = None
                self.array[val_idx] = sub_node
                return self, True
            else:
                ret = self.clone(mutid)
                ret.array[key_idx] = None
                ret.array[val_idx] = sub_node
                return ret, True

        else:
            key_idx = 2 * idx
            val_idx = key_idx + 1

            n = map_bitcount(self.bitmap)

            new_array = self.array[:key_idx]
            new_array.append(key)
            new_array.append(val)
            new_array.extend(self.array[key_idx:])

            if mutid and mutid == self.mutid:
                self.size = 2 * (n + 1)
                self.bitmap |= bit
                self.array = new_array
                return self, True
            else:
                return BitmapNode(
                    2 * (n + 1), self.bitmap | bit, new_array, mutid), True

    def find(self, shift, hash, key):
        bit = map_bitpos(hash, shift)

        if not (self.bitmap & bit):
            raise KeyError

        idx = map_bitindex(self.bitmap, bit)
        key_idx = idx * 2
        val_idx = key_idx + 1

        key_or_null = self.array[key_idx]
        val_or_node = self.array[val_idx]

        if key_or_null is None:
            return val_or_node.find(shift + 5, hash, key)

        if key == key_or_null:
            return val_or_node

        raise KeyError(key)

    def without(self, shift, hash, key, mutid):
        bit = map_bitpos(hash, shift)
        if not (self.bitmap & bit):
            return W_NOT_FOUND, None

        idx = map_bitindex(self.bitmap, bit)
        key_idx = 2 * idx
        val_idx = key_idx + 1

        key_or_null = self.array[key_idx]
        val_or_node = self.array[val_idx]

        if key_or_null is None:
            res, sub_node = val_or_node.without(shift + 5, hash, key, mutid)

            if res is W_EMPTY:
                raise RuntimeError('unreachable code')  # pragma: no cover

            elif res is W_NEWNODE:
                if (type(sub_node) is BitmapNode and
                        sub_node.size == 2 and
                        sub_node.array[0] is not None):

                    if mutid and mutid == self.mutid:
                        self.array[key_idx] = sub_node.array[0]
                        self.array[val_idx] = sub_node.array[1]
                        return W_NEWNODE, self
                    else:
                        clone = self.clone(mutid)
                        clone.array[key_idx] = sub_node.array[0]
                        clone.array[val_idx] = sub_node.array[1]
                        return W_NEWNODE, clone

                if mutid and mutid == self.mutid:
                    self.array[val_idx] = sub_node
                    return W_NEWNODE, self
                else:
                    clone = self.clone(mutid)
                    clone.array[val_idx] = sub_node
                    return W_NEWNODE, clone

            else:
                assert sub_node is None
                return res, None

        else:
            if key == key_or_null:
                if self.size == 2:
                    return W_EMPTY, None

                new_array = self.array[:key_idx]
                new_array.extend(self.array[val_idx + 1:])

                if mutid and mutid == self.mutid:
                    self.size -= 2
                    self.bitmap &= ~bit
                    self.array = new_array
                    return W_NEWNODE, self
                else:
                    new_node = BitmapNode(
                        self.size - 2, self.bitmap & ~bit, new_array, mutid)
                    return W_NEWNODE, new_node

            else:
                return W_NOT_FOUND, None

    def keys(self):
        for i in range(0, self.size, 2):
            key_or_null = self.array[i]

            if key_or_null is None:
                val_or_node = self.array[i + 1]
                yield from val_or_node.keys()
            else:
                yield key_or_null

    def values(self):
        for i in range(0, self.size, 2):
            key_or_null = self.array[i]
            val_or_node = self.array[i + 1]

            if key_or_null is None:
                yield from val_or_node.values()
            else:
                yield val_or_node

    def items(self):
        for i in range(0, self.size, 2):
            key_or_null = self.array[i]
            val_or_node = self.array[i + 1]

            if key_or_null is None:
                yield from val_or_node.items()
            else:
                yield key_or_null, val_or_node

    def dump(self, buf, level):  # pragma: no cover
        buf.append(
            '    ' * (level + 1) +
            'BitmapNode(size={} count={} bitmap={} id={:0x}):'.format(
                self.size, self.size / 2, bin(self.bitmap), id(self)))

        for i in range(0, self.size, 2):
            key_or_null = self.array[i]
            val_or_node = self.array[i + 1]

            pad = '    ' * (level + 2)

            if key_or_null is None:
                buf.append(pad + 'None:')
                val_or_node.dump(buf, level + 2)
            else:
                buf.append(pad + '{!r}: {!r}'.format(key_or_null, val_or_node))


class CollisionNode:

    def __init__(self, size, hash, array, mutid):
        self.size = size
        self.hash = hash
        self.array = array
        self.mutid = mutid

    def find_index(self, key):
        for i in range(0, self.size, 2):
            if self.array[i] == key:
                return i
        return -1

    def find(self, shift, hash, key):
        for i in range(0, self.size, 2):
            if self.array[i] == key:
                return self.array[i + 1]
        raise KeyError(key)

    def assoc(self, shift, hash, key, val, mutid):
        if hash == self.hash:
            key_idx = self.find_index(key)

            if key_idx == -1:
                new_array = self.array.copy()
                new_array.append(key)
                new_array.append(val)

                if mutid and mutid == self.mutid:
                    self.size += 2
                    self.array = new_array
                    return self, True
                else:
                    new_node = CollisionNode(
                        self.size + 2, hash, new_array, mutid)
                    return new_node, True

            val_idx = key_idx + 1
            if self.array[val_idx] is val:
                return self, False

            if mutid and mutid == self.mutid:
                self.array[val_idx] = val
                return self, False
            else:
                new_array = self.array.copy()
                new_array[val_idx] = val
                return CollisionNode(self.size, hash, new_array, mutid), False

        else:
            new_node = BitmapNode(
                2, map_bitpos(self.hash, shift), [None, self], mutid)
            return new_node.assoc(shift, hash, key, val, mutid)

    def without(self, shift, hash, key, mutid):
        if hash != self.hash:
            return W_NOT_FOUND, None

        key_idx = self.find_index(key)
        if key_idx == -1:
            return W_NOT_FOUND, None

        new_size = self.size - 2
        if new_size == 0:
            # Shouldn't be ever reachable
            return W_EMPTY, None  # pragma: no cover

        if new_size == 2:
            if key_idx == 0:
                new_array = [self.array[2], self.array[3]]
            else:
                assert key_idx == 2
                new_array = [self.array[0], self.array[1]]

            new_node = BitmapNode(
                2, map_bitpos(hash, shift), new_array, mutid)
            return W_NEWNODE, new_node

        new_array = self.array[:key_idx]
        new_array.extend(self.array[key_idx + 2:])
        if mutid and mutid == self.mutid:
            self.array = new_array
            self.size -= 2
            return W_NEWNODE, self
        else:
            new_node = CollisionNode(
                self.size - 2, self.hash, new_array, mutid)
            return W_NEWNODE, new_node

    def keys(self):
        for i in range(0, self.size, 2):
            yield self.array[i]

    def values(self):
        for i in range(1, self.size, 2):
            yield self.array[i]

    def items(self):
        for i in range(0, self.size, 2):
            yield self.array[i], self.array[i + 1]

    def dump(self, buf, level):  # pragma: no cover
        pad = '    ' * (level + 1)
        buf.append(
            pad + 'CollisionNode(size={} id={:0x}):'.format(
                self.size, id(self)))

        pad = '    ' * (level + 2)
        for i in range(0, self.size, 2):
            key = self.array[i]
            val = self.array[i + 1]

            buf.append('{}{!r}: {!r}'.format(pad, key, val))


class MapKeys:

    def __init__(self, c, m):
        self.__count = c
        self.__root = m

    def __len__(self):
        return self.__count

    def __iter__(self):
        return iter(self.__root.keys())


class MapValues:

    def __init__(self, c, m):
        self.__count = c
        self.__root = m

    def __len__(self):
        return self.__count

    def __iter__(self):
        return iter(self.__root.values())


class MapItems:

    def __init__(self, c, m):
        self.__count = c
        self.__root = m

    def __len__(self):
        return self.__count

    def __iter__(self):
        return iter(self.__root.items())


class Map:

    def __init__(self, col=None, **kw):
        self.__count = 0
        self.__root = BitmapNode(0, 0, [], 0)
        self.__hash = -1

        if isinstance(col, Map):
            self.__count = col.__count
            self.__root = col.__root
            self.__hash = col.__hash
            col = None
        elif isinstance(col, MapMutation):
            raise TypeError('cannot create Maps from MapMutations')

        if col or kw:
            init = self.update(col, **kw)
            self.__count = init.__count
            self.__root = init.__root

    @classmethod
    def _new(cls, count, root):
        m = Map.__new__(Map)
        m.__count = count
        m.__root = root
        m.__hash = -1
        return m

    def __reduce__(self):
        return (type(self), (dict(self.items()),))

    def __len__(self):
        return self.__count

    def __eq__(self, other):
        if not isinstance(other, Map):
            return NotImplemented

        if len(self) != len(other):
            return False

        for key, val in self.__root.items():
            try:
                oval = other.__root.find(0, map_hash(key), key)
            except KeyError:
                return False
            else:
                if oval != val:
                    return False

        return True

    def update(self, col=None, **kw):
        it = None
        if col is not None:
            if hasattr(col, 'items'):
                it = iter(col.items())
            else:
                it = iter(col)

        if it is not None:
            if kw:
                it = iter(itertools.chain(it, kw.items()))
        else:
            if kw:
                it = iter(kw.items())

        if it is None:

            return self

        mutid = _mut_id()
        root = self.__root
        count = self.__count

        i = 0
        while True:
            try:
                tup = next(it)
            except StopIteration:
                break

            try:
                tup = tuple(tup)
            except TypeError:
                raise TypeError(
                    'cannot convert map update '
                    'sequence element #{} to a sequence'.format(i)) from None
            key, val, *r = tup
            if r:
                raise ValueError(
                    'map update sequence element #{} has length '
                    '{}; 2 is required'.format(i, len(r) + 2))

            root, added = root.assoc(0, map_hash(key), key, val, mutid)
            if added:
                count += 1

            i += 1

        return Map._new(count, root)

    def mutate(self):
        return MapMutation(self.__count, self.__root)

    def set(self, key, val):
        new_count = self.__count
        new_root, added = self.__root.assoc(0, map_hash(key), key, val, 0)

        if new_root is self.__root:
            assert not added
            return self

        if added:
            new_count += 1

        return Map._new(new_count, new_root)

    def delete(self, key):
        res, node = self.__root.without(0, map_hash(key), key, 0)
        if res is W_EMPTY:
            return Map()
        elif res is W_NOT_FOUND:
            raise KeyError(key)
        else:
            return Map._new(self.__count - 1, node)

    def get(self, key, default=None):
        try:
            return self.__root.find(0, map_hash(key), key)
        except KeyError:
            return default

    def __getitem__(self, key):
        return self.__root.find(0, map_hash(key), key)

    def __contains__(self, key):
        try:
            self.__root.find(0, map_hash(key), key)
        except KeyError:
            return False
        else:
            return True

    def __iter__(self):
        yield from self.__root.keys()

    def keys(self):
        return MapKeys(self.__count, self.__root)

    def values(self):
        return MapValues(self.__count, self.__root)

    def items(self):
        return MapItems(self.__count, self.__root)

    def __hash__(self):
        if self.__hash != -1:
            return self.__hash

        MAX = sys.maxsize
        MASK = 2 * MAX + 1

        h = 1927868237 * (self.__count * 2 + 1)
        h &= MASK

        for key, value in self.__root.items():
            hx = hash(key)
            h ^= (hx ^ (hx << 16) ^ 89869747) * 3644798167
            h &= MASK

            hx = hash(value)
            h ^= (hx ^ (hx << 16) ^ 89869747) * 3644798167
            h &= MASK

        h = h * 69069 + 907133923
        h &= MASK

        if h > MAX:
            h -= MASK + 1  # pragma: no cover
        if h == -1:
            h = 590923713  # pragma: no cover

        self.__hash = h
        return h

    @reprlib.recursive_repr("{...}")
    def __repr__(self):
        items = []
        for key, val in self.items():
            items.append("{!r}: {!r}".format(key, val))
        return '<immutables.Map({{{}}}) at 0x{:0x}>'.format(
            ', '.join(items), id(self))

    def __dump__(self):  # pragma: no cover
        buf = []
        self.__root.dump(buf, 0)
        return '\n'.join(buf)

    def __class_getitem__(cls, item):
        return cls


class MapMutation:

    def __init__(self, count, root):
        self.__count = count
        self.__root = root
        self.__mutid = _mut_id()

    def set(self, key, val):
        self[key] = val

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.finish()
        return False

    def __iter__(self):
        raise TypeError('{} is not iterable'.format(type(self)))

    def __delitem__(self, key):
        if self.__mutid == 0:
            raise ValueError('mutation {!r} has been finished'.format(self))

        res, new_root = self.__root.without(
            0, map_hash(key), key, self.__mutid)
        if res is W_EMPTY:
            self.__count = 0
            self.__root = BitmapNode(0, 0, [], self.__mutid)
        elif res is W_NOT_FOUND:
            raise KeyError(key)
        else:
            self.__root = new_root
            self.__count -= 1

    def __setitem__(self, key, val):
        if self.__mutid == 0:
            raise ValueError('mutation {!r} has been finished'.format(self))

        self.__root, added = self.__root.assoc(
            0, map_hash(key), key, val, self.__mutid)

        if added:
            self.__count += 1

    def pop(self, key, *args):
        if self.__mutid == 0:
            raise ValueError('mutation {!r} has been finished'.format(self))

        if len(args) > 1:
            raise TypeError(
                'pop() accepts 1 to 2 positional arguments, '
                'got {}'.format(len(args) + 1))
        elif len(args) == 1:
            default = args[0]
        else:
            default = void

        val = self.get(key, default)

        try:
            del self[key]
        except KeyError:
            if val is void:
                raise
            return val
        else:
            assert val is not void
            return val

    def get(self, key, default=None):
        try:
            return self.__root.find(0, map_hash(key), key)
        except KeyError:
            return default

    def __getitem__(self, key):
        return self.__root.find(0, map_hash(key), key)

    def __contains__(self, key):
        try:
            self.__root.find(0, map_hash(key), key)
        except KeyError:
            return False
        else:
            return True

    def update(self, col=None, **kw):
        if self.__mutid == 0:
            raise ValueError('mutation {!r} has been finished'.format(self))

        it = None
        if col is not None:
            if hasattr(col, 'items'):
                it = iter(col.items())
            else:
                it = iter(col)

        if it is not None:
            if kw:
                it = iter(itertools.chain(it, kw.items()))
        else:
            if kw:
                it = iter(kw.items())

        if it is None:

            return self

        root = self.__root
        count = self.__count

        i = 0
        while True:
            try:
                tup = next(it)
            except StopIteration:
                break

            try:
                tup = tuple(tup)
            except TypeError:
                raise TypeError(
                    'cannot convert map update '
                    'sequence element #{} to a sequence'.format(i)) from None
            key, val, *r = tup
            if r:
                raise ValueError(
                    'map update sequence element #{} has length '
                    '{}; 2 is required'.format(i, len(r) + 2))

            root, added = root.assoc(0, map_hash(key), key, val, self.__mutid)
            if added:
                count += 1

            i += 1

        self.__root = root
        self.__count = count

    def finish(self):
        self.__mutid = 0
        return Map._new(self.__count, self.__root)

    @reprlib.recursive_repr("{...}")
    def __repr__(self):
        items = []
        for key, val in self.__root.items():
            items.append("{!r}: {!r}".format(key, val))
        return '<immutables.MapMutation({{{}}}) at 0x{:0x}>'.format(
            ', '.join(items), id(self))

    def __len__(self):
        return self.__count

    def __reduce__(self):
        raise TypeError("can't pickle {} objects".format(type(self).__name__))

    def __hash__(self):
        raise TypeError('unhashable type: {}'.format(type(self).__name__))

    def __eq__(self, other):
        if not isinstance(other, MapMutation):
            return NotImplemented

        if len(self) != len(other):
            return False

        for key, val in self.__root.items():
            try:
                oval = other.__root.find(0, map_hash(key), key)
            except KeyError:
                return False
            else:
                if oval != val:
                    return False

        return True


collections.abc.Mapping.register(Map)
