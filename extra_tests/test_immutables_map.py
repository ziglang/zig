import collections.abc
import gc
import pickle
import random
import sys
import weakref
import pytest

from _immutables_map import Map


class HashKey:
    _crasher = None

    def __init__(self, hash, name, *, error_on_eq_to=None):
        assert hash != -1
        self.name = name
        self.hash = hash
        self.error_on_eq_to = error_on_eq_to

    def __repr__(self):
        if self._crasher is not None and self._crasher.error_on_repr:
            raise ReprError
        return '<Key name:{} hash:{}>'.format(self.name, self.hash)

    def __hash__(self):
        if self._crasher is not None and self._crasher.error_on_hash:
            raise HashingError

        return self.hash

    def __eq__(self, other):
        if not isinstance(other, HashKey):
            return NotImplemented

        if self._crasher is not None and self._crasher.error_on_eq:
            raise EqError

        if self.error_on_eq_to is not None and self.error_on_eq_to is other:
            raise ValueError('cannot compare {!r} to {!r}'.format(self, other))
        if other.error_on_eq_to is not None and other.error_on_eq_to is self:
            raise ValueError('cannot compare {!r} to {!r}'.format(other, self))

        return (self.name, self.hash) == (other.name, other.hash)


class KeyStr(str):

    def __hash__(self):
        if HashKey._crasher is not None and HashKey._crasher.error_on_hash:
            raise HashingError
        return super().__hash__()

    def __eq__(self, other):
        if HashKey._crasher is not None and HashKey._crasher.error_on_eq:
            raise EqError
        return super().__eq__(other)

    def __repr__(self, other):
        if HashKey._crasher is not None and HashKey._crasher.error_on_repr:
            raise ReprError
        return super().__eq__(other)


class HashKeyCrasher:

    def __init__(self, *, error_on_hash=False, error_on_eq=False,
                 error_on_repr=False):
        self.error_on_hash = error_on_hash
        self.error_on_eq = error_on_eq
        self.error_on_repr = error_on_repr

    def __enter__(self):
        if HashKey._crasher is not None:
            raise RuntimeError('cannot nest crashers')
        HashKey._crasher = self

    def __exit__(self, *exc):
        HashKey._crasher = None


class HashingError(Exception):
    pass


class EqError(Exception):
    pass


class ReprError(Exception):
    pass


class BaseMapTest:

    def test_hashkey_helper_1(self):
        k1 = HashKey(10, 'aaa')
        k2 = HashKey(10, 'bbb')

        assert k1 != k2
        assert hash(k1) == hash(k2)

        d = dict()
        d[k1] = 'a'
        d[k2] = 'b'

        assert d[k1] == 'a'
        assert d[k2] == 'b'

    def test_map_basics_1(self):
        h = self.Map()
        h = None  # NoQA

    def test_map_basics_2(self):
        h = self.Map()
        assert len(h) == 0

        h2 = h.set('a', 'b')
        assert h is not h2
        assert len(h) == 0
        assert len(h2) == 1

        assert h.get('a') is None
        assert h.get('a', 42) == 42

        assert h2.get('a') == 'b'

        h3 = h2.set('b', 10)
        assert h2 is not h3
        assert len(h) == 0
        assert len(h2) == 1
        assert len(h3) == 2
        assert h3.get('a') == 'b'
        assert h3.get('b') == 10

        assert h.get('b') is None
        assert h2.get('b') is None

        assert h.get('a') is None
        assert h2.get('a') == 'b'

        h = h2 = h3 = None

    def test_map_basics_3(self):
        h = self.Map()
        o = object()
        h1 = h.set('1', o)
        h2 = h1.set('1', o)
        assert h1 is h2

    def test_map_basics_4(self):
        h = self.Map()
        h1 = h.set('key', [])
        h2 = h1.set('key', [])
        assert h1 is not h2
        assert len(h1) == 1
        assert len(h2) == 1
        assert h1.get('key') is not h2.get('key')

    def test_map_collision_1(self):
        k1 = HashKey(10, 'aaa')
        k2 = HashKey(10, 'bbb')
        k3 = HashKey(10, 'ccc')

        h = self.Map()
        h2 = h.set(k1, 'a')
        h3 = h2.set(k2, 'b')

        assert h.get(k1) == None
        assert h.get(k2) == None

        assert h2.get(k1) == 'a'
        assert h2.get(k2) == None

        assert h3.get(k1) == 'a'
        assert h3.get(k2) == 'b'

        h4 = h3.set(k2, 'cc')
        h5 = h4.set(k3, 'aa')

        assert h3.get(k1) == 'a'
        assert h3.get(k2) == 'b'
        assert h4.get(k1) == 'a'
        assert h4.get(k2) == 'cc'
        assert h4.get(k3) == None
        assert h5.get(k1) == 'a'
        assert h5.get(k2) == 'cc'
        assert h5.get(k2) == 'cc'
        assert h5.get(k3) == 'aa'

        assert len(h) == 0
        assert len(h2) == 1
        assert len(h3) == 2
        assert len(h4) == 2
        assert len(h5) == 3

    def test_map_collision_2(self):
        A = HashKey(100, 'A')
        B = HashKey(101, 'B')
        C = HashKey(0b011000011100000100, 'C')
        D = HashKey(0b011000011100000100, 'D')
        E = HashKey(0b1011000011100000100, 'E')

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(B, 'b')
        h = h.set(C, 'c')
        h = h.set(D, 'd')

        # BitmapNode(size=6 bitmap=0b100110000):
        #     NULL:
        #         BitmapNode(size=4 bitmap=0b1000000000000000000001000):
        #             <Key name:A hash:100>: 'a'
        #             NULL:
        #                 CollisionNode(size=4 id=0x108572410):
        #                     <Key name:C hash:100100>: 'c'
        #                     <Key name:D hash:100100>: 'd'
        #     <Key name:B hash:101>: 'b'

        h = h.set(E, 'e')

        # BitmapNode(size=4 count=2.0 bitmap=0b110000 id=10b8ea5c0):
        #     None:
        #         BitmapNode(size=4 count=2.0
        #                    bitmap=0b1000000000000000000001000 id=10b8ea518):
        #             <Key name:A hash:100>: 'a'
        #             None:
        #                 BitmapNode(size=2 count=1.0 bitmap=0b10
        #                            id=10b8ea4a8):
        #                     None:
        #                         BitmapNode(size=4 count=2.0
        #                                    bitmap=0b100000001000
        #                                    id=10b8ea4e0):
        #                             None:
        #                                 CollisionNode(size=4 id=10b8ea470):
        #                                     <Key name:C hash:100100>: 'c'
        #                                     <Key name:D hash:100100>: 'd'
        #                             <Key name:E hash:362244>: 'e'
        #     <Key name:B hash:101>: 'b'

    def test_map_stress(self):
        COLLECTION_SIZE = 7000
        TEST_ITERS_EVERY = 647
        CRASH_HASH_EVERY = 97
        CRASH_EQ_EVERY = 11
        RUN_XTIMES = 3

        for _ in range(RUN_XTIMES):
            h = self.Map()
            d = dict()

            for i in range(COLLECTION_SIZE):
                key = KeyStr(i)

                if not (i % CRASH_HASH_EVERY):
                    with HashKeyCrasher(error_on_hash=True):
                        with pytest.raises(HashingError):
                            h.set(key, i)

                h = h.set(key, i)

                if not (i % CRASH_EQ_EVERY):
                    with HashKeyCrasher(error_on_eq=True):
                        with pytest.raises(EqError):
                            h.get(KeyStr(i))  # really trigger __eq__

                d[key] = i
                assert len(d) == len(h)

                if not (i % TEST_ITERS_EVERY):
                    assert set(h.items()) == set(d.items())
                    assert len(h.items()) == len(d.items())

            assert len(h) == COLLECTION_SIZE

            for key in range(COLLECTION_SIZE):
                assert h.get(KeyStr(key), 'not found') == key

            keys_to_delete = list(range(COLLECTION_SIZE))
            random.shuffle(keys_to_delete)
            for iter_i, i in enumerate(keys_to_delete):
                key = KeyStr(i)

                if not (iter_i % CRASH_HASH_EVERY):
                    with HashKeyCrasher(error_on_hash=True):
                        with pytest.raises(HashingError):
                            h.delete(key)

                if not (iter_i % CRASH_EQ_EVERY):
                    with HashKeyCrasher(error_on_eq=True):
                        with pytest.raises(EqError):
                            h.delete(KeyStr(i))

                h = h.delete(key)
                assert h.get(key, 'not found') == 'not found'
                del d[key]
                assert len(d) == len(h)

                if iter_i == COLLECTION_SIZE // 2:
                    hm = h
                    dm = d.copy()

                if not (iter_i % TEST_ITERS_EVERY):
                    assert set(h.keys()) == set(d.keys())
                    assert len(h.keys()) == len(d.keys())

            assert len(d) == 0
            assert len(h) == 0

            # ============

            for key in dm:
                assert hm.get(str(key)) == dm[key]
            assert len(dm) == len(hm)

            for i, key in enumerate(keys_to_delete):
                if str(key) in dm:
                    hm = hm.delete(str(key))
                    dm.pop(str(key))
                assert hm.get(str(key), 'not found') == 'not found'
                assert len(d) == len(h)

                if not (i % TEST_ITERS_EVERY):
                    assert set(h.values()) == set(d.values())
                    assert len(h.values()) == len(d.values())

            assert len(d) == 0
            assert len(h) == 0
            assert list(h.items()) == []

    def test_map_delete_1(self):
        A = HashKey(100, 'A')
        B = HashKey(101, 'B')
        C = HashKey(102, 'C')
        D = HashKey(103, 'D')
        E = HashKey(104, 'E')
        Z = HashKey(-100, 'Z')

        Er = HashKey(103, 'Er', error_on_eq_to=D)

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(A, 'a')
        h = h.set(B, 'b')
        h = h.set(C, 'c')
        h = h.set(D, 'd')
        h = h.set(E, 'e')

        orig_len = len(h)

        # BitmapNode(size=10 bitmap=0b111110000 id=0x10eadc618):
        #     <Key name:A hash:100>: 'a'
        #     <Key name:B hash:101>: 'b'
        #     <Key name:C hash:102>: 'c'
        #     <Key name:D hash:103>: 'd'
        #     <Key name:E hash:104>: 'e'

        h = h.delete(C)
        assert len(h) == orig_len - 1

        with pytest.raises(ValueError, match='cannot compare'):
            h.delete(Er)

        h = h.delete(D)
        assert len(h) == orig_len - 2

        with pytest.raises(KeyError) as ex:
            h.delete(Z)
        assert ex.value.args[0] is Z

        h = h.delete(A)
        assert len(h) == orig_len - 3

        assert h.get(A, 42) == 42
        assert h.get(B) == 'b'
        assert h.get(E) == 'e'

    def test_map_delete_2(self):
        A = HashKey(100, 'A')
        B = HashKey(201001, 'B')
        C = HashKey(101001, 'C')
        BLike = HashKey(201001, 'B-like')
        D = HashKey(103, 'D')
        E = HashKey(104, 'E')
        Z = HashKey(-100, 'Z')

        Er = HashKey(201001, 'Er', error_on_eq_to=B)

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(B, 'b')
        h = h.set(C, 'c')
        h = h.set(D, 'd')
        h = h.set(E, 'e')

        h = h.set(B, 'b')  # trigger branch in BitmapNode.assoc

        with pytest.raises(KeyError):
            h.delete(BLike)    # trigger branch in BitmapNode.without

        orig_len = len(h)

        # BitmapNode(size=8 bitmap=0b1110010000):
        #     <Key name:A hash:100>: 'a'
        #     <Key name:D hash:103>: 'd'
        #     <Key name:E hash:104>: 'e'
        #     NULL:
        #         BitmapNode(size=4 bitmap=0b100000000001000000000):
        #             <Key name:B hash:201001>: 'b'
        #             <Key name:C hash:101001>: 'c'

        with pytest.raises(ValueError, match='cannot compare'):
            h.delete(Er)

        with pytest.raises(KeyError) as ex:
            h.delete(Z)
        assert ex.value.args[0] is Z
        assert len(h) == orig_len

        h = h.delete(C)
        assert len(h) == orig_len - 1

        h = h.delete(B)
        assert len(h) == orig_len - 2

        h = h.delete(A)
        assert len(h) == orig_len - 3

        assert h.get(D) == 'd'
        assert h.get(E) == 'e'

        with pytest.raises(KeyError):
            h = h.delete(A)
        with pytest.raises(KeyError):
            h = h.delete(B)
        h = h.delete(D)
        h = h.delete(E)
        assert len(h) == 0

    def test_map_delete_3(self):
        A = HashKey(0b00000000001100100, 'A')
        B = HashKey(0b00000000001100101, 'B')

        C = HashKey(0b11000011100000100, 'C')
        D = HashKey(0b11000011100000100, 'D')
        X = HashKey(0b01000011100000100, 'Z')
        Y = HashKey(0b11000011100000100, 'Y')

        E = HashKey(0b00000000001101000, 'E')

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(B, 'b')
        h = h.set(C, 'c')
        h = h.set(D, 'd')
        h = h.set(E, 'e')

        assert len(h) == 5
        h = h.set(C, 'c')  # trigger branch in CollisionNode.assoc
        assert len(h) == 5

        orig_len = len(h)

        with pytest.raises(KeyError):
            h.delete(X)
        with pytest.raises(KeyError):
            h.delete(Y)

        # BitmapNode(size=6 bitmap=0b100110000):
        #     NULL:
        #         BitmapNode(size=4 bitmap=0b1000000000000000000001000):
        #             <Key name:A hash:100>: 'a'
        #             NULL:
        #                 CollisionNode(size=4 id=0x108572410):
        #                     <Key name:C hash:100100>: 'c'
        #                     <Key name:D hash:100100>: 'd'
        #     <Key name:B hash:101>: 'b'
        #     <Key name:E hash:104>: 'e'

        h = h.delete(A)
        assert len(h) == orig_len - 1

        h = h.delete(E)
        assert len(h) == orig_len - 2

        assert h.get(C) == 'c'
        assert h.get(B) == 'b'

        h2 = h.delete(C)
        assert len(h2) == orig_len - 3

        h2 = h.delete(D)
        assert len(h2) == orig_len - 3

        assert len(h) == orig_len - 2

    def test_map_delete_4(self):
        A = HashKey(100, 'A')
        B = HashKey(101, 'B')
        C = HashKey(100100, 'C')
        D = HashKey(100100, 'D')
        E = HashKey(100100, 'E')

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(B, 'b')
        h = h.set(C, 'c')
        h = h.set(D, 'd')
        h = h.set(E, 'e')

        orig_len = len(h)

        # BitmapNode(size=4 bitmap=0b110000):
        #     NULL:
        #         BitmapNode(size=4 bitmap=0b1000000000000000000001000):
        #             <Key name:A hash:100>: 'a'
        #             NULL:
        #                 CollisionNode(size=6 id=0x10515ef30):
        #                     <Key name:C hash:100100>: 'c'
        #                     <Key name:D hash:100100>: 'd'
        #                     <Key name:E hash:100100>: 'e'
        #     <Key name:B hash:101>: 'b'

        h = h.delete(D)
        assert len(h) == orig_len - 1

        h = h.delete(E)
        assert len(h) == orig_len - 2

        h = h.delete(C)
        assert len(h) == orig_len - 3

        h = h.delete(A)
        assert len(h) == orig_len - 4

        h = h.delete(B)
        assert len(h) == 0

    def test_map_delete_5(self):
        h = self.Map()

        keys = []
        for i in range(17):
            key = HashKey(i, str(i))
            keys.append(key)
            h = h.set(key, 'val-{}'.format(i))

        collision_key16 = HashKey(16, '18')
        h = h.set(collision_key16, 'collision')

        # ArrayNode(id=0x10f8b9318):
        #     0::
        #     BitmapNode(size=2 count=1 bitmap=0b1):
        #         <Key name:0 hash:0>: 'val-0'
        #
        # ... 14 more BitmapNodes ...
        #
        #     15::
        #     BitmapNode(size=2 count=1 bitmap=0b1):
        #         <Key name:15 hash:15>: 'val-15'
        #
        #     16::
        #     BitmapNode(size=2 count=1 bitmap=0b1):
        #         NULL:
        #             CollisionNode(size=4 id=0x10f2f5af8):
        #                 <Key name:16 hash:16>: 'val-16'
        #                 <Key name:18 hash:16>: 'collision'

        assert len(h) == 18

        h = h.delete(keys[2])
        assert len(h) == 17

        h = h.delete(collision_key16)
        assert len(h) == 16
        h = h.delete(keys[16])
        assert len(h) == 15

        h = h.delete(keys[1])
        assert len(h) == 14
        with pytest.raises(KeyError) as ex:
            h.delete(keys[1])
        assert ex.value.args[0] is keys[1]
        assert len(h) == 14

        for key in keys:
            if key in h:
                h = h.delete(key)
        assert len(h) == 0

    def test_map_delete_6(self):
        h = self.Map()
        h = h.set(1, 1)
        h = h.delete(1)
        assert len(h) == 0
        assert h == self.Map()

    def test_map_items_1(self):
        A = HashKey(100, 'A')
        B = HashKey(201001, 'B')
        C = HashKey(101001, 'C')
        D = HashKey(103, 'D')
        E = HashKey(104, 'E')
        F = HashKey(110, 'F')

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(B, 'b')
        h = h.set(C, 'c')
        h = h.set(D, 'd')
        h = h.set(E, 'e')
        h = h.set(F, 'f')

        it = h.items()
        assert set(list(it)) == \
            {(A, 'a'), (B, 'b'), (C, 'c'), (D, 'd'), (E, 'e'), (F, 'f')}

    def test_map_items_2(self):
        A = HashKey(100, 'A')
        B = HashKey(101, 'B')
        C = HashKey(100100, 'C')
        D = HashKey(100100, 'D')
        E = HashKey(100100, 'E')
        F = HashKey(110, 'F')

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(B, 'b')
        h = h.set(C, 'c')
        h = h.set(D, 'd')
        h = h.set(E, 'e')
        h = h.set(F, 'f')

        it = h.items()
        assert set(list(it)) == \
            {(A, 'a'), (B, 'b'), (C, 'c'), (D, 'd'), (E, 'e'), (F, 'f')}

    def test_map_items_3(self):
        h = self.Map()
        assert len(h.items()) == 0
        assert list(h.items()) == []

    def test_map_items_4(self):
        h = self.Map(a=1, b=2, c=3)
        k = h.items()
        assert set(k) == {('a', 1), ('b', 2), ('c', 3)}
        assert set(k) == {('a', 1), ('b', 2), ('c', 3)}

    def test_map_keys_1(self):
        A = HashKey(100, 'A')
        B = HashKey(101, 'B')
        C = HashKey(100100, 'C')
        D = HashKey(100100, 'D')
        E = HashKey(100100, 'E')
        F = HashKey(110, 'F')

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(B, 'b')
        h = h.set(C, 'c')
        h = h.set(D, 'd')
        h = h.set(E, 'e')
        h = h.set(F, 'f')

        assert set(list(h.keys())) == {A, B, C, D, E, F}
        assert set(list(h)) == {A, B, C, D, E, F}

    def test_map_keys_2(self):
        h = self.Map(a=1, b=2, c=3)
        k = h.keys()
        assert set(k) == {'a', 'b', 'c'}
        assert set(k) == {'a', 'b', 'c'}

    def test_map_values_1(self):
        A = HashKey(100, 'A')
        B = HashKey(101, 'B')
        C = HashKey(100100, 'C')
        D = HashKey(100100, 'D')
        E = HashKey(100100, 'E')
        F = HashKey(110, 'F')

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(B, 'b')
        h = h.set(C, 'c')
        h = h.set(D, 'd')
        h = h.set(E, 'e')
        h = h.set(F, 'f')

        assert set(list(h.values())) == {'a', 'b', 'c', 'd', 'e', 'f'}

    def test_map_values_2(self):
        h = self.Map(a=1, b=2, c=3)
        k = h.values()
        assert set(k) == {1, 2, 3}
        assert set(k) == {1, 2, 3}

    def test_map_eq_1(self):
        A = HashKey(100, 'A')
        B = HashKey(101, 'B')
        C = HashKey(100100, 'C')
        D = HashKey(100100, 'D')
        E = HashKey(120, 'E')

        h1 = self.Map()
        h1 = h1.set(A, 'a')
        h1 = h1.set(B, 'b')
        h1 = h1.set(C, 'c')
        h1 = h1.set(D, 'd')

        h2 = self.Map()
        h2 = h2.set(A, 'a')

        assert not (h1 == h2)
        assert h1 != h2

        h2 = h2.set(B, 'b')
        assert not (h1 == h2)
        assert h1 != h2

        h2 = h2.set(C, 'c')
        assert not (h1 == h2)
        assert h1 != h2

        h2 = h2.set(D, 'd2')
        assert not (h1 == h2)
        assert h1 != h2

        h2 = h2.set(D, 'd')
        assert h1 == h2
        assert not (h1 != h2)

        h2 = h2.set(E, 'e')
        assert not (h1 == h2)
        assert h1 != h2

        h2 = h2.delete(D)
        assert not (h1 == h2)
        assert h1 != h2

        h2 = h2.set(E, 'd')
        assert not (h1 == h2)
        assert h1 != h2

    def test_map_eq_2(self):
        A = HashKey(100, 'A')
        Er = HashKey(100, 'Er', error_on_eq_to=A)

        h1 = self.Map()
        h1 = h1.set(A, 'a')

        h2 = self.Map()
        h2 = h2.set(Er, 'a')

        with pytest.raises(ValueError, match='cannot compare'):
            h1 == h2

        with pytest.raises(ValueError, match='cannot compare'):
            h1 != h2

    def test_map_eq_3(self):
        assert self.Map() != 1

    def test_map_gc_1(self):
        A = HashKey(100, 'A')

        h = self.Map()
        h = h.set(0, 0)  # empty Map node is memoized in _map.c
        ref = weakref.ref(h)

        a = []
        a.append(a)
        a.append(h)
        b = []
        a.append(b)
        b.append(a)
        h = h.set(A, b)

        del h, a, b

        gc.collect()
        gc.collect()
        gc.collect()

        assert ref() is None

    def test_map_gc_2(self):
        A = HashKey(100, 'A')

        h = self.Map()
        h = h.set(A, 'a')
        h = h.set(A, h)

        ref = weakref.ref(h)
        hi = iter(h.items())
        next(hi)

        del h, hi

        gc.collect()
        gc.collect()
        gc.collect()

        assert ref() is None

    def test_map_in_1(self):
        A = HashKey(100, 'A')
        AA = HashKey(100, 'A')

        B = HashKey(101, 'B')

        h = self.Map()
        h = h.set(A, 1)

        assert A in h
        assert not (B in h)

        with pytest.raises(EqError):
            with HashKeyCrasher(error_on_eq=True):
                AA in h

        with pytest.raises(HashingError):
            with HashKeyCrasher(error_on_hash=True):
                AA in h

    def test_map_getitem_1(self):
        A = HashKey(100, 'A')
        AA = HashKey(100, 'A')

        B = HashKey(101, 'B')

        h = self.Map()
        h = h.set(A, 1)

        assert h[A] == 1
        assert h[AA] == 1

        with pytest.raises(KeyError):
            h[B]

        with pytest.raises(EqError):
            with HashKeyCrasher(error_on_eq=True):
                h[AA]

        with pytest.raises(HashingError):
            with HashKeyCrasher(error_on_hash=True):
                h[AA]

    def test_repr_1(self):
        h = self.Map()
        assert repr(h).startswith('<immutables.Map({}) at 0x')

        h = h.set(1, 2).set(2, 3).set(3, 4)
        assert repr(h).startswith(
            '<immutables.Map({1: 2, 2: 3, 3: 4}) at 0x')

    def test_repr_2(self):
        h = self.Map()
        A = HashKey(100, 'A')

        with pytest.raises(ReprError):
            with HashKeyCrasher(error_on_repr=True):
                repr(h.set(1, 2).set(A, 3).set(3, 4))

        with pytest.raises(ReprError):
            with HashKeyCrasher(error_on_repr=True):
                repr(h.set(1, 2).set(2, A).set(3, 4))

    def test_repr_3(self):
        class Key:
            def __init__(self):
                self.val = None

            def __hash__(self):
                return 123

            def __repr__(self):
                return repr(self.val)

        h = self.Map()
        k = Key()
        h = h.set(k, 1)
        k.val = h

        assert repr(h).startswith(
            '<immutables.Map({{...}: 1}) at 0x')

    def test_hash_1(self):
        h = self.Map()
        assert hash(h) != -1
        assert hash(h) == hash(h)

        h = h.set(1, 2).set('a', 'b')
        assert hash(h) != -1
        assert hash(h) == hash(h)

        assert hash(h.set(1, 2).set('a', 'b')) == \
            hash(h.set('a', 'b').set(1, 2))

    def test_hash_2(self):
        h = self.Map()
        A = HashKey(100, 'A')

        m = h.set(1, 2).set(A, 3).set(3, 4)
        with pytest.raises(HashingError):
            with HashKeyCrasher(error_on_hash=True):
                hash(m)

        m = h.set(1, 2).set(2, A).set(3, 4)
        with pytest.raises(HashingError):
            with HashKeyCrasher(error_on_hash=True):
                hash(m)

    def test_abc_1(self):
        assert issubclass(self.Map, collections.abc.Mapping)

    def test_map_mut_1(self):
        h = self.Map()
        h = h.set('a', 1)

        hm1 = h.mutate()
        hm2 = h.mutate()

        assert not isinstance(hm1, self.Map)

        assert hm1 is not hm2
        assert hm1['a'] == 1
        assert hm2['a'] == 1

        hm1.set('b', 2)
        hm1.set('c', 3)

        hm2.set('x', 100)
        hm2.set('a', 1000)

        assert hm1['a'] == 1
        assert hm1.get('x', -1) == -1

        assert hm2['a'] == 1000
        assert 'x' in hm2

        h1 = hm1.finish()
        h2 = hm2.finish()

        assert isinstance(h1, self.Map)

        assert dict(h.items()) == {'a': 1}
        assert dict(h1.items()) == {'a': 1, 'b': 2, 'c': 3}
        assert dict(h2.items()) == {'a': 1000, 'x': 100}

    def test_map_mut_2(self):
        h = self.Map()
        h = h.set('a', 1)

        hm1 = h.mutate()
        hm1.set('a', 2)
        hm1.set('a', 3)
        hm1.set('a', 4)
        h2 = hm1.finish()

        assert dict(h.items()) == {'a': 1}
        assert dict(h2.items()) == {'a': 4}

    def test_map_mut_3(self):
        h = self.Map()
        h = h.set('a', 1)
        hm1 = h.mutate()

        assert repr(hm1).startswith(
            "<immutables.MapMutation({'a': 1})")

        with pytest.raises(TypeError, match='unhashable type'):
            hash(hm1)

    def test_map_mut_4(self):
        h = self.Map()
        h = h.set('a', 1)
        h = h.set('b', 2)

        hm1 = h.mutate()
        hm2 = h.mutate()

        assert hm1 == hm2

        hm1.set('a', 10)
        assert hm1 != hm2

        hm2.set('a', 10)
        assert hm1 == hm2

        assert hm2.pop('a') == 10
        assert hm1 != hm2

    def test_map_mut_5(self):
        h = self.Map({'a': 1, 'b': 2}, z=100)
        assert isinstance(h, self.Map)
        assert dict(h.items()) == {'a': 1, 'b': 2, 'z': 100}

        h2 = h.update(z=200, y=-1)
        assert dict(h.items()) == {'a': 1, 'b': 2, 'z': 100}
        assert dict(h2.items()) == {'a': 1, 'b': 2, 'z': 200, 'y': -1}

        h3 = h2.update([(1, 2), (3, 4)])
        assert dict(h.items()) == {'a': 1, 'b': 2, 'z': 100}
        assert dict(h2.items()) == {'a': 1, 'b': 2, 'z': 200, 'y': -1}
        assert dict(h3.items()) == \
                         {'a': 1, 'b': 2, 'z': 200, 'y': -1, 1: 2, 3: 4}

        h4 = h3.update()
        assert h4 is h3

        h5 = h4.update(self.Map({'zzz': 'yyz'}))

        assert dict(h5.items()) == \
                         {'a': 1, 'b': 2, 'z': 200, 'y': -1, 1: 2, 3: 4,
                          'zzz': 'yyz'}

    def test_map_mut_6(self):
        h = self.Map({'a': 1, 'b': 2}, z=100)
        assert dict(h.items()) == {'a': 1, 'b': 2, 'z': 100}

        with pytest.raises(TypeError, match='not iterable'):
            h.update(1)

        with pytest.raises(ValueError, match='map update sequence element'):
            h.update([(1, 2), (3, 4, 5)])

        with pytest.raises(TypeError, match='cannot convert map update'):
            h.update([(1, 2), 1])

        assert dict(h.items()) == {'a': 1, 'b': 2, 'z': 100}

    def test_map_mut_7(self):
        key = HashKey(123, 'aaa')

        h = self.Map({'a': 1, 'b': 2}, z=100)
        assert dict(h.items()) == {'a': 1, 'b': 2, 'z': 100}

        upd = {key: 1}
        with HashKeyCrasher(error_on_hash=True):
            with pytest.raises(HashingError):
                h.update(upd)

        upd = self.Map({key: 'zzz'})
        with HashKeyCrasher(error_on_hash=True):
            with pytest.raises(HashingError):
                h.update(upd)

        upd = [(1, 2), (key, 'zzz')]
        with HashKeyCrasher(error_on_hash=True):
            with pytest.raises(HashingError):
                h.update(upd)

        assert dict(h.items()) == {'a': 1, 'b': 2, 'z': 100}

    def test_map_mut_8(self):
        key1 = HashKey(123, 'aaa')
        key2 = HashKey(123, 'bbb')

        h = self.Map({key1: 123})
        assert dict(h.items()) == {key1: 123}

        upd = {key2: 1}
        with HashKeyCrasher(error_on_eq=True):
            with pytest.raises(EqError):
                h.update(upd)

        upd = self.Map({key2: 'zzz'})
        with HashKeyCrasher(error_on_eq=True):
            with pytest.raises(EqError):
                h.update(upd)

        upd = [(1, 2), (key2, 'zzz')]
        with HashKeyCrasher(error_on_eq=True):
            with pytest.raises(EqError):
                h.update(upd)

        assert dict(h.items()) == {key1: 123}

    def test_map_mut_9(self):
        key1 = HashKey(123, 'aaa')

        src = {key1: 123}
        with HashKeyCrasher(error_on_hash=True):
            with pytest.raises(HashingError):
                self.Map(src)

        src = [(1, 2), (key1, 123)]
        with HashKeyCrasher(error_on_hash=True):
            with pytest.raises(HashingError):
                self.Map(src)

    def test_map_mut_10(self):
        key1 = HashKey(123, 'aaa')

        m = self.Map({key1: 123})

        mm = m.mutate()
        with HashKeyCrasher(error_on_hash=True):
            with pytest.raises(HashingError):
                del mm[key1]

        mm = m.mutate()
        with HashKeyCrasher(error_on_hash=True):
            with pytest.raises(HashingError):
                mm.pop(key1, None)

        mm = m.mutate()
        with HashKeyCrasher(error_on_hash=True):
            with pytest.raises(HashingError):
                mm.set(key1, 123)

    def test_map_mut_11(self):
        m = self.Map({'a': 1, 'b': 2})

        mm = m.mutate()
        assert mm.pop('a', 1) == 1
        assert mm.finish() == self.Map({'b': 2})

        mm = m.mutate()
        assert mm.pop('b', 1) == 2
        assert mm.finish() == self.Map({'a': 1})

        mm = m.mutate()
        assert mm.pop('b', 1) == 2
        del mm['a']
        assert mm.finish() == self.Map()

    def test_map_mut_12(self):
        m = self.Map({'a': 1, 'b': 2})

        mm = m.mutate()
        mm.finish()

        with pytest.raises(ValueError, match='has been finished'):
            mm.pop('a')

        with pytest.raises(ValueError, match='has been finished'):
            del mm['a']

        with pytest.raises(ValueError, match='has been finished'):
            mm.set('a', 'b')

        with pytest.raises(ValueError, match='has been finished'):
            mm['a'] = 'b'

        with pytest.raises(ValueError, match='has been finished'):
            mm.update(a='b')

    def test_map_mut_13(self):
        key1 = HashKey(123, 'aaa')
        key2 = HashKey(123, 'aaa')

        m = self.Map({key1: 123})

        mm = m.mutate()
        with HashKeyCrasher(error_on_eq=True):
            with pytest.raises(EqError):
                del mm[key2]

        mm = m.mutate()
        with HashKeyCrasher(error_on_eq=True):
            with pytest.raises(EqError):
                mm.pop(key2, None)

        mm = m.mutate()
        with HashKeyCrasher(error_on_eq=True):
            with pytest.raises(EqError):
                mm.set(key2, 123)

    def test_map_mut_14(self):
        m = self.Map(a=1, b=2)

        with m.mutate() as mm:
            mm['z'] = 100
            del mm['a']

        assert mm.finish() == self.Map(z=100, b=2)

    def test_map_mut_15(self):
        m = self.Map(a=1, b=2)

        with pytest.raises(ZeroDivisionError):
            with m.mutate() as mm:
                mm['z'] = 100
                del mm['a']
                1 / 0

        assert mm.finish() == self.Map(z=100, b=2)
        assert m == self.Map(a=1, b=2)

    def test_map_mut_16(self):
        m = self.Map(a=1, b=2)
        hash(m)

        m2 = self.Map(m)
        m3 = self.Map(m, c=3)

        assert m == m2
        assert len(m) == len(m2)
        assert hash(m) == hash(m2)

        assert m is not m2
        assert m3 == self.Map(a=1, b=2, c=3)

    def test_map_mut_17(self):
        m = self.Map(a=1)
        with m.mutate() as mm:
            with pytest.raises(TypeError, match='cannot create Maps from MapMutations'):
                self.Map(mm)

    def test_map_mut_18(self):
        m = self.Map(a=1, b=2)
        with m.mutate() as mm:
            mm.update(self.Map(x=1), z=2)
            mm.update(c=3)
            mm.update({'n': 100, 'a': 20})
            m2 = mm.finish()

        expected = self.Map(
            {'b': 2, 'c': 3, 'n': 100, 'z': 2, 'x': 1, 'a': 20})

        assert len(m2) == 6
        assert m2 == expected
        assert m == self.Map(a=1, b=2)

    def test_map_mut_19(self):
        m = self.Map(a=1, b=2)
        m2 = m.update({'a': 20})
        assert len(m2) == 2

    def test_map_mut_stress(self):
        COLLECTION_SIZE = 7000
        TEST_ITERS_EVERY = 647
        RUN_XTIMES = 3

        for _ in range(RUN_XTIMES):
            h = self.Map()
            d = dict()

            for i in range(COLLECTION_SIZE // TEST_ITERS_EVERY):

                hm = h.mutate()
                for j in range(TEST_ITERS_EVERY):
                    key = random.randint(1, 100000)
                    key = HashKey(key % 271, str(key))

                    hm.set(key, key)
                    d[key] = key

                    assert len(hm) == len(d)

                h2 = hm.finish()
                assert dict(h2.items()) == d
                h = h2

            assert dict(h.items()) == d
            assert len(h) == len(d)

            it = iter(tuple(d.keys()))
            for i in range(COLLECTION_SIZE // TEST_ITERS_EVERY):

                hm = h.mutate()
                for j in range(TEST_ITERS_EVERY):
                    try:
                        key = next(it)
                    except StopIteration:
                        break

                    del d[key]
                    del hm[key]

                    assert len(hm) == len(d)

                h2 = hm.finish()
                assert dict(h2.items()) == d
                h = h2

            assert dict(h.items()) == d
            assert len(h) == len(d)

    def test_map_pickle(self):
        h = self.Map(a=1, b=2)
        for proto in range(pickle.HIGHEST_PROTOCOL):
            p = pickle.dumps(h, proto)
            uh = pickle.loads(p)

            assert isinstance(uh, self.Map)
            assert h == uh

        with pytest.raises(TypeError, match="can('t|not) pickle"):
            pickle.dumps(h.mutate())

    def test_map_is_subscriptable(self):
        assert self.Map[int, str] is self.Map

class TestPyMap(BaseMapTest):
    Map = Map
