import py
from rpython.rlib.jit import JitDriver, promote, elidable, set_param
from rpython.jit.codewriter.policy import StopAtXPolicy
from rpython.jit.metainterp.test.support import LLJitMixin

class SendTests(object):

    def test_green_send(self):
        myjitdriver = JitDriver(greens = ['i'], reds = ['counter'])
        lst = ["123", "45"]
        def f(i):
            counter = 20
            c = 0
            while counter > 0:
                myjitdriver.can_enter_jit(counter=counter, i=i)
                myjitdriver.jit_merge_point(counter=counter, i=i)
                s = lst[i]
                c = len(s)
                counter -= 1
            return c
        res = self.meta_interp(f, [1])
        assert res == 2
        self.check_resops({'jump': 1, 'guard_true': 2, 'int_gt': 2,
                           'int_sub': 2}) # all folded away

    def test_red_builtin_send(self):
        myjitdriver = JitDriver(greens = [], reds = ['i', 'counter'])
        lst = [{1:1, 2:2, 3:3}, {4:4, 5:5}]
        def externfn(i):
            return lst[i]
        def f(i):
            counter = 20
            res = 0
            while counter > 0:
                myjitdriver.can_enter_jit(counter=counter, i=i)
                myjitdriver.jit_merge_point(counter=counter, i=i)
                dct = externfn(i)
                res = len(dct)
                counter -= 1
            return res
        res = self.meta_interp(f, [1], policy=StopAtXPolicy(externfn))
        assert res == 2
        # 'len' becomes a getfield('num_items') for now in lltype,
        # which is itself encoded as a 'getfield_gc'
        self.check_resops(call_r=2, getfield_gc_i=2)

    def test_send_to_single_target_method(self):
        myjitdriver = JitDriver(greens = [], reds = ['i', 'counter'])
        class Foo:
            def meth(self, y):
                return self.x + y
        def externfn(i):
            foo = Foo()
            foo.x = i * 42
            return foo
        def f(i):
            counter = 20
            res = 0
            while counter > 0:
                myjitdriver.can_enter_jit(counter=counter, i=i)
                myjitdriver.jit_merge_point(counter=counter, i=i)
                foo = externfn(i)
                res = foo.meth(i)
                counter -= 1
            return res
        res = self.meta_interp(f, [1], policy=StopAtXPolicy(externfn),
                               backendopt=True)
        assert res == 43
        self.check_resops({'int_gt': 2, 'getfield_gc_i': 2,
                           'guard_true': 2, 'int_sub': 2, 'jump': 1,
                           'call_r': 2, 'guard_no_exception': 2,
                           'int_add': 2})

    def test_red_send_to_green_receiver(self):
        myjitdriver = JitDriver(greens = ['i'], reds = ['counter', 'j'])
        class Foo(object):
            def meth(self, i):
                return 42 + i
        class Foobar(Foo):
            def meth(self, i):
                return 146 + i
        lst = [Foo(), Foo(), Foobar(), Foo(), Foobar(), Foo()]
        def f(i, j):
            counter = 20
            res = 0
            while counter > 0:
                myjitdriver.can_enter_jit(counter=counter, i=i, j=j)
                myjitdriver.jit_merge_point(counter=counter, i=i, j=j)
                foo = lst[i]
                res = foo.meth(j)
                counter -= 1
            return res
        res = self.meta_interp(f, [4, -1])
        assert res == 145
        self.check_resops(int_add=1)

    def test_oosend_base(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'w'])
        class Base:
            pass
        class W1(Base):
            def __init__(self, x):
                self.x = x
            def incr(self):
                return W1(self.x + 1)
            def getvalue(self):
                return self.x
        class W2(Base):
            def __init__(self, y):
                self.y = y
            def incr(self):
                return W2(self.y + 100)
            def getvalue(self):
                return self.y
        def f(x, y):
            if x & 1:
                w = W1(x)
            else:
                w = W2(x)
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, w=w)
                myjitdriver.jit_merge_point(x=x, y=y, w=w)
                w = w.incr()
                y -= 1
            return w.getvalue()
        res = self.meta_interp(f, [3, 14])
        assert res == 17
        res = self.meta_interp(f, [4, 14])
        assert res == 1404
        self.check_resops(guard_class=1, new=0, new_with_vtable=0)

    def test_three_receivers(self):
        myjitdriver = JitDriver(greens = [], reds = ['y'])
        class Base:
            pass
        class W1(Base):
            def foo(self):
                return 1
        class W2(Base):
            def foo(self):
                return 2
        class W3(Base):
            def foo(self):
                return 3
        def externfn(y):
            lst = [W1, W1, W2, W2, W3, W3, W2, W1, W3]
            W = lst[y % len(lst)]
            return W()
        def f(y):
            while y > 0:
                myjitdriver.can_enter_jit(y=y)
                myjitdriver.jit_merge_point(y=y)
                w = externfn(y)
                w.foo()
                y -= 1
            return 42
        policy = StopAtXPolicy(externfn)

        for j in range(69, 75):
            res = self.meta_interp(f, [j], policy=policy)
            assert res == 42
            self.check_enter_count_at_most(5)
            self.check_trace_count_at_most(5)

    def test_oosend_guard_failure(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'w'])
        class Base:
            pass
        class W1(Base):
            def __init__(self, x):
                self.x = x
            def incr(self):
                return W2(self.x + 1)
            def getvalue(self):
                return self.x
        class W2(Base):
            def __init__(self, y):
                self.y = y
            def incr(self):
                return W1(self.y + 100)
            def getvalue(self):
                return self.y
        def f(x, y):
            set_param(myjitdriver, 'max_unroll_loops', 5)
            if x & 1:
                w = W1(x)
            else:
                w = W2(x)
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, w=w)
                myjitdriver.jit_merge_point(x=x, y=y, w=w)
                w = w.incr()
                y -= 1
            return w.getvalue()
        res = self.meta_interp(f, [3, 28])
        assert res == f(3, 28)
        res = self.meta_interp(f, [4, 28])
        assert res == f(4, 28)
        # This checks that the loop was originally aborted due to an
        # InvalidLoop condition, and was then unrolled, giving two copies
        # of the body in a single bigger loop with no failing guard except
        # the final one.
        self.check_trace_count(1)
        self.check_resops(guard_class=1, int_add=4, int_sub=4)
        #self.check_jumps(14)

    def test_oosend_guard_failure_2(self):
        # same as above, but using prebuilt objects 'w1' and 'w2'
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'w'])
        class Base:
            pass
        class W1(Base):
            def __init__(self, x):
                self.x = x
            def incr(self):
                return W2(self.x + 1)
            def getvalue(self):
                return self.x
        class W2(Base):
            def __init__(self, y):
                self.y = y
            def incr(self):
                return W1(self.y + 100)
            def getvalue(self):
                return self.y
        w1 = W1(10)
        w2 = W2(20)

        def f(x, y):
            set_param(myjitdriver, 'max_unroll_loops', 5)
            if x & 1:
                w = w1
            else:
                w = w2
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, w=w)
                myjitdriver.jit_merge_point(x=x, y=y, w=w)
                w = w.incr()
                y -= 1
            return w.getvalue()
        res = self.meta_interp(f, [3, 28])
        assert res == f(3, 28)
        res = self.meta_interp(f, [4, 28])
        assert res == f(4, 28)
        self.check_trace_count(1)
        self.check_resops(guard_class=1, int_add=4, int_sub=4)
        #self.check_jumps(14)

    def test_oosend_different_initial_class(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'w'])
        class Base:
            pass
        class W1(Base):
            def __init__(self, x):
                self.x = x
            def incr(self):
                return W2(self.x + 1)
            def getvalue(self):
                return self.x
        class W2(Base):
            def __init__(self, y):
                self.y = y
            def incr(self):
                return W2(self.y * 2)
            def getvalue(self):
                return self.y
        def f(x, y):
            w = W1(x)
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, w=w)
                myjitdriver.jit_merge_point(x=x, y=y, w=w)
                w = w.incr()
                y -= 1
            return w.getvalue()
        res = self.meta_interp(f, [3, 28])
        assert res == f(3, 28)
        # The effect of the ClassGuard generated by the oosend to incr()
        # should be to unroll the first iteration of the loop.  Indeed,
        # looking only at the loop, we deduce that the class of 'w' is 'W2'.
        # However, this doesn't match the initial value of 'w'.
        # XXX This not completely easy to check...
        self.check_trace_count(1)
        self.check_resops(guard_class=1, new_with_vtable=0, int_lshift=2,
                          int_add=0, new=0)

    def test_indirect_call_unknown_object_1(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y'])
        def getvalue2():
            return 2
        def getvalue25():
            return 25
        def getvalue1001():
            return -1001
        def externfn(n):
            if n % 5:
                return getvalue2
            elif n % 7:
                return getvalue25
            else:
                return getvalue1001
        def f(y):
            x = 0
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y)
                myjitdriver.jit_merge_point(x=x, y=y)
                x += externfn(y)()
                y -= 1
            return x
        res = self.meta_interp(f, [198], policy=StopAtXPolicy(externfn))
        assert res == f(198)
        self.check_trace_count(4)

    def test_indirect_call_unknown_object_2(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'state'])
        def getvalue2():
            return 2
        def getvalue25():
            return 25
        def getvalue1001():
            return -1001

        class State:
            count = 0
            def externfn(self, n):
                assert n == 198 - self.count
                self.count += 1
                if n % 5:
                    return getvalue2
                elif n % 7:
                    return getvalue25
                else:
                    return getvalue1001
        def f(y):
            state = State()
            x = 0
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, state=state)
                myjitdriver.jit_merge_point(x=x, y=y, state=state)
                x += state.externfn(y)()
                y -= 1
            return x
        res = self.meta_interp(f, [198],
                               policy=StopAtXPolicy(State.externfn.im_func))
        assert res == f(198)
        # we get two TargetTokens, one for the loop and one for the preamble
        self.check_jitcell_token_count(1)
        self.check_target_token_count(2)

    def test_indirect_call_unknown_object_3(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'z', 'state'])
        def getvalue2():
            return 2
        def getvalue25():
            return 25
        def getvalue1001():
            return -1001

        class State:
            count = 0
            def externfn(self, n):
                assert n == 198 - self.count
                self.count += 1
                if n % 5:
                    return getvalue2
                elif n % 7:
                    return getvalue25
                else:
                    return getvalue1001
        def f(y):
            state = State()
            x = z = 0
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, z=z, state=state)
                myjitdriver.jit_merge_point(x=x, y=y, z=z, state=state)
                x += z
                z = state.externfn(y)()
                y -= 1
            return x
        res = self.meta_interp(f, [198],
                               policy=StopAtXPolicy(State.externfn.im_func))
        assert res == f(198)
        # we get four TargetTokens: one for each of the 3 getvalue functions,
        # and one entering from the interpreter (the preamble)
        self.check_jitcell_token_count(1)
        self.check_target_token_count(4)

    def test_two_behaviors(self):
        myjitdriver = JitDriver(greens = [], reds = ['y', 'x'])
        class Int:
            def __init__(self, value):
                self.value = value
        cases = [True]*100 + [False, True]*10 + [False]*20
        def f(y):
            x = Int(0)
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y)
                myjitdriver.jit_merge_point(x=x, y=y)
                y -= 1
                if cases[y]:
                    x = Int(x.value + 1)
            return x.value
        res = self.meta_interp(f, [len(cases)])
        assert res == 110

    def test_behavior_change_after_a_while(self):
        myjitdriver = JitDriver(greens = [], reds = ['y', 'x'])
        class Base:
            def __init__(self, value):
                self.value = value
        class Int1(Base):
            pass
        class Int2(Base):
            pass
        cases = [False, True, True, True, True]*40
        def f(y):
            x = Int1(0)
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y)
                myjitdriver.jit_merge_point(x=x, y=y)
                y -= 1
                value = x.value + 1
                if cases[y]:
                    x = Int1(value)
                else:
                    x = Int2(value)
            return x.value
        res = self.meta_interp(f, [len(cases)])
        assert res == 200
        # we expect 2 versions of the loop, 1 entry bridge,
        # and 1 bridge going from the
        # loop back to the loop
        self.check_trace_count(2)        # preamble/loop  and  1 bridge
        self.check_jitcell_token_count(1)
        self.check_target_token_count(3) # preamble, Int1, Int2
        self.check_aborted_count(0)

    def test_three_cases(self):
        class Node:
            def __init__(self, x):
                self.x = x
        myjitdriver = JitDriver(greens = [], reds = ['node'])
        def f(n):
            node = Node(n)
            while node.x > 0:
                myjitdriver.can_enter_jit(node=node)
                myjitdriver.jit_merge_point(node=node)
                if node.x < 40:
                    if node.x < 20:
                        node = Node(node.x - 1)
                    node = Node(node.x - 1)
                node = Node(node.x - 1)
            return node.x
        res = self.meta_interp(f, [55])
        assert res == f(55)
        self.check_trace_count(3)

    def test_three_classes(self):
        class Base:
            pass
        class A(Base):
            def f(self):
                return 1
        class B(Base):
            def f(self):
                return 2
        class C(Base):
            def f(self):
                return 3
        myjitdriver = JitDriver(greens = [], reds = ['n'])
        def extern(n):
            if n > 40:
                return A()
            elif n > 20:
                return B()
            else:
                return C()
        def f(n):
            while n > 0:
                myjitdriver.can_enter_jit(n=n)
                myjitdriver.jit_merge_point(n=n)
                n -= extern(n).f()
            return n
        res = self.meta_interp(f, [55], policy=StopAtXPolicy(extern))
        assert res == f(55)
        self.check_jitcell_token_count(1)

    def test_bug1(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'node'])
        class Base:
            pass
        class A(Base):
            def decr(self, n):
                return n - 2
        class B(Base):
            def __init__(self, n):
                self.n = n
            def decr(self, n):
                assert n == self.n
                return self.n - 1
        def extern(n):
            if n <= 21:
                return B(n)
            else:
                return A()
        def f(n):
            node = A()
            while n >= 0:
                myjitdriver.can_enter_jit(node=node, n=n)
                myjitdriver.jit_merge_point(node=node, n=n)
                n = node.decr(n)
                node = extern(n)
            return n
        res = self.meta_interp(f, [60], policy=StopAtXPolicy(extern))
        assert res == f(60)

    def test_recursive_call_to_portal_from_blackhole(self):
        from rpython.rtyper.annlowlevel import hlstr

        myjitdriver = JitDriver(greens = ['k'], reds = ['n'])
        def f(n, k):
            while n >= 0:
                myjitdriver.can_enter_jit(n=n, k=k)
                myjitdriver.jit_merge_point(n=n, k=k)
                if n == 3 and k == 0:
                    return f(10, 1)
                n -= 1
            if k == 1:
                return "string"
            return "xyz"

        res = self.meta_interp(f, [20, 0])
        assert hlstr(res) == "string"

    def test_residual_oosend(self):
        myjitdriver = JitDriver(greens=[], reds = ['i', 'obj'])
        class A:
            def foo(self):
                return 41
        class B(A):
            def foo(self):
                return 42
        def new(n):
            if n:
                return A()
            else:
                return B()
        def fn(n, i):
            res = 0
            obj = new(n)
            while i > 0:
                myjitdriver.can_enter_jit(i=i, obj=obj)
                myjitdriver.jit_merge_point(i=i, obj=obj)
                res = obj.foo()
                i-=1
            return res

        policy = StopAtXPolicy(new, A.foo.im_func, B.foo.im_func)
        res = self.meta_interp(fn, [0, 20], policy=policy)
        assert res == 42
        self.check_resops(call_i=2)


    def test_residual_oosend_with_void(self):
        myjitdriver = JitDriver(greens=[], reds = ['i', 'obj'])
        class A:
            def foo(self, other):
                return 41
            def _freeze_(self):
                return True
        def new(n):
            if n:
                return A()
            else:
                return None
        pbc = A()
        def fn(n, i):
            res = 0
            obj = new(n)
            while i > 0:
                myjitdriver.can_enter_jit(i=i, obj=obj)
                myjitdriver.jit_merge_point(i=i, obj=obj)
                res = obj.foo(pbc)
                i-=1
            return res
        policy = StopAtXPolicy(new, A.foo.im_func)
        res = self.meta_interp(fn, [1, 20], policy=policy)
        assert res == 41
        self.check_resops(call_i=2)

    def test_constfold_pure_oosend(self):
        myjitdriver = JitDriver(greens=[], reds = ['i', 'obj'])
        class A:
            @elidable
            def foo(self):
                return 42
        def fn(n, i):
            res = 0
            obj = A()
            while i > 0:
                myjitdriver.can_enter_jit(i=i, obj=obj)
                myjitdriver.jit_merge_point(i=i, obj=obj)
                promote(obj)
                res = obj.foo()
                i-=1
            return res
        policy = StopAtXPolicy(A.foo.im_func)
        res = self.meta_interp(fn, [1, 20], policy=policy)
        assert res == 42
        self.check_resops(call=0)

    def test_generalize_loop(self):
        myjitdriver = JitDriver(greens=[], reds = ['i', 'obj'])
        class A:
            def __init__(self, n):
                self.n = n
        def extern(obj):
            pass
        def fn(i):
            obj = A(1)
            while i > 0:
                myjitdriver.can_enter_jit(i=i, obj=obj)
                myjitdriver.jit_merge_point(i=i, obj=obj)
                obj = A(obj.n + 1)
                if i < 10:
                    extern(obj)
                i -= 1
            return obj.n
        res = self.meta_interp(fn, [20], policy=StopAtXPolicy(extern))
        assert res == 21

class TestLLtype(SendTests, LLJitMixin):
    pass
