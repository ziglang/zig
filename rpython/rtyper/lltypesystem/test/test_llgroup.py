from rpython.rtyper.lltypesystem.llgroup import *
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.test.test_llinterp import interpret


class TestLLGroup(object):

    def _freeze_(self):
        return True

    def build(self):
        grp = group('testing')
        S1 = lltype.Struct('S1', ('x', lltype.Signed))
        S2 = lltype.Struct('S2', ('y', lltype.Signed), ('z', lltype.Signed))
        p1a = lltype.malloc(S1, immortal=True, zero=True)
        p1b = lltype.malloc(S1, immortal=True, zero=True)
        p2a = lltype.malloc(S2, immortal=True, zero=True)
        p2b = lltype.malloc(S2, immortal=True, zero=True)
        p1a.x = 123
        p1b.x = 456
        p2a.y = 789
        p2b.z = -12
        self.g1a = grp.add_member(p1a)
        self.g2a = grp.add_member(p2a)
        self.g2b = grp.add_member(p2b)
        self.g1b = grp.add_member(p1b)
        self.p1a = p1a
        self.p1b = p1b
        self.p2a = p2a
        self.p2b = p2b
        self.S1 = S1
        self.S2 = S2
        self.grp = grp
        self.grpptr = grp._as_ptr()

    def test_simple(self):
        self.build()
        grpptr = self.grpptr
        S1 = self.S1
        S2 = self.S2
        Ptr = lltype.Ptr
        assert llop.get_group_member(Ptr(S1), grpptr, self.g1a) == self.p1a
        assert llop.get_group_member(Ptr(S1), grpptr, self.g1b) == self.p1b
        assert llop.get_group_member(Ptr(S2), grpptr, self.g2a) == self.p2a
        assert llop.get_group_member(Ptr(S2), grpptr, self.g2b) == self.p2b

    def test_member_of_group(self):
        self.build()
        assert member_of_group(self.p1a) == self.grp
        assert member_of_group(self.p2b) == self.grp
        pnew = lltype.malloc(self.S2, immortal=True)
        assert member_of_group(pnew) is None

    def test_interpreted(self):
        f = build_test()
        res = f()
        assert res == 42

    def test_rpython(self):
        f = build_test()
        res = interpret(f, [])
        assert res == 42


def build_test():
    test = TestLLGroup()
    test.build()
    grpptr = test.grpptr
    g1x = [test.g1a, test.g1b]
    MASK = CombinedSymbolic.MASK
    cs1 = CombinedSymbolic(test.g1b, 0x45 << HALFSHIFT)
    cs2 = CombinedSymbolic(test.g1b, 0x41 << HALFSHIFT)
    assert llop.extract_ushort(HALFWORD, cs1) is test.g1b
    assert cs1 & ~MASK == 0x45 << HALFSHIFT
    cslist = [cs1, cs2]
    #
    def f():
        p = llop.get_group_member(lltype.Ptr(test.S1), grpptr, test.g1a)
        assert p == test.p1a
        p = llop.get_group_member(lltype.Ptr(test.S1), grpptr, test.g1b)
        assert p == test.p1b
        p = llop.get_group_member(lltype.Ptr(test.S2), grpptr, test.g2a)
        assert p == test.p2a
        p = llop.get_group_member(lltype.Ptr(test.S2), grpptr, test.g2b)
        assert p == test.p2b
        #
        p = llop.get_next_group_member(lltype.Ptr(test.S2), grpptr,
                                       test.g1a, llmemory.sizeof(test.S1))
        assert p == test.p2a
        p = llop.get_next_group_member(lltype.Ptr(test.S2), grpptr,
                                       test.g2a, llmemory.sizeof(test.S2))
        assert p == test.p2b
        p = llop.get_next_group_member(lltype.Ptr(test.S1), grpptr,
                                       test.g2b, llmemory.sizeof(test.S2))
        assert p == test.p1b
        #
        expected = [123, 456]
        for i in range(2):
            p = llop.get_group_member(lltype.Ptr(test.S1), grpptr, g1x[i])
            assert p.x == expected[i]
        #
        for i in range(2):
            s = llop.extract_ushort(HALFWORD, cslist[i])
            p = llop.get_group_member(lltype.Ptr(test.S1), grpptr, s)
            assert p == test.p1b
        assert cslist[0] & ~MASK == 0x45 << HALFSHIFT
        assert cslist[1] & ~MASK == 0x41 << HALFSHIFT
        assert cslist[0] >> HALFSHIFT == 0x45
        assert cslist[1] >> (HALFSHIFT+1) == 0x41 >> 1
        #
        return 42
    return f
