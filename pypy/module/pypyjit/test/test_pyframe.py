import py


class TestJitTraceInteraction(object):

    def test_trace_while_blackholing(self):
        import sys
        l = []
        printed = []
        def trace(frame, event, arg):
            l.append((frame.f_code.co_name, event))
            return trace
        def g(i, x):
            if i > x - 10:
                printed.append(i)
            if i == x - 5:
                sys.settrace(trace)

        def f(x):
            res = 0
            for i in range(x):
                res += i
                g(i, x)

        f(10)
        sys.settrace(None)
        print printed
        assert l == [('g', 'call'), ('g', 'line'), ('g', 'line'), ('g', 'line'), ('g', 'return')] * 4
        l1 = l
        l = []
        printed = []
        f(10000)
        sys.settrace(None)
        print printed

        assert l == l1
