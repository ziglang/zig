from pypy.conftest import option


class AppTestReferents(object):

    def setup_class(cls):
        from rpython.rlib import rgc
        cls._backup = [rgc.get_rpy_roots]
        w = cls.space.wrap
        space = cls.space
        if option.runappdirect:
            ro = None
        else:
            class RandomRPythonObject(object):
                pass
            ro = RandomRPythonObject()
        l4 = space.newlist([w(4)])
        l2 = space.newlist([w(2)])
        l7 = space.newlist([w(7)])
        cls.ALL_ROOTS = [l4, space.newlist([l2, l7]), ro,
                         space.newtuple([l7])]
        cls.w_ALL_ROOTS = cls.space.newlist(cls.ALL_ROOTS)
        rgc.get_rpy_roots = lambda: (
            map(rgc._GcRef, cls.ALL_ROOTS) + [rgc.NULL_GCREF]*17)
        cls.w_runappdirect = cls.space.wrap(option.runappdirect)

    def teardown_class(cls):
        from rpython.rlib import rgc
        rgc.get_rpy_roots = cls._backup[0]

    def test_get_objects(self):
        import gc
        lst = gc.get_objects()
        i4, l27, ro, rt = self.ALL_ROOTS
        i2, i7 = l27
        found = 0
        for x in lst:
            if x is i4: found |= 1
            if x is i2: found |= 2
            if x is i7: found |= 4
            if x is l27: found |= 8
        assert found == 15
        for x in lst:
            if type(x) is gc.GcRef:
                assert 0, "get_objects() returned a GcRef"

    def test_get_rpy_roots(self):
        import gc
        lst = gc.get_rpy_roots()
        if self.runappdirect:
            pass    # unsure what to test
        else:
            assert lst[0] == [4]
            assert lst[1] == [[2], [7]]
            assert type(lst[2]) is gc.GcRef
            assert lst[3] == ([7],)
            assert len(lst) == 4

    def test_get_rpy_referents(self):
        import gc
        y = [12345]
        x = [y]
        lst = gc.get_rpy_referents(x)
        # After translation, 'lst' should contain the RPython-level list
        # (as a GcStruct).  Before translation, the 'wrappeditems' list.
        print(lst)
        lst2 = [x for x in lst if type(x) is gc.GcRef]
        assert lst2 != []
        # In any case, we should land on 'y' after one or two extra levels
        # of indirection.
        lst3 = []
        for x in lst2: lst3 += gc.get_rpy_referents(x)
        if y not in lst3:
            lst4 = []
            for x in lst3: lst4 += gc.get_rpy_referents(x)
            if y not in lst4:
                assert 0, "does not seem to reach 'y'"

    def test_get_rpy_memory_usage(self):
        import gc
        n = gc.get_rpy_memory_usage(12345)
        print(n)
        assert 4 <= n <= 64

    def test_get_rpy_type_index(self):
        import gc
        class Foo(object):
            pass
        n1 = gc.get_rpy_type_index(12345)
        n2 = gc.get_rpy_type_index(23456)
        n3 = gc.get_rpy_type_index(1.2)
        n4 = gc.get_rpy_type_index(Foo())
        print(n1, n2, n3, n4)
        assert n1 == n2
        assert n1 != n3
        assert n1 != n4
        assert n3 != n4

    def test_get_referents(self):
        import gc
        y = [12345]
        z = [23456]
        x = [y, z]
        lst = gc.get_referents(x)
        assert y in lst and z in lst

    def test_get_referrers(self):
        import gc
        l27 = self.ALL_ROOTS[1]
        i2, i7 = l27
        lst = gc.get_referrers(i7)
        for x in lst:
            if x is l27:
                break   # found
        else:
            assert 0, "the list [2, 7] is not found as gc.get_referrers(7)"
        l7t = self.ALL_ROOTS[3]
        for x in lst:
            if x is l7t:
                break   # found
        else:
            if i7 is self.ALL_ROOTS[3][0]: # not the case under runappdirect
                assert 0, "the tuple (7,) is not found as gc.get_referrers(7)"


class AppTestReferentsMore(object):

    def setup_class(cls):
        from rpython.rlib import rgc
        cls._backup = [rgc.get_rpy_roots]
        l4 = cls.space.newlist([])
        cls.ALL_ROOTS = [l4]
        cls.w_ALL_ROOTS = cls.space.newlist(cls.ALL_ROOTS)
        rgc.get_rpy_roots = lambda: (
            map(rgc._GcRef, cls.ALL_ROOTS) + [rgc.NULL_GCREF]*2)
        cls.w_runappdirect = cls.space.wrap(option.runappdirect)

    def teardown_class(cls):
        from rpython.rlib import rgc
        rgc.get_rpy_roots = cls._backup[0]

    def test_get_referrers(self):
        import gc
        class A(object):
            pass
        a = A()
        if not self.runappdirect:
            l4 = self.ALL_ROOTS[0]
            l4.append(a)              # add 'a' to the list which is in roots
        lst = gc.get_referrers(A)
        assert a in lst
        lst = gc.get_referrers(A)
        assert a in lst
        lst = gc.get_referrers(A)
        assert a in lst
        lst = gc.get_referrers(A)
        assert a in lst
