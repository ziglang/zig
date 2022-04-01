import random, sys
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.memory import support, lldict


class TestLLAddressDict:

    def setup_method(self, meth):
        lldict.alloc_count = 0

    def test_basics(self):
        d = lldict.newdict()
        d.add(intaddr(42))
        d.setitem(intaddr(43), intaddr(44))
        assert not d.contains(intaddr(41))
        assert d.contains(intaddr(42))
        assert d.contains(intaddr(43))
        assert not d.contains(intaddr(44))
        assert d.get(intaddr(41)) == llmemory.NULL
        assert d.get(intaddr(42)) == llmemory.NULL
        assert d.get(intaddr(43)) == intaddr(44)
        assert d.get(intaddr(44)) == llmemory.NULL
        assert d.length() == 2
        d.delete()
        assert lldict.alloc_count == 0

    def test_foreach(self):
        d = lldict.newdict()
        for i in range(30):
            d.setitem(intaddr(0x100 * i), intaddr(i))
        result = []
        d.foreach(lambda key, value, arg: result.append((key, value, arg)),
                  "hello world")
        assert len(result) == 30
        seen = {}
        for key, value, arg in result:
            assert key.intval == 0x100 * value.intval
            assert arg == "hello world"
            seen[key.intval] = True
        assert len(seen) == 30
        d.delete()
        assert lldict.alloc_count == 0

    def test_copy_and_update(self):
        d = lldict.newdict(3)
        d.setitem(intaddr(41), intaddr(44))
        d.insertclean(intaddr(42), intaddr(45))
        d.setitem(intaddr(43), intaddr(46))
        def surviving(key):
            return key.intval != 41
        def updated_address(key):
            return intaddr({42: 42, 43: 99}[key.intval])
        d2 = support.copy_and_update(d, surviving, updated_address)
        d.delete()
        assert d2.length() == 2
        assert d2.get(intaddr(41)) == llmemory.NULL
        assert d2.get(intaddr(42)) == intaddr(45)
        assert d2.get(intaddr(43)) == llmemory.NULL
        assert d2.get(intaddr(99)) == intaddr(46)
        d2.delete()
        assert lldict.alloc_count == 0

    def test_clear(self):
        d = lldict.newdict()
        d.setitem(intaddr(41), intaddr(42))
        d.clear()
        assert d.length() == 0
        assert not d.contains(intaddr(41))
        d.delete()
        assert lldict.alloc_count == 0

    def test_random(self):
        for i in range(8) + range(8, 80, 10):
            examples = {}
            lst = []
            for j in range(i):
                if j % 17 == 13:
                    intval = random.choice(lst)
                else:
                    intval = random.randrange(-sys.maxint, sys.maxint) or 1
                lst.append(intval)
                examples[intval] = True

            d = lldict.newdict()
            for intval in lst:
                d.setitem(intaddr(intval), intaddr(-intval))
            for intval in lst:
                assert d.contains(intaddr(intval))
                assert d.get(intaddr(intval), "???").intval == -intval
            for intval in lst:
                for j in range(intval-5, intval+5):
                    if j not in examples:
                        assert not d.contains(intaddr(j))
            assert not d.contains(llmemory.NULL)
            d.delete()
            assert lldict.alloc_count == 0


class intaddr(object):
    _TYPE = llmemory.Address
    def __init__(self, intval):
        self.intval = intval
    def _cast_to_int(self, symbolic="?"):
        return self.intval
    def __repr__(self):
        return '<intaddr 0x%x>' % (self.intval & (sys.maxint*2+1),)
    def __eq__(self, other):
        return isinstance(other, intaddr) and self.intval == other.intval
    def __ne__(self, other):
        return not self.__eq__(other)
