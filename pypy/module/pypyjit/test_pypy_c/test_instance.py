import py
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

class TestInstance(BaseTestPyPyC):

    def test_virtual_instance(self):
        def main(n):
            class A(object):
                pass
            #
            i = 0
            while i < n:
                a = A()
                assert isinstance(a, A)
                assert not isinstance(a, int)
                a.x = 2
                i = i + a.x
            return i
        #
        log = self.run(main, [1000], threshold = 400)
        assert log.result == 1000
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i7 = int_lt(i5, i6)
            guard_true(i7, descr=...)
            guard_not_invalidated(descr=...)
            i9 = int_add_ovf(i5, 2)
            guard_no_overflow(descr=...)
            --TICK--
            jump(..., descr=...)
        """)

    def test_load_attr(self):
        src = '''
            class A(object):
                pass
            a = A()
            a.x = 1
            def main(n):
                i = 0
                while i < n:
                    i = i + a.x
                return i
        '''
        log = self.run(src, [1000])
        assert log.result == 1000
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i9 = int_lt(i5, i6)
            guard_true(i9, descr=...)
            guard_not_invalidated(descr=...)
            i10 = int_add(i5, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_getattr_with_dynamic_attribute(self):
        src = """
        class A(object):
            pass

        l = ["x", "y"]

        def main():
            sum = 0
            a = A()
            a.a1 = 0
            a.a2 = 0
            a.a3 = 0
            a.a4 = 0
            a.a5 = 0 # workaround, because the first five attributes need a promotion
            a.x = 1
            a.y = 2
            i = 0
            while i < 500:
                name = l[i % 2]
                sum += getattr(a, name)
                i += 1
            return sum
        """
        log = self.run(src, [])
        assert log.result == 250 + 250*2
        loops = log.loops_by_filename(self.filepath)
        assert len(loops) == 1

    def test_mutate_class_int(self):
        def fn(n):
            class A(object):
                count = 1
                def __init__(self, a):
                    self.a = a
                def f(self):
                    return self.count
            i = 0
            a = A(1)
            while i < n:
                A.count += 1 # ID: mutate
                i = a.f()    # ID: meth1
            return i
        #
        log = self.run(fn, [1000], threshold=10)
        assert log.result == 1000
        #
        # first, we test the entry bridge
        # -------------------------------
        entry_bridge, = log.loops_by_filename(self.filepath, is_entry_bridge=True)
        ops = entry_bridge.ops_by_id('mutate', opcode='LOAD_ATTR')
        assert log.opnames(ops) == ['guard_value',
                                    'guard_not_invalidated',
                                    'getfield_gc_i']
        # the STORE_ATTR is folded away
        assert list(entry_bridge.ops_by_id('meth1', opcode='STORE_ATTR')) == []
        #
        # then, the actual loop
        # ----------------------
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i58 = int_lt(i38, i31)
            guard_true(i58, descr=...)
            guard_not_invalidated(descr=...)
            i59 = int_add_ovf(i57, 1)
            guard_no_overflow(descr=...)
            p60 = force_token()
            i61 = getfield_raw_i(..., descr=...)
            setfield_gc(ConstPtr(ptr39), i59, descr=...)
            i62 = int_lt(i61, 0)
            guard_false(i62, descr=...)
            jump(..., descr=...)
        """)

    def test_mutate_class(self):
        def fn(n):
            class LL(object):
                def __init__(self, n):
                    self.n = n
            class A(object):
                count = None
                def __init__(self, a):
                    self.a = a
                def f(self):
                    return self.count
            i = 0
            a = A(1)
            while i < n:
                A.count = LL(A.count) # ID: mutate
                a.f()    # ID: meth1
                i += 1
            return i
        #
        log = self.run(fn, [1000], threshold=10)
        assert log.result == 1000
        #
        # first, we test the entry bridge
        # -------------------------------
        entry_bridge, = log.loops_by_filename(self.filepath, is_entry_bridge=True)
        ops = entry_bridge.ops_by_id('mutate', opcode='LOAD_ATTR')
        assert log.opnames(ops) == ['guard_value',
                                    'guard_not_invalidated',
                                    'getfield_gc_r', 'guard_nonnull_class',
                                    'getfield_gc_r', 'guard_value', # type check on the attribute
                                    ]
        # the STORE_ATTR is folded away
        assert list(entry_bridge.ops_by_id('meth1', opcode='STORE_ATTR')) == []
        #
        # then, the actual loop
        # ----------------------
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i70 = int_lt(i58, i33)
            guard_true(i70, descr=...)
            guard_not_invalidated(descr=...)
            p71 = getfield_gc_r(p64, descr=...)
            guard_value(p71, ConstPtr(ptr42), descr=...)
            p72 = force_token()
            p73 = force_token()
            i74 = int_add(i58, 1)
            i75 = getfield_raw_i(..., descr=...)
            i76 = int_lt(i75, 0)
            guard_false(i76, descr=...)
            p77 = new_with_vtable(descr=...)
            setfield_gc(p77, p64, descr=...)
            setfield_gc(p77, ConstPtr(null), descr=...)
            setfield_gc(p77, ConstPtr(null), descr=...)
            setfield_gc(p77, ConstPtr(null), descr=...)
            setfield_gc(p77, ConstPtr(null), descr=...)
            setfield_gc(p77, ConstPtr(ptr42), descr=...)
            setfield_gc(ConstPtr(ptr69), p77, descr=...)
            jump(..., descr=...)

        """)

    def test_python_contains(self):
        def main():
            class A(object):
                def __contains__(self, v):
                    return True

            i = 0
            a = A()
            while i < 100:
                i += i in a # ID: contains
                b = 0       # to make sure that JUMP_ABSOLUTE is not part of the ID

        log = self.run(main, [], threshold=80)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id("contains", """
            guard_not_invalidated(descr=...)
            i11 = force_token()
            i12 = int_add(i5, 1)
        """)

    def test_id_compare_optimization(self):
        def main():
            class A(object):
                pass
            #
            i = 0
            a = A()
            while i < 300:
                new_a = A()
                if new_a != a:  # ID: compare
                    pass
                i += 1
            return i
        #
        log = self.run(main, [])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id("compare", "") # optimized away

    def test_super(self):
        def main():
            class A(object):
                def m(self, x):
                    return x + 1
            class B(A):
                def m(self, x):
                    return super(B, self).m(x)
            i = 0
            while i < 300:
                i = B().m(i)
            return i

        log = self.run(main, [])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i78 = int_lt(i72, 300)
            guard_true(i78, descr=...)
            guard_not_invalidated(descr=...)
            i79 = force_token()
            i80 = force_token()
            i81 = int_add(i72, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_super_no_args(self):
        def main():
            class A(object):
                def m(self, x):
                    return x + 1
            class B(A):
                def m(self, x):
                    return super().m(x)
            i = 0
            while i < 300:
                i = B().m(i)
            return i

        log = self.run(main, [])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i78 = int_lt(i72, 300)
            guard_true(i78, descr=...)
            guard_not_invalidated(descr=...)
            p1 = force_token()
            p65 = force_token()
            p3 = force_token()
            i81 = int_add(i72, 1)

            # can't use TICK here, because of the extra setfield_gc
            ticker0 = getfield_raw_i(#, descr=<FieldS pypysig_long_struct.c_value .*>)
            setfield_gc(p0, p65, descr=<FieldP pypy.interpreter.pyframe.PyFrame.vable_token .>)
            ticker_cond0 = int_lt(ticker0, 0)
            guard_false(ticker_cond0, descr=...)

            jump(..., descr=...)
        """)

    def test_float_instance_field_read(self):
        def main():
            class A(object):
                def __init__(self, x, y):
                    self.x = float(x)
                    self.y = float(y)

            l = [A(i, i * 5) for i in range(2000)]

            res = 0
            for x in l:
                res += x.x + x.y # ID: get
            return res
        log = self.run(main, [])
        listcomp, loop, = log.loops_by_filename(self.filepath)
        loop.match_by_id('get', """
            p67 = getfield_gc_r(p63, descr=...) # map
            guard_value(p67, ConstPtr(ptr68), descr=...) # promote map
            guard_not_invalidated(descr=...)
            p69 = getfield_gc_r(p63, descr=...) # value0
            i71 = getarrayitem_gc_i(p69, 0, descr=...) # x
            f71 = convert_longlong_bytes_to_float(i71)
            i73 = getarrayitem_gc_i(p69, 1, descr=...) # y
            f73 = convert_longlong_bytes_to_float(i73)
            f74 = float_add(f71, f73) # add them
            f75 = float_add(f57, f74)
            --TICK--
""")

    def test_float_instance_field_write(self):
        def main():
            class A(object):
                def __init__(self, x):
                    self.x = float(x)

            l = [A(i) for i in range(2000)]

            for a in l:
                a.x += 3.4 # ID: set
        log = self.run(main, [])
        listcomp, loop, = log.loops_by_filename(self.filepath)
        loop.match_by_id('set', """
            p60 = getfield_gc_r(p56, descr=...) # map
            guard_value(p60, ConstPtr(ptr61), descr=...)
            guard_not_invalidated(descr=...)
            p62 = getfield_gc_r(p56, descr=...) # value
            i64 = getarrayitem_gc_i(p62, 0, descr=...) # x
            f64 = convert_longlong_bytes_to_float(i64)
            f66 = float_add(f64, 3.400000) 
            i66 = convert_float_bytes_to_longlong(f66)
            i68 = getfield_raw_i(..., descr=...)
            setarrayitem_gc(p62, 0, i66, descr=...) # store x
            i71 = int_lt(i68, 0)
            guard_false(i71, descr=...)
""")


    def test_namedtuple_construction(self):
        def main():
            from collections import namedtuple
            A = namedtuple("A", "x y")
            res = 0
            i = 0
            while i < 2000:
                res += A(i, 0).x
                i += 1
        log = self.run(main, [])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i7 = int_lt(i5, 2000)
            guard_true(i7, descr=...)
            guard_not_invalidated(descr=...)
            p1 = force_token()
            p2 = force_token()
            i20 = int_add_ovf(i19, i5)
            guard_no_overflow(descr=...)
            i9 = int_add(i5, 1)
            --TICK--
            jump(..., descr=...)
        """)

