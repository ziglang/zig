from rpython.rtyper.test.test_llinterp import gengraph, interpret
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rlib import rgc # Force registration of gc.collect
import gc
import py, sys

def test_collect():
    def f():
        return gc.collect()

    t, typer, graph = gengraph(f, [])
    ops = list(graph.iterblockops())
    assert len(ops) == 1
    op = ops[0][1]
    assert op.opname == 'gc__collect'
    assert len(op.args) == 0

    res = interpret(f, [])

    assert res is None

def test_collect_0():
    if sys.version_info < (2, 5):
        py.test.skip("requires Python 2.5 to call gc.collect() with an arg")

    def f():
        return gc.collect(0)

    t, typer, graph = gengraph(f, [])
    ops = list(graph.iterblockops())
    assert len(ops) == 1
    op = ops[0][1]
    assert op.opname == 'gc__collect'
    assert len(op.args) == 1
    assert op.args[0].value == 0

    res = interpret(f, [])

    assert res is None

def test_enable_disable():
    def f():
        gc.enable()
        a = gc.isenabled()
        gc.disable()
        b = gc.isenabled()
        return a and not b

    t, typer, graph = gengraph(f, [])
    blockops = list(graph.iterblockops())
    opnames = [op.opname for block, op in blockops
               if op.opname.startswith('gc__')]
    assert opnames == ['gc__enable', 'gc__isenabled',
                       'gc__disable', 'gc__isenabled']
    res = interpret(f, [])
    assert res

def test_collect_step():
    def f():
        return rgc.collect_step()

    assert f()
    t, typer, graph = gengraph(f, [])
    blockops = list(graph.iterblockops())
    opnames = [op.opname for block, op in blockops
               if op.opname.startswith('gc__')]
    assert opnames == ['gc__collect_step']
    res = interpret(f, [])
    assert res

def test__encode_states():
    val = rgc._encode_states(42, 43)
    assert rgc.old_state(val) == 42
    assert rgc.new_state(val) == 43
    assert not rgc.is_done(val)
    #
    val = rgc.collect_step()
    assert rgc.is_done(val)

def test_can_move():
    T0 = lltype.GcStruct('T')
    T1 = lltype.GcArray(lltype.Float)
    def f(i):
        if i:
            return rgc.can_move(lltype.malloc(T0))
        else:
            return rgc.can_move(lltype.malloc(T1, 1))

    t, typer, graph = gengraph(f, [int])
    ops = list(graph.iterblockops())
    res = [op for op in ops if op[1].opname == 'gc_can_move']
    assert len(res) == 2

    res = interpret(f, [1])

    assert res == True

def test_ll_arraycopy_1():
    TYPE = lltype.GcArray(lltype.Signed)
    a1 = lltype.malloc(TYPE, 10)
    a2 = lltype.malloc(TYPE, 6)
    for i in range(10): a1[i] = 100 + i
    for i in range(6):  a2[i] = 200 + i
    rgc.ll_arraycopy(a1, a2, 4, 2, 3)
    for i in range(10):
        assert a1[i] == 100 + i
    for i in range(6):
        if 2 <= i < 5:
            assert a2[i] == a1[i+2]
        else:
            assert a2[i] == 200 + i

def test_ll_arraycopy_2():
    TYPE = lltype.GcArray(lltype.Void)
    a1 = lltype.malloc(TYPE, 10)
    a2 = lltype.malloc(TYPE, 6)
    rgc.ll_arraycopy(a1, a2, 4, 2, 3)
    # nothing to assert here, should not crash...

def test_ll_arraycopy_3():
    S = lltype.Struct('S')    # non-gc
    TYPE = lltype.GcArray(lltype.Ptr(S))
    a1 = lltype.malloc(TYPE, 10)
    a2 = lltype.malloc(TYPE, 6)
    org1 = [None] * 10
    org2 = [None] * 6
    for i in range(10): a1[i] = org1[i] = lltype.malloc(S, immortal=True)
    for i in range(6):  a2[i] = org2[i] = lltype.malloc(S, immortal=True)
    rgc.ll_arraycopy(a1, a2, 4, 2, 3)
    for i in range(10):
        assert a1[i] == org1[i]
    for i in range(6):
        if 2 <= i < 5:
            assert a2[i] == a1[i+2]
        else:
            assert a2[i] == org2[i]

def test_ll_arraycopy_4():
    S = lltype.GcStruct('S')
    TYPE = lltype.GcArray(lltype.Ptr(S))
    a1 = lltype.malloc(TYPE, 10)
    a2 = lltype.malloc(TYPE, 6)
    org1 = [None] * 10
    org2 = [None] * 6
    for i in range(10): a1[i] = org1[i] = lltype.malloc(S)
    for i in range(6):  a2[i] = org2[i] = lltype.malloc(S)
    rgc.ll_arraycopy(a1, a2, 4, 2, 3)
    for i in range(10):
        assert a1[i] == org1[i]
    for i in range(6):
        if 2 <= i < 5:
            assert a2[i] == a1[i+2]
        else:
            assert a2[i] == org2[i]

def test_ll_arraycopy_5(monkeypatch):
    S = lltype.GcStruct('S')
    TYPE = lltype.GcArray(lltype.Ptr(S))
    def f():
        a1 = lltype.malloc(TYPE, 10)
        a2 = lltype.malloc(TYPE, 6)
        rgc.ll_arraycopy(a2, a1, 0, 1, 5)

    CHK = lltype.Struct('CHK', ('called', lltype.Bool))
    check = lltype.malloc(CHK, immortal=True)

    def raw_memcopy(*args):
        check.called = True

    monkeypatch.setattr(llmemory, "raw_memcopy", raw_memcopy)

    interpret(f, [])

    assert check.called

def test_ll_arraycopy_array_of_structs():
    TP = lltype.GcArray(lltype.Struct('x', ('x', lltype.Signed),
                                      ('y', lltype.Signed)))
    def f():
        a1 = lltype.malloc(TP, 3)
        a2 = lltype.malloc(TP, 3)
        for i in range(3):
            a1[i].x = 2 * i
            a1[i].y = 2 * i + 1
        rgc.ll_arraycopy(a1, a2, 0, 0, 3)
        for i in range(3):
            assert a2[i].x == 2 * i
            assert a2[i].y == 2 * i + 1


    interpret(f, [])
    a1 = lltype.malloc(TP, 3)
    a2 = lltype.malloc(TP, 3)
    a1[1].x = 3
    a1[1].y = 15
    rgc.copy_struct_item(a1, a2, 1, 2)
    assert a2[2].x == 3
    assert a2[2].y == 15

def test_ll_arraymove_1():
    TYPE = lltype.GcArray(lltype.Signed)
    a1 = lltype.malloc(TYPE, 10)
    org1 = [None] * 10
    for i in range(10): a1[i] = org1[i] = 1000 + i
    rgc.ll_arraymove(a1, 2, 4, 3)
    for i in range(10):
        if 4 <= i < 7:
            expected = org1[i - 2]
        else:
            expected = org1[i]
        assert a1[i] == expected

def test_ll_arraymove_2():
    TYPE = lltype.GcArray(lltype.Signed)
    a1 = lltype.malloc(TYPE, 10)
    org1 = [None] * 10
    for i in range(10): a1[i] = org1[i] = 1000 + i
    rgc.ll_arraymove(a1, 4, 2, 3)
    for i in range(10):
        if 2 <= i < 5:
            expected = org1[i + 2]
        else:
            expected = org1[i]
        assert a1[i] == expected

def test_ll_arraymove_gc():
    S = lltype.GcStruct('S')
    TYPE = lltype.GcArray(lltype.Ptr(S))
    a1 = lltype.malloc(TYPE, 10)
    org1 = [None] * 10
    for i in range(10): a1[i] = org1[i] = lltype.malloc(S)
    rgc.ll_arraymove(a1, 2, 4, 3)
    for i in range(10):
        if 4 <= i < 7:
            expected = org1[i - 2]
        else:
            expected = org1[i]
        assert a1[i] == expected

def test_ll_arraymove_slowpath(monkeypatch):
    monkeypatch.setattr(rgc, "must_split_gc_address_space", lambda: True)
    test_ll_arraymove_1()
    test_ll_arraymove_2()

def test_ll_arrayclear():
    TYPE = lltype.GcArray(lltype.Signed)
    a1 = lltype.malloc(TYPE, 10)
    for i in range(10):
        a1[i] = 100 + i
    rgc.ll_arrayclear(a1)
    assert len(a1) == 10
    for i in range(10):
        assert a1[i] == 0

def test__contains_gcptr():
    assert not rgc._contains_gcptr(lltype.Signed)
    assert not rgc._contains_gcptr(
        lltype.Struct('x', ('x', lltype.Signed)))
    assert rgc._contains_gcptr(
        lltype.Struct('x', ('x', lltype.Signed),
                      ('y', lltype.Ptr(lltype.GcArray(lltype.Signed)))))
    assert rgc._contains_gcptr(
        lltype.Struct('x', ('x', lltype.Signed),
                      ('y', llmemory.GCREF)))
    assert rgc._contains_gcptr(lltype.Ptr(lltype.GcStruct('x')))
    assert not rgc._contains_gcptr(lltype.Ptr(lltype.Struct('x')))
    GCPTR = lltype.Ptr(lltype.GcStruct('x'))
    assert rgc._contains_gcptr(
        lltype.Struct('FOO', ('s', lltype.Struct('BAR', ('y', GCPTR)))))

def test_ll_arraycopy_small():
    TYPE = lltype.GcArray(lltype.Signed)
    for length in range(5):
        a1 = lltype.malloc(TYPE, 10)
        a2 = lltype.malloc(TYPE, 6)
        org1 = range(20, 30)
        org2 = range(50, 56)
        for i in range(len(a1)): a1[i] = org1[i]
        for i in range(len(a2)): a2[i] = org2[i]
        rgc.ll_arraycopy(a1, a2, 4, 2, length)
        for i in range(10):
            assert a1[i] == org1[i]
        for i in range(6):
            if 2 <= i < 2 + length:
                assert a2[i] == a1[i+2]
            else:
                assert a2[i] == org2[i]


def test_ll_shrink_array_1():
    py.test.skip("implement ll_shrink_array for GcStructs or GcArrays that "
                 "don't have the shape of STR or UNICODE")

def test_ll_shrink_array_2():
    S = lltype.GcStruct('S', ('x', lltype.Signed),
                             ('vars', lltype.Array(lltype.Signed)))
    s1 = lltype.malloc(S, 5)
    s1.x = 1234
    for i in range(5):
        s1.vars[i] = 50 + i
    s2 = rgc.ll_shrink_array(s1, 3)
    assert lltype.typeOf(s2) == lltype.Ptr(S)
    assert s2.x == 1234
    assert len(s2.vars) == 3
    for i in range(3):
        assert s2.vars[i] == 50 + i

def test_get_referents():
    class X(object):
        __slots__ = ['stuff']
    x1 = X()
    x1.stuff = X()
    x2 = X()
    lst = rgc.get_rpy_referents(rgc.cast_instance_to_gcref(x1))
    lst2 = [rgc.try_cast_gcref_to_instance(X, x) for x in lst]
    assert x1.stuff in lst2
    assert x2 not in lst2

def test_get_memory_usage():
    class X(object):
        pass
    x1 = X()
    n = rgc.get_rpy_memory_usage(rgc.cast_instance_to_gcref(x1))
    assert n >= 8 and n <= 64

def test_register_custom_trace_hook():
    TP = lltype.GcStruct('X')

    def trace_func():
        xxx # should not be annotated here
    lambda_trace_func = lambda: trace_func
    
    def f():
        rgc.register_custom_trace_hook(TP, lambda_trace_func)
    
    t, typer, graph = gengraph(f, [])

    assert typer.custom_trace_funcs == [(TP, trace_func)]

def test_nonmoving_raw_ptr_for_resizable_list():
    def f(n):
        lst = ['a', 'b', 'c']
        lst = rgc.resizable_list_supporting_raw_ptr(lst)
        lst.append(chr(n))
        assert lst[3] == chr(n)
        assert lst[-1] == chr(n)
        #
        ptr = rgc.nonmoving_raw_ptr_for_resizable_list(lst)
        assert lst[:] == ['a', 'b', 'c', chr(n)]
        assert lltype.typeOf(ptr) == rffi.CCHARP
        assert [ptr[i] for i in range(4)] == ['a', 'b', 'c', chr(n)]
        #
        lst[-3] = 'X'
        assert ptr[1] == 'X'
        ptr[2] = 'Y'
        assert lst[-2] == 'Y'
        #
        addr = rffi.cast(lltype.Signed, ptr)
        ptr = rffi.cast(rffi.CCHARP, addr)
        rgc.collect()    # should not move lst.items
        lst[-4] = 'g'
        assert ptr[0] == 'g'
        ptr[3] = 'H'
        assert lst[-1] == 'H'
        return lst
    #
    # direct untranslated run
    lst = f(35)
    assert isinstance(lst, rgc._ResizableListSupportingRawPtr)
    #
    # llinterp run
    interpret(f, [35])
    #
    # compilation with the GC transformer
    import subprocess
    from rpython.translator.interactive import Translation
    #
    def main(argv):
        f(len(argv))
        print "OK!"
        return 0
    #
    t = Translation(main, gc="incminimark")
    t.disable(['backendopt'])
    t.set_backend_extra_options(c_debug_defines=True)
    exename = t.compile()
    data = subprocess.check_output([str(exename), '.', '.', '.'])
    assert data.strip().endswith('OK!')


def test_nonmoving_raw_ptr_for_resizable_list_getslice():
    def f(n):
        lst = ['a', 'b', 'c', 'd', 'e']
        lst = rgc.resizable_list_supporting_raw_ptr(lst)
        lst = lst[:3]
        lst.append(chr(n))
        assert lst[3] == chr(n)
        assert lst[-1] == chr(n)
        #
        ptr = rgc.nonmoving_raw_ptr_for_resizable_list(lst)
        assert lst[:] == ['a', 'b', 'c', chr(n)]
        assert lltype.typeOf(ptr) == rffi.CCHARP
        assert [ptr[i] for i in range(4)] == ['a', 'b', 'c', chr(n)]
        return lst
    #
    # direct untranslated run
    lst = f(35)
    assert isinstance(lst, rgc._ResizableListSupportingRawPtr)
    #
    # llinterp run
    interpret(f, [35])


def test_ll_for_resizable_list():
    def f(n):
        lst = ['a', 'b', 'c']
        lst = rgc.resizable_list_supporting_raw_ptr(lst)
        lst.append(chr(n))
        assert lst[3] == chr(n)
        assert lst[-1] == chr(n)
        #
        ll_list = rgc.ll_for_resizable_list(lst)
        assert lst[:] == ['a', 'b', 'c', chr(n)]
        assert ll_list.length == 4
        assert [ll_list.items[i] for i in range(4)] == ['a', 'b', 'c', chr(n)]
        #
        lst[-3] = 'X'
        assert ll_list.items[1] == 'X'
        ll_list.items[2] = 'Y'
        assert lst[-2] == 'Y'
        #
        return lst
    #
    # direct untranslated run
    lst = f(35)
    assert isinstance(lst, rgc._ResizableListSupportingRawPtr)
    #
    # llinterp run
    interpret(f, [35])
    #
    # compilation with the GC transformer
    import subprocess
    from rpython.translator.interactive import Translation
    #
    def main(argv):
        f(len(argv))
        print "OK!"
        return 0
    #
    t = Translation(main, gc="incminimark")
    t.disable(['backendopt'])
    t.set_backend_extra_options(c_debug_defines=True)
    exename = t.compile()
    data = subprocess.check_output([str(exename), '.', '.', '.'])
    assert data.strip().endswith('OK!')


def test_ListSupportingRawPtr_direct():
    lst = ['a', 'b', 'c']
    lst = rgc.resizable_list_supporting_raw_ptr(lst)

    def check_nonresizing():
        assert lst[1] == lst[-2] == 'b'
        lst[1] = 'X'
        assert lst[1] == 'X'
        lst[-1] = 'Y'
        assert lst[1:3] == ['X', 'Y']
        assert lst[-2:9] == ['X', 'Y']
        lst[1:2] = 'B'
        assert lst[:] == ['a', 'B', 'Y']
        assert list(iter(lst)) == ['a', 'B', 'Y']
        assert list(reversed(lst)) == ['Y', 'B', 'a']
        assert 'B' in lst
        assert 'b' not in lst
        assert p[0] == 'a'
        assert p[1] == 'B'
        assert p[2] == 'Y'
        assert lst + ['*'] == ['a', 'B', 'Y', '*']
        assert ['*'] + lst == ['*', 'a', 'B', 'Y']
        assert lst + lst == ['a', 'B', 'Y', 'a', 'B', 'Y']
        base = ['8']
        base += lst
        assert base == ['8', 'a', 'B', 'Y']
        assert lst == ['a', 'B', 'Y']
        assert ['a', 'B', 'Y'] == lst
        assert ['a', 'B', 'Z'] != lst
        assert ['a', 'B', 'Z'] >  lst
        assert ['a', 'B', 'Z'] >= lst
        assert lst * 2 == ['a', 'B', 'Y', 'a', 'B', 'Y']
        assert 2 * lst == ['a', 'B', 'Y', 'a', 'B', 'Y']
        assert lst.count('B') == 1
        assert lst.index('Y') == 2
        lst.reverse()
        assert lst == ['Y', 'B', 'a']
        lst.sort()
        assert lst == ['B', 'Y', 'a']
        lst.sort(reverse=True)
        assert lst == ['a', 'Y', 'B']
        lst[1] = 'b'
        lst[2] = 'c'
        assert list(lst) == ['a', 'b', 'c']

    p = lst
    check_nonresizing()
    assert lst._ll_list is None
    p = lst._nonmoving_raw_ptr_for_resizable_list()
    ll_list = rgc.ll_for_resizable_list(lst)
    assert ll_list is lst._ll_list
    check_nonresizing()
    assert lst._ll_list == ll_list
    assert p[0] == ll_list.items[0] == 'a'
    assert p[1] == ll_list.items[1] == 'b'
    assert p[2] == ll_list.items[2] == 'c'

    def do_resizing_operation():
        del lst[1]
        yield ['a', 'c']

        lst[:2] = ['X']
        yield ['X', 'c']

        del lst[:2]
        yield ['c']

        x = lst
        x += ['t']
        yield ['a', 'b', 'c', 't']

        x = lst
        x *= 3
        yield ['a', 'b', 'c'] * 3

        lst.append('f')
        yield ['a', 'b', 'c', 'f']

        lst.extend('fg')
        yield ['a', 'b', 'c', 'f', 'g']

        lst.insert(1, 'k')
        yield ['a', 'k', 'b', 'c']

        n = lst.pop(1)
        assert n == 'b'
        yield ['a', 'c']

        lst.remove('c')
        yield ['a', 'b']

    assert lst == ['a', 'b', 'c']
    for expect in do_resizing_operation():
        assert lst == expect
        assert lst._ll_list is None
        lst = ['a', 'b', 'c']
        lst = rgc.resizable_list_supporting_raw_ptr(lst)
        lst._nonmoving_raw_ptr_for_resizable_list()

# ____________________________________________________________


class T_Root(object):
    pass

class T_Int(T_Root):
    def __init__(self, x):
        self.x = x

class SimpleFQ(rgc.FinalizerQueue):
    Class = T_Root
    _triggered = 0
    def finalizer_trigger(self):
        self._triggered += 1

class TestFinalizerQueue:

    def test_simple(self):
        fq = SimpleFQ()
        assert fq.next_dead() is None
        assert fq._triggered == 0
        w = T_Int(67)
        fq.register_finalizer(w)
        #
        gc.collect()
        assert fq._triggered == 0
        assert fq.next_dead() is None
        #
        del w
        gc.collect()
        assert fq._triggered == 1
        n = fq.next_dead()
        assert type(n) is T_Int and n.x == 67
        #
        gc.collect()
        assert fq._triggered == 1
        assert fq.next_dead() is None

    def test_del_1(self):
        deleted = {}
        class T_Del(T_Int):
            def __del__(self):
                deleted[self.x] = deleted.get(self.x, 0) + 1

        fq = SimpleFQ()
        fq.register_finalizer(T_Del(42))
        gc.collect(); gc.collect()
        assert deleted == {}
        assert fq._triggered == 1
        n = fq.next_dead()
        assert type(n) is T_Del and n.x == 42
        assert deleted == {}
        del n
        gc.collect()
        assert fq.next_dead() is None
        assert deleted == {42: 1}
        assert fq._triggered == 1

    def test_del_2(self):
        deleted = {}
        class T_Del1(T_Int):
            def __del__(self):
                deleted[1, self.x] = deleted.get((1, self.x), 0) + 1
        class T_Del2(T_Del1):
            def __del__(self):
                deleted[2, self.x] = deleted.get((2, self.x), 0) + 1
                T_Del1.__del__(self)

        fq = SimpleFQ()
        w = T_Del2(42)
        fq.register_finalizer(w)
        del w
        fq.register_finalizer(T_Del1(21))
        gc.collect(); gc.collect()
        assert deleted == {}
        assert fq._triggered == 2
        a = fq.next_dead()
        b = fq.next_dead()
        if a.x == 21:
            a, b = b, a
        assert type(a) is T_Del2 and a.x == 42
        assert type(b) is T_Del1 and b.x == 21
        assert deleted == {}
        del a, b
        gc.collect()
        assert fq.next_dead() is None
        assert deleted == {(1, 42): 1, (2, 42): 1, (1, 21): 1}
        assert fq._triggered == 2

    def test_del_3(self):
        deleted = {}
        class T_Del1(T_Int):
            def __del__(self):
                deleted[1, self.x] = deleted.get((1, self.x), 0) + 1
        class T_Del2(T_Del1):
            pass

        fq = SimpleFQ()
        fq.register_finalizer(T_Del2(42))
        gc.collect(); gc.collect()
        assert deleted == {}
        assert fq._triggered == 1
        a = fq.next_dead()
        assert type(a) is T_Del2 and a.x == 42
        assert deleted == {}
        del a
        gc.collect()
        assert fq.next_dead() is None
        assert deleted == {(1, 42): 1}
        assert fq._triggered == 1

    def test_finalizer_trigger_calls_too_much(self):
        external_func = rffi.llexternal("foo", [], lltype.Void)
        # ^^^ with release_gil=True
        class X(object):
            pass
        class FQ(rgc.FinalizerQueue):
            Class = X
            def finalizer_trigger(self):
                external_func()
        fq = FQ()
        def f():
            x = X()
            fq.register_finalizer(x)

        e = py.test.raises(TyperError, gengraph, f, [])
        assert str(e.value).startswith('the RPython-level __del__() method in')

    def test_translated_boehm(self):
        self._test_translated(use_gc="boehm", llcase=False)

    def test_translated_boehm_ll(self):
        self._test_translated(use_gc="boehm", llcase=True)

    def test_translated_incminimark(self):
        self._test_translated(use_gc="incminimark", llcase=False)

    def test_translated_incminimark_ll(self):
        self._test_translated(use_gc="incminimark", llcase=True)

    def _test_translated(self, use_gc, llcase):
        import subprocess
        from rpython.rlib import objectmodel
        from rpython.translator.interactive import Translation
        #
        class Seen:
            count = 0
        class MySimpleFQ(rgc.FinalizerQueue):
            if not llcase:
                Class = T_Root
            else:
                Class = None
            def finalizer_trigger(self):
                seen.count += 1
        seen = Seen()
        fq = MySimpleFQ()
        if not llcase:
            EMPTY = None
            llbuilder = T_Int
        else:
            from rpython.rtyper.annlowlevel import llstr
            EMPTY = lltype.nullptr(llmemory.GCREF.TO)
            def llbuilder(n):
                return lltype.cast_opaque_ptr(llmemory.GCREF, llstr(str(n)))

        def subfunc():
            w0 = llbuilder(40); fq.register_finalizer(w0)
            w1 = llbuilder(41); fq.register_finalizer(w1)
            w2 = llbuilder(42); fq.register_finalizer(w2)
            w3 = llbuilder(43); fq.register_finalizer(w3)
            w4 = llbuilder(44); fq.register_finalizer(w4)
            w5 = llbuilder(45); fq.register_finalizer(w5)
            w6 = llbuilder(46); fq.register_finalizer(w6)
            w7 = llbuilder(47); fq.register_finalizer(w7)
            w8 = llbuilder(48); fq.register_finalizer(w8)
            w9 = llbuilder(49); fq.register_finalizer(w9)
            gc.collect()
            assert seen.count == 0
            assert fq.next_dead() is EMPTY
            objectmodel.keepalive_until_here(w0)
            objectmodel.keepalive_until_here(w1)
            objectmodel.keepalive_until_here(w2)
            objectmodel.keepalive_until_here(w3)
            objectmodel.keepalive_until_here(w4)
            objectmodel.keepalive_until_here(w5)
            objectmodel.keepalive_until_here(w6)
            objectmodel.keepalive_until_here(w7)
            objectmodel.keepalive_until_here(w8)
            objectmodel.keepalive_until_here(w9)

        def main(argv):
            assert fq.next_dead() is EMPTY
            subfunc()
            gc.collect(); gc.collect(); gc.collect()
            assert seen.count > 0
            n = fq.next_dead()
            while True:
                if not llcase:
                    assert type(n) is T_Int and 40 <= n.x <= 49
                else:
                    from rpython.rtyper.lltypesystem.rstr import STR
                    assert lltype.typeOf(n) is llmemory.GCREF
                    p = lltype.cast_opaque_ptr(lltype.Ptr(STR), n)
                    assert len(p.chars) == 2
                    assert p.chars[0] == "4"
                    assert "0" <= p.chars[1] <= "9"
                n = fq.next_dead()
                if n is EMPTY:
                    break
            print "OK!"
            return 0
        #
        t = Translation(main, gc=use_gc)
        t.disable(['backendopt'])
        t.set_backend_extra_options(c_debug_defines=True)
        exename = t.compile()
        data = subprocess.check_output([str(exename), '.', '.', '.'])
        assert data.strip().endswith('OK!')
