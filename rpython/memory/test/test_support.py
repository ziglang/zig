from rpython.rlib.objectmodel import free_non_gc_object
from rpython.memory.support import get_address_stack
from rpython.memory.support import get_address_deque

from rpython.rtyper.test.test_llinterp import interpret
from rpython.rtyper.lltypesystem import lltype, llmemory, llarena
from rpython.rtyper.lltypesystem.llmemory import raw_malloc, raw_free, NULL

import random

class TestAddressStack(object):
    def test_simple_access(self):
        AddressStack = get_address_stack()
        addr0 = raw_malloc(llmemory.sizeof(lltype.Signed))
        addr1 = raw_malloc(llmemory.sizeof(lltype.Signed))
        addr2 = raw_malloc(llmemory.sizeof(lltype.Signed))
        ll = AddressStack()
        ll.append(addr0)
        ll.append(addr1)
        ll.append(addr2)
        assert ll.non_empty()
        a = ll.pop()
        assert a == addr2
        assert ll.non_empty()
        a = ll.pop()
        assert a == addr1
        assert ll.non_empty()
        a = ll.pop()
        assert a == addr0
        assert not ll.non_empty()
        ll.append(addr0)
        ll.delete()
        ll = AddressStack()
        ll.append(addr0)
        ll.append(addr1)
        ll.append(addr2)
        ll.append(NULL)
        a = ll.pop()
        assert a == NULL
        ll.delete()
        raw_free(addr2)
        raw_free(addr1)
        raw_free(addr0)

    def test_big_access(self):
        AddressStack = get_address_stack()
        addrs = [raw_malloc(llmemory.sizeof(lltype.Signed))
                 for i in range(3000)]
        ll = AddressStack()
        for i in range(3000):
            print i
            ll.append(addrs[i])
        for i in range(3000)[::-1]:
            a = ll.pop()
            assert a == addrs[i]
        for i in range(3000):
            print i
            ll.append(addrs[i])
        for i in range(3000)[::-1]:
            a = ll.pop()
            assert a == addrs[i]
        ll.delete()
        for addr in addrs:
            raw_free(addr)

    def test_foreach(self):
        AddressStack = get_address_stack()
        addrs = [raw_malloc(llmemory.sizeof(lltype.Signed))
                 for i in range(3000)]
        ll = AddressStack()
        for i in range(3000):
            ll.append(addrs[i])

        seen = []

        def callback(addr, fortytwo):
            assert fortytwo == 42
            seen.append(addr)

        ll.foreach(callback, 42)
        assert seen == addrs or seen[::-1] == addrs   # order not guaranteed

    def test_remove(self):
        AddressStack = get_address_stack()
        addrs = [raw_malloc(llmemory.sizeof(lltype.Signed))
                 for i in range(2200)]
        ll = AddressStack()
        for i in range(2200):
            ll.append(addrs[i])
        ll.remove(addrs[-400])
        expected = range(2200)
        del expected[-400]
        expected.reverse()
        for i in expected:
            a = ll.pop()
            assert a == addrs[i]
        assert not ll.non_empty()

    def test_length(self):
        AddressStack = get_address_stack(10)
        ll = AddressStack()
        a = raw_malloc(llmemory.sizeof(lltype.Signed))
        for i in range(42):
            assert ll.length() == i
            ll.append(a)
        for i in range(42-1, -1, -1):
            b = ll.pop()
            assert b == a
            assert ll.length() == i

    def test_sort(self):
        AddressStack = get_address_stack(chunk_size=15)
        lla = llarena.arena_malloc(10, 2)
        addrs = [lla + i for i in range(10)]
        for _ in range(13):
            ll = AddressStack()
            addr_copy = addrs[:]
            random.shuffle(addr_copy)
            for i in addr_copy:
                ll.append(i)
            ll.sort()
            expected = range(10)
            for i in expected:
                a = ll.pop()
                assert a == addrs[i]



class TestAddressDeque:
    def test_big_access(self):
        import random
        AddressDeque = get_address_deque(10)
        deque = AddressDeque()
        expected = []
        for i in range(3000):
            assert deque.non_empty() == (len(expected) > 0)
            r = random.random()
            if r < 0.51 and expected:
                x = deque.popleft()
                y = expected.pop(0)
                assert x == y
            else:
                x = raw_malloc(llmemory.sizeof(lltype.Signed))
                deque.append(x)
                expected.append(x)

    def test_foreach(self):
        AddressDeque = get_address_deque(10)
        ll = AddressDeque()
        for num_entries in range(30, -1, -1):
            addrs = [raw_malloc(llmemory.sizeof(lltype.Signed))
                     for i in range(num_entries)]
            for a in addrs:
                ll.append(a)

            seen = []
            def callback(addr, fortytwo):
                assert fortytwo == 42
                seen.append(addr)

            ll.foreach(callback, 42)
            assert seen == addrs
            seen = []
            ll.foreach(callback, 42, step=2)
            assert seen == addrs[::2]

            for a in addrs:
                b = ll.popleft()
                assert a == b
            assert not ll.non_empty()


def test_stack_annotate():
    AddressStack = get_address_stack(60)
    INT_SIZE = llmemory.sizeof(lltype.Signed)
    def f():
        addr = raw_malloc(INT_SIZE*100)
        ll = AddressStack()
        ll.append(addr)
        ll.append(addr + INT_SIZE*1)
        ll.append(addr + INT_SIZE*2)
        a = ll.pop()
        res = (a - INT_SIZE*2 == addr)
        a = ll.pop()
        res = res and (a - INT_SIZE*1 == addr)
        res = res and ll.non_empty()
        a = ll.pop()
        res = res and a == addr
        res = res and not ll.non_empty()
        ll.append(addr)
        for i in range(300):
            ll.append(addr + INT_SIZE*i)
        for i in range(299, -1, -1):
            a = ll.pop()
            res = res and (a - INT_SIZE*i == addr)
        for i in range(300):
            ll.append(addr + INT_SIZE*i)
        for i in range(299, -1, -1):
            a = ll.pop()
            res = res and (a - INT_SIZE*i == addr)
        ll.delete()
        ll = AddressStack()
        ll.append(addr)
        ll.append(addr + INT_SIZE*1)
        ll.append(addr + INT_SIZE*2)
        ll.delete()
        raw_free(addr)
        return res

    assert f()
    AddressStack = get_address_stack()
    res = interpret(f, [], malloc_check=False)
    assert res
