import py
from rpython.rlib.jit import JitDriver, hint, set_param, dont_look_inside,\
     elidable, promote
from rpython.rlib.objectmodel import compute_hash
from rpython.jit.metainterp.warmspot import ll_meta_interp, get_stats
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.codewriter.policy import StopAtXPolicy
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.metainterp import history

class LoopTest(object):
    enable_opts = ''

    automatic_promotion_result = {
        'int_add' : 6, 'int_gt' : 1, 'guard_false' : 1, 'jump' : 1,
        'guard_value' : 3
    }

    def meta_interp(self, f, args, policy=None, backendopt=False):
        return ll_meta_interp(f, args, enable_opts=self.enable_opts,
                              policy=policy,
                              CPUClass=self.CPUClass,
                              backendopt=backendopt)

    def run_directly(self, f, args):
        return f(*args)

    def test_simple_loop(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'res'])
        def f(x, y):
            res = 0
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, res=res)
                myjitdriver.jit_merge_point(x=x, y=y, res=res)
                res += x
                y -= 1
            return res * 2
        res = self.meta_interp(f, [6, 7])
        assert res == 84
        self.check_trace_count(1)

    def test_loop_with_delayed_setfield(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'res', 'a'])
        class A(object):
            def __init__(self):
                self.x = 3

        def f(x, y):
            res = 0
            a = A()
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, res=res, a=a)
                myjitdriver.jit_merge_point(x=x, y=y, res=res, a=a)
                a.x = y
                if y < 3:
                    return a.x
                res += a.x
                y -= 1
            return res * 2
        res = self.meta_interp(f, [6, 13])
        assert res == f(6, 13)
        self.check_trace_count(1)
        if self.enable_opts:
            self.check_resops(setfield_gc=2, getfield_gc_i=0)


    def test_loop_with_two_paths(self):
        from rpython.rtyper.lltypesystem import lltype
        from rpython.rtyper.lltypesystem.lloperation import llop
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'res'])

        def l(y, x, t):
            llop.debug_print(lltype.Void, y, x, t)

        def g(y, x, r):
            if y <= 12:
                res = x - 2
            else:
                res = x
            l(y, x, r)
            return res

        def f(x, y):
            res = 0
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, res=res)
                myjitdriver.jit_merge_point(x=x, y=y, res=res)
                res += g(y, x, res)
                y -= 1
            return res * 2
        res = self.meta_interp(f, [6, 33], policy=StopAtXPolicy(l))
        assert res == f(6, 33)
        if self.enable_opts:
            self.check_trace_count(2)
        else:
            self.check_trace_count(2)

    def test_alternating_loops(self):
        myjitdriver = JitDriver(greens = [], reds = ['pattern'])
        def f(pattern):
            while pattern > 0:
                myjitdriver.can_enter_jit(pattern=pattern)
                myjitdriver.jit_merge_point(pattern=pattern)
                if pattern & 1:
                    pass
                else:
                    pass
                pattern >>= 1
            return 42
        self.meta_interp(f, [0xF0F0F0])
        if self.enable_opts:
            self.check_trace_count(3)
        else:
            self.check_trace_count(2)

    def test_interp_simple(self):
        myjitdriver = JitDriver(greens = ['i'], reds = ['x', 'y'])
        bytecode = "bedca"
        def f(x, y):
            i = 0
            while i < len(bytecode):
                myjitdriver.can_enter_jit(i=i, x=x, y=y)
                myjitdriver.jit_merge_point(i=i, x=x, y=y)
                op = bytecode[i]
                if op == 'a':
                    x += 3
                elif op == 'b':
                    x += 1
                elif op == 'c':
                    x -= y
                elif op == 'd':
                    y += y
                else:
                    y += 1
                i += 1
            return x
        res = self.meta_interp(f, [100, 30])
        assert res == 42
        self.check_trace_count(0)

    def test_green_prevents_loop(self):
        myjitdriver = JitDriver(greens = ['i'], reds = ['x', 'y'])
        bytecode = "+--+++++----"
        def f(x, y):
            i = 0
            while i < len(bytecode):
                myjitdriver.can_enter_jit(i=i, x=x, y=y)
                myjitdriver.jit_merge_point(i=i, x=x, y=y)
                op = bytecode[i]
                if op == '+':
                    x += y
                else:
                    y += 1
                i += 1
            return x
        res = self.meta_interp(f, [100, 5])
        assert res == f(100, 5)
        self.check_trace_count(0)

    def test_interp_single_loop(self):
        myjitdriver = JitDriver(greens = ['i'], reds = ['x', 'y'])
        bytecode = "abcd"
        def f(x, y):
            i = 0
            while i < len(bytecode):
                myjitdriver.jit_merge_point(i=i, x=x, y=y)
                op = bytecode[i]
                if op == 'a':
                    x += y
                elif op == 'b':
                    y -= 1
                elif op == 'c':
                    if y:
                        i = 0
                        myjitdriver.can_enter_jit(i=i, x=x, y=y)
                        continue
                else:
                    x += 1
                i += 1
            return x
        res = self.meta_interp(f, [5, 8])
        assert res == 42
        self.check_trace_count(1)
        # the 'int_eq' and following 'guard' should be constant-folded
        if 'unroll' in self.enable_opts:
            self.check_resops(int_eq=0, guard_true=2, guard_false=0)
        else:
            self.check_resops(int_eq=0, guard_true=1, guard_false=0)
        if self.basic:
            found = 0
            for op in get_stats().loops[0]._all_operations():
                if op.getopname() == 'guard_true':
                    liveboxes = op.getfailargs()
                    assert len(liveboxes) == 2     # x, y (in some order)
                    assert liveboxes[0].type == 'i'
                    assert liveboxes[1].type == 'i'
                    found += 1
            if 'unroll' in self.enable_opts:
                assert found == 2
            else:
                assert found == 1

    def test_interp_many_paths(self):
        myjitdriver = JitDriver(greens = ['i'], reds = ['x', 'node'])
        NODE = self._get_NODE()
        bytecode = "xxxxxxxb"
        def f(node):
            x = 0
            i = 0
            while i < len(bytecode):
                myjitdriver.jit_merge_point(i=i, x=x, node=node)
                op = bytecode[i]
                if op == 'x':
                    if not node:
                        break
                    if node.value < 100:   # a pseudo-random choice
                        x += 1
                    node = node.next
                elif op == 'b':
                    i = 0
                    myjitdriver.can_enter_jit(i=i, x=x, node=node)
                    continue
                i += 1
            return x

        node1 = self.nullptr(NODE)
        for i in range(300):
            prevnode = self.malloc(NODE)
            prevnode.value = pow(47, i, 199)
            prevnode.next = node1
            node1 = prevnode

        expected = f(node1)
        res = self.meta_interp(f, [node1])
        assert res == expected
        self.check_trace_count_at_most(19)

    def test_interp_many_paths_2(self):
        import sys
        oldlimit = sys.getrecursionlimit()
        try:
            sys.setrecursionlimit(10000)
            myjitdriver = JitDriver(greens = ['i'], reds = ['x', 'node'])
            NODE = self._get_NODE()
            bytecode = "xxxxxxxb"

            def can_enter_jit(i, x, node):
                myjitdriver.can_enter_jit(i=i, x=x, node=node)

            def f(node):
                x = 0
                i = 0
                while i < len(bytecode):
                    myjitdriver.jit_merge_point(i=i, x=x, node=node)
                    op = bytecode[i]
                    if op == 'x':
                        if not node:
                            break
                        if node.value < 100:   # a pseudo-random choice
                            x += 1
                        node = node.next
                    elif op == 'b':
                        i = 0
                        can_enter_jit(i, x, node)
                        continue
                    i += 1
                return x

            node1 = self.nullptr(NODE)
            for i in range(300):
                prevnode = self.malloc(NODE)
                prevnode.value = pow(47, i, 199)
                prevnode.next = node1
                node1 = prevnode

            expected = f(node1)
            res = self.meta_interp(f, [node1])
            assert res == expected
            self.check_trace_count_at_most(19)
        finally:
            sys.setrecursionlimit(oldlimit)

    def test_nested_loops(self):
        myjitdriver = JitDriver(greens = ['i'], reds = ['x', 'y'])
        bytecode = "abc<de"
        def f(x, y):
            i = 0
            op = '-'
            while True:
                myjitdriver.jit_merge_point(i=i, x=x, y=y)
                op = bytecode[i]
                if op == 'a':
                    x += 1
                elif op == 'b':
                    x += y
                elif op == 'c':
                    y -= 1
                elif op == '<':
                    if y:
                        i -= 2
                        myjitdriver.can_enter_jit(i=i, x=x, y=y)
                        continue
                elif op == 'd':
                    y = x
                elif op == 'e':
                    if x > 1000:
                        break
                    else:
                        i = 0
                        myjitdriver.can_enter_jit(i=i, x=x, y=y)
                        continue
                i += 1
            return x

        expected = f(2, 3)
        res = self.meta_interp(f, [2, 3])
        assert res == expected

    def test_loop_in_bridge1(self):
        myjitdriver = JitDriver(greens = ['i'], reds = ['x', 'y', 'res'])
        bytecode = "abs>cxXyY"
        def f(y):
            res = x = 0
            i = 0
            op = '-'
            while i < len(bytecode):
                myjitdriver.jit_merge_point(i=i, x=x, y=y, res=res)
                op = bytecode[i]
                if op == 'a':
                    res += 1
                elif op == 'b':
                    res += 10
                elif op == 'c':
                    res += 10000
                elif op == 's':
                    x = y
                elif op == 'y':
                    y -= 1
                elif op == 'Y':
                    if y:
                        i = 1
                        myjitdriver.can_enter_jit(i=i, x=x, y=y, res=res)
                        continue
                elif op == 'x':
                    x -= 1
                elif op == 'X':
                    if x > 0:
                        i -= 2
                        myjitdriver.can_enter_jit(i=i, x=x, y=y, res=res)
                        continue
                elif op == '>':
                    if y > 6:
                        i += 4
                        continue
                i += 1
            return res

        expected = f(12)
        res = self.meta_interp(f, [12])
        print res
        assert res == expected

    def test_nested_loops_discovered_by_bridge(self):
        # This is an bytecode implementation of the loop below. With
        # threshold=3 the first trace produced will start with a failing
        # test j <= i from the inner loop followed by one iteration of the
        # outer loop followed by one iteration of the inner loop. A bridge
        # is then created by tracing the inner loop again.
        #
        #   i = j = x = 0
        #   while i < n:
        #       j = 0
        #       while j <= i:
        #           j = j + 1
        #           x = x + (i&j)
        #       i = i + 1

        myjitdriver = JitDriver(greens = ['pos'], reds = ['i', 'j', 'n', 'x'])
        bytecode = "IzJxji"
        def f(n, threshold):
            set_param(myjitdriver, 'threshold', threshold)
            i = j = x = 0
            pos = 0
            op = '-'
            while pos < len(bytecode):
                myjitdriver.jit_merge_point(pos=pos, i=i, j=j, n=n, x=x)
                op = bytecode[pos]
                if op == 'z':
                    j = 0
                elif op == 'i':
                    i += 1
                    pos = 0
                    myjitdriver.can_enter_jit(pos=pos, i=i, j=j, n=n, x=x)
                    continue
                elif op == 'j':
                    j += 1
                    pos = 2
                    myjitdriver.can_enter_jit(pos=pos, i=i, j=j, n=n, x=x)
                    continue
                elif op == 'I':
                    if not (i < n):
                        pos = 5
                elif op == 'J':
                    if not (j <= i):
                        pos = 4
                elif op == 'x':
                    x = x + (i&j)

                pos += 1

            return x

        for th in (3, 1, 2, 4, 5): # Start with the interesting case
            expected = f(25, th)
            res = self.meta_interp(f, [25, th])
            assert res == expected

    def test_nested_loops_discovered_by_bridge_virtual(self):
        # Same loop as above, but with virtuals
        class A:
            def __init__(self, val):
                self.val = val
            def add(self, val):
                return A(self.val + val)
        myjitdriver = JitDriver(greens = ['pos'], reds = ['i', 'j', 'n', 'x'])
        bytecode = "IzJxji"
        def f(nval, threshold):
            set_param(myjitdriver, 'threshold', threshold)
            i, j, x = A(0), A(0), A(0)
            n = A(nval)
            pos = 0
            op = '-'
            while pos < len(bytecode):
                myjitdriver.jit_merge_point(pos=pos, i=i, j=j, n=n, x=x)
                op = bytecode[pos]
                if op == 'z':
                    j = A(0)
                elif op == 'i':
                    i = i.add(1)
                    pos = 0
                    myjitdriver.can_enter_jit(pos=pos, i=i, j=j, n=n, x=x)
                    continue
                elif op == 'j':
                    j = j.add(1)
                    pos = 2
                    myjitdriver.can_enter_jit(pos=pos, i=i, j=j, n=n, x=x)
                    continue
                elif op == 'I':
                    if not (i.val < n.val):
                        pos = 5
                elif op == 'J':
                    if not (j.val <= i.val):
                        pos = 4
                elif op == 'x':
                    x = x.add(i.val & j.val)

                pos += 1

            return x.val

        for th in (5, 3, 1, 2, 4): # Start with the interesting case
            expected = f(25, th)
            res = self.meta_interp(f, [25, th])
            assert res == expected

    def test_two_bridged_loops(self):
        myjitdriver = JitDriver(greens = ['pos'], reds = ['i', 'n', 's', 'x'])
        bytecode = "zI7izI8i"
        def f(n, s):
            i = x = 0
            pos = 0
            op = '-'
            while pos < len(bytecode):
                myjitdriver.jit_merge_point(pos=pos, i=i, n=n, s=s, x=x)
                op = bytecode[pos]
                if op == 'z':
                    i = 0
                if op == 'i':
                    i += 1
                    pos -= 2
                    myjitdriver.can_enter_jit(pos=pos, i=i, n=n, s=s, x=x)
                    continue
                elif op == 'I':
                    if not (i < n):
                        pos += 2
                elif op == '7':
                    if s==1:
                        x = x + 7
                    else:
                        x = x + 2
                elif op == '8':
                    if s==1:
                        x = x + 8
                    else:
                        x = x + 3

                pos += 1
            return x

        def g(n, s):
            sa = 0
            for i in range(7):
                sa += f(n, s)
            return sa
        assert self.meta_interp(g, [25, 1]) == g(25, 1)

        def h(n):
            return g(n, 1) + g(n, 2)
        assert self.meta_interp(h, [25]) == h(25)


    def test_two_bridged_loops_classes(self):
        myjitdriver = JitDriver(greens = ['pos'], reds = ['i', 'n', 'x', 's'])
        class A(object):
            pass
        bytecode = "I7i"
        def f(n, s):
            i = x = 0
            pos = 0
            op = '-'
            while pos < len(bytecode):
                myjitdriver.jit_merge_point(pos=pos, i=i, n=n, s=s, x=x)
                op = bytecode[pos]
                if op == 'i':
                    i += 1
                    pos -= 2
                    myjitdriver.can_enter_jit(pos=pos, i=i, n=n, s=s, x=x)
                    continue
                elif op == 'I':
                    if not (i < n):
                        pos += 2
                elif op == '7':
                    if s is not None:
                        x = x + 7
                    else:
                        x = x + 2
                pos += 1
            return x

        def g(n, s):
            if s == 2:
                s = None
            else:
                s = A()
            sa = 0
            for i in range(7):
                sa += f(n, s)
            return sa
        #assert self.meta_interp(g, [25, 1]) == g(25, 1)

        def h(n):
            return g(n, 1) + g(n, 2)
        assert self.meta_interp(h, [25]) == h(25)


    def test_three_nested_loops(self):
        myjitdriver = JitDriver(greens = ['i'], reds = ['x'])
        bytecode = ".+357"
        def f(x):
            assert x >= 0
            i = 0
            while i < len(bytecode):
                myjitdriver.jit_merge_point(i=i, x=x)
                op = bytecode[i]
                if op == '+':
                    x += 1
                elif op == '.':
                    pass
                elif op == '3':
                    if x % 3 != 0:
                        i -= 1
                        myjitdriver.can_enter_jit(i=i, x=x)
                        continue
                elif op == '5':
                    if x % 5 != 0:
                        i -= 2
                        myjitdriver.can_enter_jit(i=i, x=x)
                        continue
                elif op == '7':
                    if x % 7 != 0:
                        i -= 4
                        myjitdriver.can_enter_jit(i=i, x=x)
                        continue
                i += 1
            return x

        expected = f(0)
        assert expected == 3*5*7
        res = self.meta_interp(f, [0])
        assert res == expected

    def test_unused_loop_constant(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'z'])
        def f(x, y, z):
            while z > 0:
                myjitdriver.can_enter_jit(x=x, y=y, z=z)
                myjitdriver.jit_merge_point(x=x, y=y, z=z)
                x += z
                z -= 1
            return x * y
        expected = f(2, 6, 30)
        res = self.meta_interp(f, [2, 6, 30])
        assert res == expected

    def test_loop_unicode(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'x'])
        def f(n):
            x = u''
            while n > 13:
                myjitdriver.can_enter_jit(n=n, x=x)
                myjitdriver.jit_merge_point(n=n, x=x)
                x += unichr(n)
                n -= 1
            return compute_hash(x)
        expected = self.run_directly(f, [100])
        res = self.meta_interp(f, [100])
        assert res == expected

    def test_loop_string(self):
        myjitdriver = JitDriver(greens = [], reds = ['n', 'x'])
        def f(n):
            x = ''
            while n > 13:
                myjitdriver.can_enter_jit(n=n, x=x)
                myjitdriver.jit_merge_point(n=n, x=x)
                #print len(x), x
                x += chr(n)
                n -= 1
            return compute_hash(x)
        expected = self.run_directly(f, [100])
        res = self.meta_interp(f, [100])
        assert res == expected

    def test_adapt_bridge_to_merge_point(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'z'])

        class Z(object):
            def __init__(self, elem):
                self.elem = elem

        def externfn(z):
            pass

        def f(x, y):
            z = Z(y)
            while x > 0:
                myjitdriver.can_enter_jit(x=x, z=z)
                myjitdriver.jit_merge_point(x=x, z=z)
                if x % 5 != 0:
                    externfn(z)
                z = Z(z.elem + 1)
                x -= 1
            return z.elem

        expected = f(100, 5)
        res = self.meta_interp(f, [100, 5], policy=StopAtXPolicy(externfn))
        assert res == expected

        if self.enable_opts:
            self.check_trace_count(2)
            self.check_jitcell_token_count(1)   # 1 loop with bridge from interp
        else:
            self.check_trace_count(2)
            self.check_jitcell_token_count(1)   # 1 loop, callable from the interp

    def test_example(self):
        myjitdriver = JitDriver(greens = ['i'],
                                reds = ['res', 'a'])
        CO_INCREASE = 0
        CO_JUMP_BACK_3 = 1
        CO_DECREASE = 2

        code = [CO_INCREASE, CO_INCREASE, CO_INCREASE,
                CO_JUMP_BACK_3, CO_INCREASE, CO_DECREASE]

        def add(res, a):
            return res + a

        def sub(res, a):
            return res - a

        def main_interpreter_loop(a):
            i = 0
            res = 0
            c = len(code)
            while i < c:
                myjitdriver.jit_merge_point(res=res, i=i, a=a)
                elem = code[i]
                if elem == CO_INCREASE:
                    res = add(res, a)
                elif elem == CO_DECREASE:
                    res = sub(res, a)
                else:
                    if res > 100:
                        pass
                    else:
                        i = i - 3
                        myjitdriver.can_enter_jit(res=res, i=i, a=a)
                        continue
                i = i + 1
            return res

        res = self.meta_interp(main_interpreter_loop, [1])
        assert res == 102
        self.check_trace_count(1)
        if 'unroll' in self.enable_opts:
            self.check_resops({'int_add' : 6, 'int_gt' : 2,
                               'guard_false' : 2, 'jump' : 1})
        else:
            self.check_resops({'int_add' : 3, 'int_gt' : 1,
                               'guard_false' : 1, 'jump' : 1})

    def test_automatic_promotion(self):
        myjitdriver = JitDriver(greens = ['i'],
                                reds = ['res', 'a'])
        CO_INCREASE = 0
        CO_JUMP_BACK_3 = 1

        code = [CO_INCREASE, CO_INCREASE, CO_INCREASE,
                CO_JUMP_BACK_3, CO_INCREASE]

        def add(res, a):
            return res + a

        def sub(res, a):
            return res - a

        def main_interpreter_loop(a):
            i = 0
            res = 0
            c = len(code)
            while True:
                myjitdriver.jit_merge_point(res=res, i=i, a=a)
                if i >= c:
                    break
                elem = code[i]
                if elem == CO_INCREASE:
                    i += a
                    res += a
                else:
                    if res > 100:
                        i += 1
                    else:
                        i = i - 3
                        myjitdriver.can_enter_jit(res=res, i=i, a=a)
            return res

        res = self.meta_interp(main_interpreter_loop, [1])
        assert res == main_interpreter_loop(1)
        self.check_trace_count(1)
        # These loops do different numbers of ops based on which optimizer we
        # are testing with.
        self.check_resops(self.automatic_promotion_result)

    def test_can_enter_jit_outside_main_loop(self):
        myjitdriver = JitDriver(greens=[], reds=['i', 'j', 'a'])
        def done(a, j):
            myjitdriver.can_enter_jit(i=0, j=j, a=a)
        def main_interpreter_loop(a):
            i = j = 0
            while True:
                myjitdriver.jit_merge_point(i=i, j=j, a=a)
                i += 1
                j += 3
                if i >= 10:
                    a -= 1
                    if not a:
                        break
                    i = 0
                    done(a, j)
            return j
        assert main_interpreter_loop(5) == 5 * 10 * 3
        res = self.meta_interp(main_interpreter_loop, [5])
        assert res == 5 * 10 * 3

    def test_outer_and_inner_loop(self):
        jitdriver = JitDriver(greens = ['p', 'code'], reds = ['i', 'j',
                                                              'total'])

        class Code:
            def __init__(self, lst):
                self.lst = lst
        codes = [Code([]), Code([0, 0, 1, 1])]

        def interpret(num):
            code = codes[num]
            p = 0
            i = 0
            j = 0
            total = 0
            while p < len(code.lst):
                jitdriver.jit_merge_point(code=code, p=p, i=i, j=j, total=total)
                total += i
                e = code.lst[p]
                if e == 0:
                    p += 1
                elif e == 1:
                    if i < p * 20:
                        p = 3 - p
                        i += 1
                        jitdriver.can_enter_jit(code=code, p=p, j=j, i=i,
                                                total=total)
                    else:
                        j += 1
                        i = j
                        p += 1
            return total

        res = self.meta_interp(interpret, [1])
        assert res == interpret(1)
        # XXX it's unsure how many loops should be there
        self.check_trace_count(2)

    def test_path_with_operations_not_from_start(self):
        jitdriver = JitDriver(greens = ['k'], reds = ['n', 'z'])

        def f(n):
            k = 0
            z = 0
            while n > 0:
                jitdriver.can_enter_jit(n=n, k=k, z=z)
                jitdriver.jit_merge_point(n=n, k=k, z=z)
                k += 1
                if k == 30:
                    if z == 0 or z == 1:
                        k = 4
                        z += 1
                    else:
                        k = 15
                        z = 0
                n -= 1
            return 42

        res = self.meta_interp(f, [200])


    def test_path_with_operations_not_from_start_2(self):
        jitdriver = JitDriver(greens = ['k'], reds = ['n', 'z', 'stuff'])

        class Stuff(object):
            def __init__(self, n):
                self.n = n

        def some_fn(stuff, k, z):
            jitdriver.can_enter_jit(n=stuff.n, k=k, z=z, stuff=stuff)

        def f(n):
            k = 0
            z = 0
            stuff = Stuff(0)
            while n > 0:
                jitdriver.jit_merge_point(n=n, k=k, z=z, stuff=stuff)
                k += 1
                if k == 30:
                    if z == 0 or z == 1:
                        k = 4
                        z += 1
                    else:
                        k = 15
                        z = 0
                n -= 1
                some_fn(Stuff(n), k, z)
            return 0

        res = self.meta_interp(f, [200])

    def test_regular_pointers_in_short_preamble(self):
        from rpython.rtyper.lltypesystem import lltype
        BASE = lltype.GcStruct('BASE')
        A = lltype.GcStruct('A', ('parent', BASE), ('val', lltype.Signed))
        B = lltype.GcStruct('B', ('parent', BASE), ('charval', lltype.Char))
        myjitdriver = JitDriver(greens = [], reds = ['n', 'm', 'i', 'j', 'sa', 'p'])
        def f(n, m, j):
            i = sa = 0
            pa = lltype.malloc(A)
            pa.val = 7
            p = pa.parent
            while i < n:
                myjitdriver.jit_merge_point(n=n, m=m, i=i, j=j, sa=sa, p=p)
                if i < m:
                    pa = lltype.cast_pointer(lltype.Ptr(A), p)
                    sa += pa.val
                elif i == m:
                    pb = lltype.malloc(B)
                    pb.charval = 'y'
                    p = pb.parent
                else:
                    pb = lltype.cast_pointer(lltype.Ptr(B), p)
                    sa += ord(pb.charval)
                sa += 100
                assert n>0 and m>0
                i += j
            return sa
        # This is detected as invalid by the codewriter, for now
        py.test.raises(NotImplementedError, self.meta_interp, f, [20, 10, 1])

    def test_unerased_pointers_in_short_preamble(self):
        from rpython.rlib.rerased import new_erasing_pair
        from rpython.rtyper.lltypesystem import lltype
        class A(object):
            def __init__(self, val):
                self.val = val
        erase_A, unerase_A = new_erasing_pair('A')
        erase_TP, unerase_TP = new_erasing_pair('TP')
        TP = lltype.GcArray(lltype.Signed)
        myjitdriver = JitDriver(greens = [], reds = ['n', 'm', 'i', 'j', 'sa', 'p'])
        def f(n, m, j):
            i = sa = 0
            p = erase_A(A(7))
            while i < n:
                myjitdriver.jit_merge_point(n=n, m=m, i=i, j=j, sa=sa, p=p)
                if i < m:
                    sa += unerase_A(p).val
                elif i == m:
                    a = lltype.malloc(TP, 5)
                    a[0] = 42
                    p = erase_TP(a)
                else:
                    sa += unerase_TP(p)[0]
                sa += A(i).val
                assert n>0 and m>0
                i += j
            return sa
        res = self.meta_interp(f, [20, 10, 1])
        assert res == f(20, 10, 1)

    def test_boxed_unerased_pointers_in_short_preamble(self):
        from rpython.rlib.rerased import new_erasing_pair
        from rpython.rtyper.lltypesystem import lltype
        class A(object):
            def __init__(self, val):
                self.val = val
            def tst(self):
                return self.val

        class Box(object):
            def __init__(self, val):
                self.val = val

        erase_A, unerase_A = new_erasing_pair('A')
        erase_TP, unerase_TP = new_erasing_pair('TP')
        TP = lltype.GcArray(lltype.Signed)
        myjitdriver = JitDriver(greens = [], reds = ['n', 'm', 'i', 'sa', 'p'])
        def f(n, m):
            i = sa = 0
            p = Box(erase_A(A(7)))
            while i < n:
                myjitdriver.jit_merge_point(n=n, m=m, i=i, sa=sa, p=p)
                if i < m:
                    sa += unerase_A(p.val).tst()
                elif i == m:
                    a = lltype.malloc(TP, 5)
                    a[0] = 42
                    p = Box(erase_TP(a))
                else:
                    sa += unerase_TP(p.val)[0]
                sa -= A(i).val
                i += 1
            return sa
        res = self.meta_interp(f, [20, 10])
        assert res == f(20, 10)

    def test_unroll_issue_1(self):
        class A(object):
            _attrs_ = []
            def checkcls(self):
                raise NotImplementedError

        class B(A):
            def __init__(self, b_value):
                self.b_value = b_value
            def get_value(self):
                return self.b_value
            def checkcls(self):
                return self.b_value

        @dont_look_inside
        def check(a):
            return isinstance(a, B)

        jitdriver = JitDriver(greens=[], reds='auto')

        def f(a, xx):
            i = 0
            total = 0
            while i < 10:
                jitdriver.jit_merge_point()
                if check(a):
                    if xx & 1:
                        total *= a.checkcls()
                    total += a.get_value()
                i += 1
            return total

        def run(n):
            bt = f(B(n), 1)
            bt = f(B(n), 2)
            at = f(A(), 3)
            return at * 100000 + bt

        assert run(42) == 420
        res = self.meta_interp(run, [42], backendopt=True)
        assert res == 420

    def test_unroll_issue_2(self):
        py.test.skip("decide")

        class B(object):
            def __init__(self, b_value):
                self.b_value = b_value
        class C(object):
            pass

        from rpython.rlib.rerased import new_erasing_pair
        b_erase, b_unerase = new_erasing_pair("B")
        c_erase, c_unerase = new_erasing_pair("C")

        @elidable
        def unpack_b(a):
            return b_unerase(a)

        jitdriver = JitDriver(greens=[], reds='auto')

        def f(a, flag):
            i = 0
            total = 0
            while i < 10:
                jitdriver.jit_merge_point()
                if flag:
                    total += unpack_b(a).b_value
                    flag += 1
                i += 1
            return total

        def run(n):
            res = f(b_erase(B(n)), 1)
            f(c_erase(C()), 0)
            return res

        assert run(42) == 420
        res = self.meta_interp(run, [42], backendopt=True)
        assert res == 420

    def test_unroll_issue_3(self):
        py.test.skip("decide")

        from rpython.rlib.rerased import new_erasing_pair
        b_erase, b_unerase = new_erasing_pair("B")    # list of ints
        c_erase, c_unerase = new_erasing_pair("C")    # list of Nones

        @elidable
        def unpack_b(a):
            return b_unerase(a)

        jitdriver = JitDriver(greens=[], reds='auto')

        def f(a, flag):
            i = 0
            total = 0
            while i < 10:
                jitdriver.jit_merge_point()
                if flag:
                    total += unpack_b(a)[0]
                    flag += 1
                i += 1
            return total

        def run(n):
            res = f(b_erase([n]), 1)
            f(c_erase([None]), 0)
            return res

        assert run(42) == 420
        res = self.meta_interp(run, [42], backendopt=True)
        assert res == 420

    def test_not_too_many_bridges(self):
        jitdriver = JitDriver(greens = [], reds = 'auto')

        def f(i):
            s = 0
            while i > 0:
                jitdriver.jit_merge_point()
                if i % 2 == 0:
                    s += 1
                elif i % 3 == 0:
                    s += 1
                elif i % 5 == 0:
                    s += 1
                elif i % 7 == 0:
                    s += 1
                i -= 1
            return s

        self.meta_interp(f, [30])
        self.check_trace_count(3)

    def test_sharing_guards(self):
        py.test.skip("unimplemented")
        driver = JitDriver(greens = [], reds = 'auto')

        def f(i):
            s = 0
            while i > 0:
                driver.jit_merge_point()
                if s > 100:
                    raise Exception
                if s > 9:
                    s += 1 # bridge
                s += 1
                i -= 1

        self.meta_interp(f, [15])
        # one guard_false got removed
        self.check_resops(guard_false=4, guard_true=5)

    def test_heapcache_bug(self):
        class W_Object(object):
            _attrs_ = []
        class W_Nil(W_Object):
            _attrs_ = []
        class W_Cons(W_Object):
            _attrs_ = ['first', 'rest']
            _immutable_fields_ = ['first', 'rest']
            def __init__(self, v1, v2):
                self.first = v1
                self.rest = v2

        def reverse(xs):
            result = W_Nil()
            while isinstance(xs, W_Cons):
                result = W_Cons(xs.first, result)
                xs = xs.rest
            return result

        driver = JitDriver(reds=['repetitions', 'v'], greens=['pc'],
                       get_printable_location=lambda pc: str(pc))
        def entry_point():
            repetitions = 0
            while repetitions < 10:
                pc = 0
                v = W_Nil()
                while pc < 10:
                    driver.jit_merge_point(v=v, repetitions=repetitions, pc=pc)
                    v = reverse(W_Cons(pc + 1, W_Cons(pc + 2, W_Cons(pc + 3, W_Cons(pc + 4, W_Nil())))))
                    pc = pc + 1
                repetitions += 1
        
        self.meta_interp(entry_point, [])

    def test_unroll_shortpreamble_mutates_bug(self):
        class List:
            pass

        class Cell:
            pass

        class Base:
            pass
        class Int(Base):
            pass

        class WNone(Base):
            pass

        l1 = List()
        l1.strategy = 1
        l1.content1 = Int()
        l2 = List()
        l2.strategy = 2
        l2.content2 = WNone()
        l = [l1, l2] * 100

        c_int = Cell()
        c_int.value = Int()
        c_w_none = Cell()
        c_w_none.value = WNone()

        class Func:
            pass

        f1 = Func()
        f1.fval = 1
        f2 = Func()
        f2.fval = 2

        driver = JitDriver(reds=['i', 'c', 'l', 'func'], greens=['promoteint'])
        def f(l, func, c, promoteint):
            i = 0
            while i < len(l):
                subl = l[i]
                # reading from the inner list
                st = promote(subl.strategy)
                if st == 1:
                    lcontent = subl.content1
                else:
                    lcontent = subl.content2

                # LOAD_DEREF
                cellvalue = c.value
                assert cellvalue is not None

                # calling one of the two funcs
                # two variants:
                # - if we promote the int, then the erroneous bridge goes to
                #   the preamble
                # - if we don't the erroneous bridge goes to the main loop
                # both cases are wrong
                if promoteint:
                    x = promote(func.fval)
                else:
                    x = func.fval
                if x == 1:
                    promote(type(cellvalue) is type(lcontent))
                else:
                    promote(type(lcontent) is not WNone)
                i += 1
                driver.jit_merge_point(i=i, func=func, c=c, l=l, promoteint=promoteint)

        def main(promoteint):
            set_param(None, 'retrace_limit', 0)
            set_param(None, 'threshold', 8)
            List().content1 = WNone() # ensure annotator doesn't think the fields are constants
            Cell().value = None
            List().content2 = Int()
            f(l, f1, c_w_none, promoteint)
            print "=================================================================="
            f(l + [l1, l2], f2, c_int, promoteint)

        self.meta_interp(main, [True])
        self.check_trace_count_at_most(10)
        self.meta_interp(main, [False])
        self.check_trace_count_at_most(10)


class TestLLtype(LoopTest, LLJitMixin):
    pass
