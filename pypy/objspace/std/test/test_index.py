from py.test import raises

class AppTest_IndexProtocol:
    def setup_class(cls):
        cls.w_o = cls.space.appexec([], """():
            class oldstyle:
                def __index__(self):
                    return self.ind
            return oldstyle()""")

        cls.w_n = cls.space.appexec([], """():
            class newstyle(object):
                def __index__(self):
                    return self.ind
            return newstyle()""")

        cls.w_o_no_index = cls.space.appexec([], """():
            class oldstyle_no_index:
                pass
            return oldstyle_no_index()""")

        cls.w_n_no_index = cls.space.appexec([], """():
            class newstyle_no_index(object):
                pass
            return newstyle_no_index()""")

        cls.w_TrapInt = cls.space.appexec([], """(): 
            class TrapInt(int):
                def __index__(self):
                    return self
            return TrapInt""")

    def test_basic(self):
        self.o.ind = -2
        self.n.ind = 2
        import operator
        assert operator.index(self.o) == -2
        assert operator.index(self.n) == 2
        raises(TypeError, operator.index, self.o_no_index) 
        raises(TypeError, operator.index, self.n_no_index) 

    def test_slice(self):
        self.o.ind = 1
        self.n.ind = 2
        slc = slice(self.o, self.o, self.o)
        check_slc = slice(1, 1, 1)
        assert slc.indices(self.o) == check_slc.indices(1)
        slc = slice(self.n, self.n, self.n)
        check_slc = slice(2, 2, 2)
        assert slc.indices(self.n) == check_slc.indices(2)

    def test_in_methods(self):
        self.o.ind = 5
        self.n.ind = 10
        s = "abcdefghijklmno"
        assert s.find("a", self.o, self.n) == -1
        assert s.find("f", self.o, self.n) == 5

    def test_wrappers(self):
        self.o.ind = 4
        self.n.ind = 5
        assert 6 .__index__() == 6
        assert -7 .__index__() == -7
        assert self.o.__index__() == 4
        assert self.n.__index__() == 5

    def test_subclasses(self):
        r = list(range(10))
        assert r[self.TrapInt(5):self.TrapInt(10)] == r[5:10]
        assert slice(self.TrapInt()).indices(0) == (0,0,1)

    def test_error(self):
        self.o.ind = 'dumb'
        self.n.ind = 'bad'
        import operator
        raises(TypeError, operator.index, self.o)
        raises(TypeError, operator.index, self.n)
        raises(TypeError, slice(self.o).indices, 0)
        raises(TypeError, slice(self.n).indices, 0)


class SeqTestCase:
    # This test case isn't run directly. It just defines common tests
    # to the different sequence types below
    def setup_method(self, method):
        for name in ('w_o', 'w_o2'):
            setattr(self, name, self.space.appexec([], """():
                class oldstyle:
                    def __index__(self):
                        return self.ind
                return oldstyle()"""))

        for name in ('w_n', 'w_n2'):
            setattr(self, name, self.space.appexec([], """():
                class newstyle(object):
                    def __index__(self):
                        return self.ind
                return newstyle()"""))

        self.w_TrapInt = self.space.appexec([], """(): 
            class TrapInt(int):
                def __index__(self):
                    return self
            return TrapInt""")

    def test_index(self):
        self.o.ind = -2
        self.n.ind = 2
        assert self.seq[self.n] == self.seq[2]
        assert self.seq[self.o] == self.seq[-2]

    def test_slice(self):
        self.o.ind = 1
        self.o2.ind = 3
        self.n.ind = 2
        self.n2.ind = 4
        assert self.seq[self.o:self.o2] == self.seq[1:3]
        assert self.seq[self.n:self.n2] == self.seq[2:4]

    def test_repeat(self):
        self.o.ind = 3
        self.n.ind = 2
        assert self.seq * self.o == self.seq * 3
        assert self.seq * self.n == self.seq * 2
        assert self.o * self.seq == self.seq * 3
        assert self.n * self.seq == self.seq * 2

    def test_wrappers(self):
        self.o.ind = 4
        self.n.ind = 5
        assert self.seq.__getitem__(self.o) == self.seq[4]
        assert self.seq.__mul__(self.o) == self.seq * 4
        assert self.seq.__rmul__(self.o) == self.seq * 4
        assert self.seq.__getitem__(self.n) == self.seq[5]
        assert self.seq.__mul__(self.n) == self.seq * 5
        assert self.seq.__rmul__(self.n) == self.seq * 5

    def test_subclasses(self):
        assert self.seq[self.TrapInt()] == self.seq[0]

    def test_error(self):
        self.o.ind = 'dumb'
        self.n.ind = 'bad'
        indexobj = lambda x, obj: obj.seq[x]
        raises(TypeError, indexobj, self.o, self)
        raises(TypeError, indexobj, self.n, self)
        sliceobj = lambda x, obj: obj.seq[x:]
        raises(TypeError, sliceobj, self.o, self)
        raises(TypeError, sliceobj, self.n, self)


class AppTest_ListTestCase(SeqTestCase):
    def setup_method(self, method):
        SeqTestCase.setup_method(self, method)
        self.w_seq = self.space.newlist([self.space.wrap(x) for x in (0,10,20,30,40,50)])

    def test_setdelitem(self):
        self.o.ind = -2
        self.n.ind = 2
        lst = list('ab!cdefghi!j')
        del lst[self.o]
        del lst[self.n]
        lst[self.o] = 'X'
        lst[self.n] = 'Y'
        assert lst == list('abYdefghXj')

        lst = [5, 6, 7, 8, 9, 10, 11]
        lst.__setitem__(self.n, "here")
        assert lst == [5, 6, "here", 8, 9, 10, 11]
        lst.__delitem__(self.n)
        assert lst == [5, 6, 8, 9, 10, 11]

    def test_inplace_repeat(self):
        self.o.ind = 2
        self.n.ind = 3
        lst = [6, 4]
        lst *= self.o
        assert lst == [6, 4, 6, 4]
        lst *= self.n
        assert lst == [6, 4, 6, 4] * 3

        lst = [5, 6, 7, 8, 9, 11]
        l2 = lst.__imul__(self.n)
        assert l2 is lst
        assert lst == [5, 6, 7, 8, 9, 11] * 3


class AppTest_TupleTestCase(SeqTestCase):
    def setup_method(self, method):
        SeqTestCase.setup_method(self, method)
        self.w_seq = self.space.newtuple([self.space.wrap(x) for x in (0,10,20,30,40,50)])


class StringTestCase(object):
    def test_startswith(self):
        self.o.ind = 1
        assert self.const('abc').startswith(self.const('b'), self.o)
        self.o.ind = 2
        assert not self.const('abc').startswith(self.const('abc'), 0, self.o)

    def test_endswith(self):
        self.o.ind = 1
        assert self.const('abc').endswith(self.const('a'), 0, self.o)
        self.o.ind = 2
        assert not self.const('abc').endswith(self.const('abc'), 0, self.o)

    def test_index(self):
        self.o.ind = 3
        assert self.const('abcabc').index(self.const('abc'), 0, self.o) == 0
        assert self.const('abcabc').index(self.const('abc'), self.o) == 3
        assert self.const('abcabc').rindex(self.const('abc'), 0, self.o) == 0
        assert self.const('abcabc').rindex(self.const('abc'), self.o) == 3

    def test_find(self):
        self.o.ind = 3
        assert self.const('abcabc').find(self.const('abc'), 0, self.o) == 0
        assert self.const('abcabc').find(self.const('abc'), self.o) == 3
        assert self.const('abcabc').rfind(self.const('abc'), 0, self.o) == 0
        assert self.const('abcabc').rfind(self.const('abc'), self.o) == 3

    def test_count(self):
        self.o.ind = 3
        assert self.const('abcabc').count(self.const('abc'), 0, self.o) == 1
        assert self.const('abcabc').count(self.const('abc'), self.o) == 1


class AppTest_StringTestCase(SeqTestCase, StringTestCase):
    def setup_method(self, method):
        SeqTestCase.setup_method(self, method)
        self.w_seq = self.space.wrap("this is a test")
        self.w_const = self.space.appexec([], """(): return str""")


class AppTest_RangeTestCase:

    def test_range(self):
        class newstyle(object):
            def __index__(self):
                return self.ind
        n = newstyle()
        n.ind = 5
        assert range(1, 20)[n] == 6
        assert range(1, 20).__getitem__(n) == 6

class AppTest_OverflowTestCase:

    def setup_class(cls):
        cls.w_pos = cls.space.wrap(2**100)
        cls.w_neg = cls.space.wrap(-2**100)

    def test_large_longs(self):
        assert self.pos.__index__() == self.pos
        assert self.neg.__index__() == self.neg

    def test_getitem(self):
        from sys import maxsize as maxint
        class GetItem(object):
            def __len__(self):
                return maxint
            def __getitem__(self, key):
                return key
        x = GetItem()
        assert x[self.pos] == self.pos
        assert x[self.neg] == self.neg
        assert x[self.neg:self.pos] == slice(self.neg, self.pos)
        assert x[self.neg:self.pos:1].indices(maxint) == (0, maxint, 1)

    def test_getslice_nolength(self):
        class X(object):
            def __getitem__(self, slice):
                return slice

        assert X()[-2:1] == slice(-2, 1)

    def test_sequence_repeat(self):
        raises(OverflowError, lambda: "a" * self.pos)
        raises(OverflowError, lambda: "a" * self.neg)
