import py
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC
from pypy.module.pypyjit.test_pypy_c.model import OpMatcher

class TestCall(BaseTestPyPyC):

    def test_recursive_call(self):
        def fn():
            def rec(n):
                if n == 0:
                    return 0
                return 1 + rec(n-1)
            #
            # this loop is traced and then aborted, because the trace is too
            # long. But then "rec" is marked as "don't inline". Since we
            # already traced function from the start (because of number),
            # now we can inline it as call assembler
            i = 0
            j = 0
            while i < 25:
                i += 1
                j += rec(100) # ID: call_rec
            return j
        #
        # NB. the parameters below are a bit ad-hoc.  After 16 iterations,
        # the we trace from the "while" and reach a "trace too long".  Then
        # in the next execution, we trace the "rec" function from start;
        # that's "functrace" below.  Then after one or two extra iterations
        # we try again from "while", and this time we succeed.
        log = self.run(fn, [], threshold=20)
        functrace, loop = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('call_rec', """
            ...
            p53 = call_assembler_r(..., descr=...)
            guard_not_forced(descr=...)
            keepalive(...)
            guard_no_exception(descr=...)
            ...
        """)

    def test_fib(self):
        def fib(n):
            if n == 0 or n == 1:
                return 1
            return fib(n - 1) + fib(n - 2) # ID: call_rec

        log = self.run(fib, [7], function_threshold=15)
        loop, = log.loops_by_filename(self.filepath, is_entry_bridge='*')
        #assert loop.match_by_id('call_rec', '''
        #...
        #p1 = call_assembler(..., descr=...)
        #...
        #''')

    def test_simple_call(self):
        src = """
            OFFSET = 0
            def f(i):
                return i + 1 + OFFSET # ID: add
            def main(n):
                i = 0
                while i < n+OFFSET:   # ID: cond
                    i = f(f(i))       # ID: call
                    a = 0
                return i
        """
        log = self.run(src, [1000])
        assert log.result == 1000
        # first, we test what is inside the entry bridge
        # -----------------------------------------------
        entry_bridge, = log.loops_by_id('call', is_entry_bridge=True)
        # LOAD_GLOBAL of OFFSET
        ops = entry_bridge.ops_by_id('cond', opcode='LOAD_GLOBAL')
        assert log.opnames(ops) == ["guard_value",
                                    "guard_not_invalidated"]
        ops = entry_bridge.ops_by_id('add', opcode='LOAD_GLOBAL')
        assert log.opnames(ops) == []
        #
        ops = entry_bridge.ops_by_id('call', opcode='LOAD_GLOBAL')
        assert log.opnames(ops) == []
        #
        assert entry_bridge.match_by_id('call', """
            dummy_get_utf8?
            p38 = call_r(ConstClass(_ll_1_threadlocalref_get__Ptr_GcStruct_objectLlT_Signed), #, descr=<Callr . i EF=1 OS=5>)
            p39 = getfield_gc_r(p38, descr=<FieldP pypy.interpreter.executioncontext.ExecutionContext.inst_topframeref .*>)
            i40 = force_token()
            p41 = getfield_gc_r(p38, descr=<FieldP pypy.interpreter.executioncontext.ExecutionContext.inst_w_tracefunc .*>)
            guard_value(p41, ConstPtr(ptr42), descr=...)
            i42 = getfield_gc_i(p38, descr=<FieldU pypy.interpreter.executioncontext.ExecutionContext.inst_profilefunc .*>)
            i43 = int_is_zero(i42)
            guard_true(i43, descr=...)
            i50 = force_token()
        """)
        #
        # then, we test the actual loop
        # -----------------------------
        loop, = log.loops_by_id('call')
        assert loop.match("""
            guard_not_invalidated(descr=...)
            i9 = int_lt(i5, i6)
            guard_true(i9, descr=...)
            i10 = force_token()
            i12 = int_add(i5, 1)
            i13 = force_token()
            i15 = int_add_ovf(i12, 1)
            guard_no_overflow(descr=...)
            --TICK--
            jump(..., descr=...)
        """)

    def test_method_call(self):
        def fn(n):
            class A(object):
                def __init__(self, a):
                    self.a = a
                def f(self, i):
                    return self.a + i
            a = A("a") # stop field unboxing

            i = 0
            a = A(1)
            while i < n:
                x = a.f(i)    # ID: meth1
                i = a.f(x)    # ID: meth2
            return i
        #
        log = self.run(fn, [1000])
        assert log.result == 1000
        #
        # first, we test the entry bridge
        # -------------------------------
        entry_bridge, = log.loops_by_filename(self.filepath, is_entry_bridge=True)
        ops = entry_bridge.ops_by_id('meth1', opcode='LOAD_METHOD')
        assert log.opnames(ops) == ['guard_value', 'getfield_gc_r',
                                    'guard_value',
                                    'guard_not_invalidated']
        # the second LOAD_METHOD is folded away
        assert list(entry_bridge.ops_by_id('meth2', opcode='LOAD_METHOD')) == []
        #
        # then, the actual loop
        # ----------------------
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i15 = int_lt(i6, i9)
            guard_true(i15, descr=...)
            guard_not_invalidated(descr=...)
            i16 = force_token()
            i17 = int_add_ovf(i10, i6)
            guard_no_overflow(descr=...)
            i18 = force_token()
            i19 = int_add_ovf(i10, i17)
            guard_no_overflow(descr=...)
            --TICK--
            jump(..., descr=...)
        """)

    def test_static_classmethod_call(self):
        def fn(n):
            class A(object):
                @classmethod
                def f(cls, i):
                    return i + (cls is A) + 1
                @staticmethod
                def g(i):
                    return i - 1
            #
            i = 0
            a = A()
            while i < n:
                x = a.f(i)
                i = a.g(x)
            return i
        #
        log = self.run(fn, [1000])
        assert log.result == 1000
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i14 = int_lt(i6, i9)
            guard_true(i14, descr=...)
            guard_not_invalidated(descr=...)
            i15 = force_token()
            i17 = int_add_ovf(i8, 1)
            guard_no_overflow(descr=...)
            i18 = force_token()
            --TICK--
            jump(..., descr=...)
        """)

    def test_default_and_kw(self):
        def main(n):
            def f(i, j=1):
                return i + j
            #
            i = 0
            while i < n:
                i = f(f(i), j=1) # ID: call
                a = 0
            return i
        #
        log = self.run(main, [1000])
        assert log.result == 1000
        loop, = log.loops_by_id('call')
        assert loop.match_by_id('call', """
            guard_not_invalidated?
            i14 = force_token()
            i16 = force_token()
        """)

    def test_kwargs_empty(self):
        def main(x):
            def g(**args):
                return len(args) + 1
            #
            s = 0
            d = {}
            i = 0
            while i < x:
                s += g(**d)       # ID: call
                i += 1
            return s
        #
        log = self.run(main, [1000])
        assert log.result == 1000
        loop, = log.loops_by_id('call')
        ops = log.opnames(loop.ops_by_id('call'))
        guards = [ops for ops in ops if ops.startswith('guard')]
        assert guards == ["guard_not_invalidated", "guard_no_overflow"]

    def test_kwargs(self):
        # this is not a very precise test, could be improved
        def main(x):
            def g(**args):
                return len(args)
            #
            s = 0
            d = {"a": 1}
            i = 0
            while i < x:
                s += g(**d)       # ID: call
                d[str(i)] = i
                if i % 100 == 99:
                    d = {"a": 1}
                i += 1
            return s
        #
        log = self.run(main, [1000])
        assert log.result == 50500
        loop, = log.loops_by_id('call')
        print loop.ops_by_id('call')
        ops = log.opnames(loop.ops_by_id('call'))
        guards = [ops for ops in ops if ops.startswith('guard')]
        print guards
        assert len(guards) <= 20


    def test_stararg_virtual(self):
        def main(x):
            def g(*args):
                return len(args)
            def h(a, b, c):
                return c
            #
            s = 0
            i = 0
            while i < x:
                l = [i, x, 2]
                s += g(*l)       # ID: g1
                s += h(*l)       # ID: h1
                s += g(i, x, 2)  # ID: g2
                a = 0
                i += 1
            i = 0
            while i < x:
                l = [x, 2]
                g(*l)
                s += g(i, *l)    # ID: g3
                s += h(i, *l)    # ID: h2
                a = 0
                i += 1
            return s
        #
        log = self.run(main, [1000])
        assert log.result == 13000
        loop0, = log.loops_by_id('g1')
        assert loop0.match_by_id('g1', """
            guard_not_invalidated?
            i20 = force_token()
            i22 = int_add_ovf(i8, 3)
            guard_no_overflow(descr=...)
        """)
        assert loop0.match_by_id('h1', """
            i20 = force_token()
            i22 = int_add_ovf(i8, 2)
            guard_no_overflow(descr=...)
        """)
        assert loop0.match_by_id('g2', """
            i27 = force_token()
            i29 = int_add_ovf(i26, 3)
            guard_no_overflow(descr=...)
        """)
        #
        loop1, = log.loops_by_id('g3')
        assert loop1.match_by_id('g3', """
            i21 = force_token()
            i23 = int_add_ovf(i9, 3)
            guard_no_overflow(descr=...)
        """)
        assert loop1.match_by_id('h2', """
            i25 = force_token()
            i27 = int_add_ovf(i23, 2)
            guard_no_overflow(descr=...)
        """)

    def test_stararg(self):
        def main(x):
            def g(*args):
                return args[-1]
            def h(*args):
                return len(args)
            #
            s = 0
            l = []
            i = 0
            while i < x:
                l.append(1)
                s += g(*l)     # ID: g
                i = h(*l)      # ID: h
                a = 0
            return s
        #
        log = self.run(main, [1000])
        assert log.result == 1000
        loop, = log.loops_by_id('g')
        ops_g = log.opnames(loop.ops_by_id('g'))
        ops_h = log.opnames(loop.ops_by_id('h'))
        ops = ops_g + ops_h
        assert 'new_with_vtable' not in ops
        assert 'call_may_force' not in ops

    def test_call_builtin_function(self):
        def main(n):
            i = 2
            l = []
            while i < n:
                i += 1
                l.append(i)    # ID: append
                a = 0
            return i, len(l)
        #
        log = self.run(main, [1000])
        assert log.result == (1000, 998)
        loop, = log.loops_by_filename(self.filepath)
        # the int strategy is used here
        assert loop.match_by_id('append', """
            guard_not_invalidated?
            i15 = int_add(i13, 1)
            i17 = arraylen_gc(p15, descr=<ArrayS .>)
            i18 = int_lt(i17, i15)
            # a cond call to _ll_list_resize_hint_really_look_inside_iff
            cond_call(i18, _, p8, i15, 1, descr=<Callv 0 rii EF=5>)
            guard_no_exception(descr=...)
            p17 = getfield_gc_r(p8, descr=<FieldP list.items .*>)
            setarrayitem_gc(p17, i13, i12, descr=<ArrayS .>)
        """)

    def test_blockstack_virtualizable(self):
        def main(n):
            from pypyjit import residual_call
            l = len
            i = 0
            while i < n:
                try:
                    residual_call(l, [])   # ID: call
                except:
                    pass
                i += 1
            return i
        #
        log = self.run(main, [500])
        assert log.result == 500
        loop, = log.loops_by_id('call')
        assert loop.match_by_id('call', opcode='CALL_FUNCTION', expected_src="""
            # make sure that the "block" is not allocated
            ...
            p20 = force_token()
            p22 = new_with_vtable(descr=<SizeDescr .*>)
            p24 = new_array_clear(1, descr=<ArrayP .>)
            p26 = new_with_vtable(descr=<SizeDescr .*>)
            {{{
            setfield_gc(p0, p20, descr=<FieldP .*PyFrame.vable_token .*>)
            setfield_gc(p22, ConstPtr(null), descr=<FieldP pypy.interpreter.argument.Arguments.inst_keywords_w .*>)
            setfield_gc(p22, ConstPtr(null), descr=<FieldP pypy.interpreter.argument.Arguments.inst_keyword_names_w .*>)
            setfield_gc(p22, 1, descr=<FieldU pypy.interpreter.argument.Arguments.inst__jit_few_keywords .*>)
            setfield_gc(p22, 0, descr=<FieldU pypy.interpreter.argument.Arguments.inst_methodcall .*>)
            setfield_gc(p26, ConstPtr(ptr22), descr=<FieldP pypy.objspace.std.listobject.W_ListObject.inst_strategy .*>)
            setfield_gc(p26, ConstPtr(null), descr=<FieldP pypy.objspace.std.listobject.W_ListObject.inst_lstorage .*>)
            setarrayitem_gc(p24, 0, p26, descr=<ArrayP .>)
            setfield_gc(p22, p24, descr=<FieldP .*Arguments.inst_arguments_w .*>)
            }}}
            p32 = call_may_force_r(_, p18, p22, descr=<Callr . rr EF=7>)
            ...
        """)

    def test_func_defaults(self):
        def main(n):
            i = 1
            while i < n:
                i += len(range(i+1)) - i
            return i

        log = self.run(main, [10000])
        assert log.result == 10000
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i10 = int_lt(i5, i6)
            guard_true(i10, descr=...)
            guard_not_invalidated(descr=...)
            i120 = int_add(i5, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_global_closure_has_constant_cells(self):
        log = self.run("""
            def make_adder(n):
                def add(x):
                    return x + n
                return add
            add5 = make_adder(5)
            def main():
                i = 0
                while i < 5000:
                    i = add5(i) # ID: call
            """, [])
        loop, = log.loops_by_id('call', is_entry_bridge=True)
        assert loop.match("""
            guard_value(i4, 1, descr=...)
            guard_isnull(p5, descr=...)
            guard_nonnull_class(p12, ConstClass(W_IntObject), descr=...)
            guard_value(p2, ConstPtr(ptr21), descr=...)
            i22 = getfield_gc_i(p12, descr=<FieldS pypy.objspace.std.intobject.W_IntObject.inst_intval .*>)
            i24 = int_lt(i22, 5000)
            guard_true(i24, descr=...)
            dummy_get_utf8?
            guard_not_invalidated(descr=...)
            p29 = call_r(ConstClass(_ll_1_threadlocalref_get__Ptr_GcStruct_objectLlT_Signed), #, descr=<Callr . i EF=1 OS=5>)
            p30 = getfield_gc_r(p29, descr=<FieldP pypy.interpreter.executioncontext.ExecutionContext.inst_topframeref .*>)
            p31 = force_token()
            p32 = getfield_gc_r(p29, descr=<FieldP pypy.interpreter.executioncontext.ExecutionContext.inst_w_tracefunc .*>)
            guard_value(p32, ConstPtr(ptr33), descr=...)
            i34 = getfield_gc_i(p29, descr=<FieldU pypy.interpreter.executioncontext.ExecutionContext.inst_profilefunc .*>)
            i35 = int_is_zero(i34)
            guard_true(i35, descr=...)
            i40 = int_add(i22, 5)
            --TICK--
        """)

    def test_local_closure_is_virtual(self):
        log = self.run("""
            def main():
                i = 0
                while i < 5000:
                    def add():
                        return i + 1
                    i = add() # ID: call
            """, [])
        loop, = log.loops_by_id('call')
        assert loop.match("""
            i8 = getfield_gc_i(p6, descr=<FieldS pypy.objspace.std.intobject.W_IntObject.inst_intval .*>)
            i10 = int_lt(i8, 5000)
            guard_true(i10, descr=...)
            guard_not_invalidated?
            i11 = force_token()
            i13 = int_add(i8, 1)
            --TICK--
            p22 = new_with_vtable(descr=<SizeDescr .*>)
            setfield_gc(p22, i13, descr=<FieldS pypy.objspace.std.intobject.W_IntObject.inst_intval .*>)
            setfield_gc(p4, p22, descr=<FieldP pypy.interpreter.nestedscope.Cell.inst_w_value .*>)
            jump(..., descr=...)
        """)

    def test_kwargs_virtual(self):
        def main(n):
            def g(**kwargs):
                return kwargs["x"] + 1

            i = 0
            while i < n:
                i = g(x=i)
            return i

        log = self.run(main, [500])
        assert log.result == 500
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i2 = int_lt(i0, i1)
            guard_true(i2, descr=...)
            guard_not_invalidated?
            i3 = force_token()
            i4 = int_add(i0, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_kwargs_virtual2(self):
        log = self.run("""
        def f(*args, **kwargs):
            kwargs['a'] = kwargs['z'] * 0
            return g(1, *args, **kwargs)

        def g(x, y, z=2, a=1):
            return x - y + z + a

        def main(stop):
            res = 0
            i = 0
            while i < stop:
                res = f(res, z=i) # ID: call
                i += 1
            return res""", [1000])
        assert log.result == 500
        loop, = log.loops_by_id('call')
        assert loop.match("""
            i65 = int_lt(i58, i29)
            guard_true(i65, descr=...)
            guard_not_invalidated(..., descr=...)
            i66 = force_token()
            i67 = force_token()
            i69 = int_sub_ovf(1, i56)
            guard_no_overflow(..., descr=...)
            i70 = int_add_ovf(i69, i58)
            guard_no_overflow(..., descr=...)
            i71 = int_add(i58, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_kwargs_virtual3(self):
        log = self.run("""
        def f(a, b, c):
            pass

        def main(stop):
            i = 0
            while i < stop:
                d = {'a': 2, 'b': 3, 'c': 4}
                f(**d) # ID: call
                i += 1
            return 13
        """, [1000])
        assert log.result == 13
        loop, = log.loops_by_id('call')
        allops = loop.allops()
        calls = [op for op in allops if op.name.startswith('call')]
        assert len(calls) == 0
        assert len([op for op in allops if op.name.startswith('new')]) == 0

    def test_kwargs_update_virtual1(self):
        log = self.run("""
        def f(**kwargs):
            return len(kwargs)
        def main(stop):
            i = 0
            res = 0
            while i < stop:
                d = {'a': 1, 'b': 2}
                # used to force the dict!
                res += f(c=2, **d) # ID: call
                i += 1
            return res
        """, [1000])
        loop, = log.loops_by_id('call')
        ops = loop.ops_by_id('call')
        assert log.opnames(ops) == ["guard_not_invalidated", "force_token",
                "int_add_ovf", "guard_no_overflow"]


    def test_kwargs_non_virtual(self):
        log = self.run("""
        def f(a, b, c):
            pass

        def main(stop):
            d = {'a': 2, 'b': 3, 'c': 4}
            i = 0
            while i < stop:
                f(**d) # ID: call
                i += 1
            return 13
        """, [1000])
        assert log.result == 13
        loop, = log.loops_by_id('call')
        allops = loop.allops()
        calls = [op for op in allops if op.name.startswith('call')]
        assert OpMatcher(calls).match('''
        p93 = call_r(ConstClass(view_as_kwargs), p35, p12, descr=<.*>)
        i103 = call_i(ConstClass(_match_keywords), ConstPtr(ptr52), 0, 0, 0, p94, p98, 0, descr=<.*>)
        ''')
        assert len([op for op in allops if op.name.startswith('new')]) == 1
        # 1 alloc

    def test_complex_case(self):
        log = self.run("""
        def f(x, y, a, b, c=3, d=4):
            pass

        def main(stop):
            i = 0
            while i < stop:
                a = [1, 2]
                d = {'a': 2, 'b': 3, 'd':4}
                f(*a, **d) # ID: call
                i += 1
            return 13
        """, [1000])
        loop, = log.loops_by_id('call')
        assert loop.match_by_id('call', '''
        guard_not_invalidated?
        i1 = force_token()
        ''')

    def test_complex_case_global(self):
        log = self.run("""
        def f(x, y, a, b, c=3, d=4):
            pass

        a = [1, 2]
        d = {'a': 2, 'b': 3, 'd':4}

        def main(stop):
            i = 0
            while i < stop:
                f(*a, **d) # ID: call
                i += 1
            return 13
        """, [1000])

    def test_complex_case_loopconst(self):
        log = self.run("""
        def f(x, y, a, b, c=3, d=4):
            pass

        def main(stop):
            i = 0
            a = [1, 2]
            d = {'a': 2, 'b': 3, 'd':4}
            while i < stop:
                f(*a, **d) # ID: call
                i += 1
            return 13
        """, [1000])


    def test_nonstd_jitdriver_distinguishes_map(self):
        log = self.run("""
        def f(a):
            return a + 1
        def g(a):
            return a + 2
        def main():
            # test the "contains" jitdriver, but the others are the same
            res = (9999 in map(f, range(100000)))
            res += (9999 in map(g, range(200000)))
            return res
        """, [])
        assert len([l for l in log.loops if l.chunks[1].bytecode_name.startswith("DescrOperation.contains")]) == 2

    def test_methodcall_kwargs_regression(self):
        log = self.run("""
        class A:
            def f(self, x, y, z):
                return x + y + z
        def main():
            a = A()
            res = 0
            for i in range(10000):
                a.f(x=i, y=i+1, z=i*2) # ID: meth
                res += i
        """, [])
        
        loop, = log.loops_by_id('meth')

        assert loop.match_by_id("meth", """
            setfield_gc(p15, i65, descr=...)
            guard_not_invalidated(descr=...)
            i68 = int_mul_ovf(i62, 2)
            guard_no_overflow(descr=...)
            p69 = force_token()
        """)

