import pytest
import sys

@pytest.fixture
def tempfile(tmpdir):
    return str(tmpdir / 'tempfile1')

def test_f_locals():
    import sys
    f = sys._getframe()
    assert f.f_locals is locals()

def test_f_globals():
    import sys
    f = sys._getframe()
    assert f.f_globals is globals()
    with pytest.raises(AttributeError):
        f.f_globals = globals()

def test_f_builtins():
    import sys, builtins
    f = sys._getframe()
    assert f.f_builtins is builtins.__dict__

def test_f_code():
    def g():
        import sys
        f = sys._getframe()
        return f.f_code
    assert g() is g.__code__

def test_f_trace_del():
    import sys
    f = sys._getframe()
    del f.f_trace
    assert f.f_trace is None

def test_f_lineno():
    def g():
        import sys
        f = sys._getframe()
        x = f.f_lineno
        y = f.f_lineno
        z = f.f_lineno
        return [x, y, z]
    origin = g.__code__.co_firstlineno
    assert g() == [origin+3, origin+4, origin+5]

def test_f_lineno_huge_jump():
    code = """def g():
        import sys
        f = sys._getframe()
        x = f.f_lineno
        %s
        y = f.f_lineno
        %s
        z = f.f_lineno
        return [x, y, z]""" % ("\n" * 127, "\n" * 1000)
    d = {}
    exec(code, d)
    g = d['g']
    origin = g.__code__.co_firstlineno
    print(repr(g.__code__.co_lnotab))
    assert g() == [origin+3, origin+5+127, origin+7+127+1000]

def test_bug_line_tracing():
    import sys
    def trace(frame, event, arg):
        lineno = frame.f_lineno - frame.f_code.co_firstlineno
        tr.append((event, lineno))
        return trace
    tr = []
    def no_pop_tops():      # 0
        x = 1               # 1
        for a in range(2):  # 2
            if a:           # 3
                x = 1       # 4
            else:           # 5
                x = 1       # 6
    sys.settrace(trace)
    no_pop_tops()
    sys.settrace(None)
    assert tr == [('call', 0), ('line', 1), ('line', 2), ('line', 3),
            ('line', 6), ('line', 2), ('line', 3), ('line', 4), ('line', 2),
            ('return', 2)]

class JumpTracer:
    """Defines a trace function that jumps from one place to another."""

    def __init__(self, function, jumpFrom, jumpTo, event='line',
                 decorated=False):
        self.code = function.__code__
        self.jumpFrom = jumpFrom
        self.jumpTo = jumpTo
        self.event = event
        self.firstLine = None if decorated else self.code.co_firstlineno
        self.done = False

    def trace(self, frame, event, arg):
        if self.done:
            return
        # frame.f_code.co_firstlineno is the first line of the decorator when
        # 'function' is decorated and the decorator may be written using
        # multiple physical lines when it is too long. Use the first line
        # trace event in 'function' to find the first line of 'function'.
        if (self.firstLine is None and frame.f_code == self.code and
                event == 'line'):
            self.firstLine = frame.f_lineno - 1
        if (event == self.event and self.firstLine and
                frame.f_lineno == self.firstLine + self.jumpFrom):
            frame.f_lineno = self.firstLine + self.jumpTo
            self.done = True
        return self.trace

def test_f_lineno_set(tempfile):
    def tracer(f, *args):
        def y(f, *args):
            return y
        def x(f, *args):
            f.f_lineno += 1
            return y  # "return None" should have the same effect, but see
                        # test_local_trace_function_returning_None_ignored
        return x

    # obscure: call open beforehand, py3k's open invokes some app
    # level code that confuses our tracing (likely due to the
    # testing env, otherwise it's not a problem)
    f = open(tempfile, 'w')
    def function(f=f):
        xyz
        with f as f:
            pass
        return 3

    import sys
    sys.settrace(tracer)
    function()
    sys.settrace(None)
    # assert did not crash

def test_f_lineno_set_2():
    counter = [0]
    errors = []

    def tracer(f, event, *args):
        if event == 'line':
            counter[0] += 1
            if counter[0] == 2:
                try:
                    f.f_lineno += 2
                except ValueError as e:
                    errors.append(e)
        return tracer

    def function():
        try:
            raise ValueError
        except ValueError:
            x = 42
        return x

    import sys
    sys.settrace(tracer)
    x = function()
    sys.settrace(None)
    assert x == 42
    assert len(errors) == 1
    assert str(errors[0]).startswith(
        "can't jump into an 'except' block as there's no exception")

def test_f_lineno_set_3():
    def jump_in_nested_finally(output):
        try:
            output.append(2)
        finally:
            output.append(4)
            try:
                output.append(6)
            finally:
                output.append(8)
            output.append(9)
    output = []
    tracer = JumpTracer(jump_in_nested_finally, 4, 9)

    import sys
    sys.settrace(tracer.trace)
    jump_in_nested_finally(output)
    sys.settrace(None)
    assert output == [2, 9]

def test_f_lineno_set_4():
    def jump_in_nested_finally(output):
        try:
            output.append(2)
            1/0
            return
        finally:
            output.append(6)
            output.append(7)
        output.append(8)
    output = []
    tracer = JumpTracer(jump_in_nested_finally, 6, 7)

    import sys
    sys.settrace(tracer.trace)
    try:
        jump_in_nested_finally(output)
    except ZeroDivisionError:
        sys.settrace(None)
    else:
        sys.settrace(None)
        assert False, 'did not raise'
    assert output == [2, 7]

def test_jump_forwards_out_of_with_block():
    class tracecontext:
        """Context manager that traces its enter and exit."""
        def __init__(self, output, value):
            self.output = output
            self.value = value

        def __enter__(self):
            self.output.append(self.value)

        def __exit__(self, *exc_info):
            self.output.append(-self.value)

    def jump_forwards_out_of_with_block(output):
        with tracecontext(output, 1):
            output.append(2)
        output.append(3)
    output = []
    tracer = JumpTracer(jump_forwards_out_of_with_block, 2, 3)
    sys.settrace(tracer.trace)
    jump_forwards_out_of_with_block(output)
    sys.settrace(None)
    assert output == [1, 3]

def test_jump_forwards_out_of_try_finally_block():
    def jump_forwards_out_of_try_finally_block(output):
        try:
            output.append(2)
        finally:
            output.append(4)
        output.append(5)
    output = []
    tracer = JumpTracer(jump_forwards_out_of_try_finally_block, 2, 5)
    sys.settrace(tracer.trace)
    jump_forwards_out_of_try_finally_block(output)
    sys.settrace(None)
    assert output == [5]

def test_f_lineno_set_firstline():
    seen = []
    def tracer(f, event, *args):
        if f.f_code.co_name == "decode":
            return tracer
        seen.append((event, f.f_lineno))
        if len(seen) == 5:
            f.f_lineno = 1       # bug shown only when setting lineno to 1
        return tracer

    def g():
        import sys
        source = "x=1\ny=x+1\nz=y+1\nt=z+1\ns=t+1\n"
        # compile first to ensure that no spurious events appear in the trace
        code = compile(source, '<string>', 'exec')
        sys.settrace(tracer)
        exec(code, {})
        sys.settrace(None)

    g()
    assert seen == [('call', 1),
                    ('line', 1),
                    ('line', 2),
                    ('line', 3),
                    ('line', 4),
                    ('line', 2),
                    ('line', 3),
                    ('line', 4),
                    ('line', 5),
                    ('return', 5)]

def test_f_back():
    import sys
    def f():
        assert sys._getframe().f_code.co_name == g()
    def g():
        return sys._getframe().f_back.f_code.co_name
    f()

def test_f_back_virtualref():
    import sys
    def f():
        return g()
    def g():
        return sys._getframe()
    frame = f()
    assert frame.f_back.f_code.co_name == 'f'

def test_virtualref_through_traceback():
    import sys
    def g():
        try:
            raise ValueError
        except:
            _, _, tb = sys.exc_info()
        return tb
    def f():
        return g()
    #
    tb = f()
    assert tb.tb_frame.f_code.co_name == 'g'
    assert tb.tb_frame.f_back.f_code.co_name == 'f'

def test_trace_basic():
    import sys
    l = []
    class Tracer:
        def __init__(self, i):
            self.i = i
        def trace(self, frame, event, arg):
            l.append((self.i, frame.f_code.co_name, event, arg))
            if frame.f_code.co_name == 'g2':
                return None    # don't trace g2
            return Tracer(self.i+1).trace
    def g3(n):
        n -= 5
        return n
    def g2(n):
        n += g3(2)
        n += g3(7)
        return n
    def g(n):
        n += g2(3)
        return n
    def f(n):
        n = g(n)
        return n * 7
    sys.settrace(Tracer(0).trace)
    x = f(4)
    sys.settrace(None)
    assert x == 42
    print(l)
    assert l == [(0, 'f', 'call', None),
                    (1, 'f', 'line', None),
                        (0, 'g', 'call', None),
                        (1, 'g', 'line', None),
                            (0, 'g2', 'call', None),
                                (0, 'g3', 'call', None),
                                (1, 'g3', 'line', None),
                                (2, 'g3', 'line', None),
                                (3, 'g3', 'return', -3),
                                (0, 'g3', 'call', None),
                                (1, 'g3', 'line', None),
                                (2, 'g3', 'line', None),
                                (3, 'g3', 'return', 2),
                        (2, 'g', 'line', None),
                        (3, 'g', 'return', 6),
                    (2, 'f', 'line', None),
                    (3, 'f', 'return', 42)]

def test_trace_exc():
    import sys
    l = []
    def ltrace(a,b,c):
        if b == 'exception':
            l.append(c)
        return ltrace
    def trace(a,b,c): return ltrace
    def f():
        try:
            raise Exception
        except:
            pass
    sys.settrace(trace)
    f()
    sys.settrace(None)
    assert len(l) == 1
    assert isinstance(l[0][1], Exception)

def test_trace_ignore_hidden():
    import sys
    try:
        import _testing
    except ImportError:
        skip('PyPy only test')
    _testing.Hidden  # avoid module lazy-loading weirdness when untranslated

    l = []
    def trace(a,b,c):
        l.append((a,b,c))

    def f():
        h = _testing.Hidden()
        r = h.meth()
        return r

    sys.settrace(trace)
    res = f()
    sys.settrace(None)
    assert len(l) == 1
    assert l[0][1] == 'call'
    assert res == 'hidden' # sanity

def test_trace_hidden_applevel_builtins():
    import sys

    l = []
    def trace(a,b,c):
        l.append((a,b,c))
        return trace

    def f():
        sum([])
        sum([])
        sum([])
        return "that's the return value"

    sys.settrace(trace)
    f()
    sys.settrace(None)
    # should get 1 "call", 3 "line" and 1 "return" events, and no call
    # or return for the internal app-level implementation of sum
    assert len(l) == 6
    assert [what for (frame, what, arg) in l] == [
        'call', 'line', 'line', 'line', 'line', 'return']
    assert l[-1][2] == "that's the return value"

def test_trace_return_exc():
    import sys
    l = []
    def trace(a,b,c):
        if b in ('exception', 'return'):
            l.append((b, c))
        return trace

    def g():
        raise Exception
    def f():
        try:
            g()
        except:
            pass
    sys.settrace(trace)
    f()
    sys.settrace(None)
    assert len(l) == 4
    assert l[0][0] == 'exception'
    assert isinstance(l[0][1][1], Exception)
    assert l[1] == ('return', None)
    assert l[2][0] == 'exception'
    assert isinstance(l[2][1][1], Exception)
    assert l[3] == ('return', None)

def test_trace_raises_on_return():
    import sys
    def trace(frame, event, arg):
        if event == 'return':
            raise ValueError
        else:
            return trace

    def f(): return 1

    for i in range(sys.getrecursionlimit() + 1):
        sys.settrace(trace)
        try:
            f()
        except ValueError:
            pass

def test_trace_try_finally():
    import sys
    l = []
    def trace(frame, event, arg):
        if event == 'exception':
            l.append(arg)
        return trace

    def g():
        try:
            raise Exception
        finally:
            pass

    def f():
        try:
            g()
        except:
            pass

    sys.settrace(trace)
    f()
    sys.settrace(None)
    assert len(l) == 2
    assert issubclass(l[0][0], Exception)
    assert issubclass(l[1][0], Exception)

def test_trace_generator_finalisation():
    import sys
    l = []
    got_exc = []
    def trace(frame, event, arg):
        l.append((frame.f_lineno, event))
        if event == 'exception':
            got_exc.append(arg)
        return trace

    d = {}
    exec("""if 1:
    def called_generator_with_finally(): # line 2
        try:
            yield True
        finally:
            pass

    def f(): # line 8
        try:
            gen = called_generator_with_finally()
            next(gen)
            gen.close()
        except:
            pass
    """, d)
    f = d['f']

    sys.settrace(trace)
    f()
    sys.settrace(None)
    assert len(got_exc) == 1
    assert issubclass(got_exc[0][0], GeneratorExit)
    assert l == [(8, 'call'),
                    (9, 'line'),
                    (10, 'line'),
                    (11, 'line'),
                    (2, 'call'),
                    (3, 'line'),
                    (4, 'line'),
                    (4, 'return'),
                    (12, 'line'),
                    (4, 'call'),
                    (4, 'exception'),
                    (6, 'line'),
                    (6, 'return'),
                    (12, 'return')]


def test_dont_trace_on_reraise():
    import sys
    l = []
    def ltrace(a,b,c):
        if b == 'exception':
            l.append(c)
        return ltrace
    def trace(a,b,c): return ltrace
    def f():
        try:
            1/0
        except:
            try:
                raise
            except:
                pass
    sys.settrace(trace)
    f()
    sys.settrace(None)
    assert len(l) == 1
    assert issubclass(l[0][0], Exception)

def test_dont_trace_on_reraise2():
    import sys
    l = []
    got_exc = []
    def trace(frame, event, arg):
        l.append((frame.f_lineno, event))
        if event == 'exception':
            got_exc.append(arg)
        return trace


    d = {}
    exec("""
def b(reraise): # line 2
    try:
        try:
            raise Exception(exc)
        except Exception as e:
            if reraise:
                raise
            print("after raise") # Not run, line 9
    except:
        pass
    """, d)

    sys.settrace(trace)
    d['b'](True)
    sys.settrace(None)
    assert l == [(2, 'call'), (3, 'line'), (4, 'line'),
                 (5, 'line'), (5, 'exception'), (6, 'line'),
                 (7, 'line'), (8, 'line'), # not 9!
                 (10, 'line'), (11, 'line'),
                 (11, 'return')]

def test_issue_3673():
    import sys
    l = []
    got_exc = []
    def trace(frame, event, arg):
        l.append((frame.f_lineno, event))
        if event == 'exception':
            got_exc.append(arg)
        return trace


    d = {}
    exec("""def regression():
    try: # line 2
        a = 1
        try:
            raise Exception("foo")
        finally:
            b = 123
    except:
        a = 99
    assert a == 99 and b == 123
    """, d)
    sys.settrace(trace)
    d['regression']()
    sys.settrace(None)
    goal = [(1, 'call'), (2, 'line'), (3, 'line'), (4, 'line'),
                 (5, 'line'), (5, 'exception'), (7, 'line'), (8, 'line'),
                 (9, 'line'), (10, 'line'), (10, 'return')]
    assert l == goal

    d = {}
    exec("""def regression():
    try:
        a = 1
        try:
            g() # not defined
        finally:
            b = 123
    except:
        a = 99
    assert a == 99 and b == 123
    """, d)
    l = []
    sys.settrace(trace)
    d['regression']()
    sys.settrace(None)
    print(l)
    assert l == goal

def test_trace_changes_locals():
    import sys
    def trace(frame, what, arg):
        frame.f_locals['x'] = 42
        return trace
    def f(x):
        return x
    sys.settrace(trace)
    res = f(1)
    sys.settrace(None)
    assert res == 42

def test_trace_onliner_if():
    import sys
    l = []
    def trace(frame, event, arg):
        l.append((frame.f_lineno, event))
        return trace
    def onliners():
        if True: False
        else: True
        return 0
    sys.settrace(trace)
    onliners()
    sys.settrace(None)
    firstlineno = onliners.__code__.co_firstlineno
    assert l == [(firstlineno + 0, 'call'),
                    (firstlineno + 3, 'line'),
                    (firstlineno + 3, 'return')]

def test_set_unset_f_trace():
    import sys
    seen = []
    def trace1(frame, what, arg):
        seen.append((1, frame, frame.f_lineno, what, arg))
        return trace1
    def trace2(frame, what, arg):
        seen.append((2, frame, frame.f_lineno, what, arg))
        return trace2
    def set_the_trace(f):
        f.f_trace = trace1
        sys.settrace(trace2)
        len(seen)     # take one line: should not be traced
    f = sys._getframe()
    set_the_trace(f)
    len(seen)     # take one line: should not be traced
    len(seen)     # take one line: should not be traced
    sys.settrace(None)   # and this line should be the last line traced
    len(seen)     # take one line
    del f.f_trace
    len(seen)     # take one line
    firstline = set_the_trace.__code__.co_firstlineno
    assert seen == [(1, f, firstline + 6, 'line', None),
                    (1, f, firstline + 7, 'line', None),
                    (1, f, firstline + 8, 'line', None)]

def test_locals2fast_freevar_bug():
    import sys
    def f(n):
        class A(object):
            def g(self):
                return n
            n = 42
        return A()
    res = f(10).g()
    assert res == 10
    #
    def trace(*args):
        return trace
    sys.settrace(trace)
    res = f(10).g()
    sys.settrace(None)
    assert res == 10

def test_disable_line_tracing():
    import sys
    assert sys._getframe().f_trace_lines

    l = []
    def trace(frame, event, arg):
        l.append((frame.f_code.co_name, event, arg, frame.f_lineno - frame.f_code.co_firstlineno))
        frame.f_trace_lines = False
        return trace
    def g(n):
        return n + 2
    def f(n):
        n = g(n)
        return n * 7
    sys.settrace(trace)
    x = f(4)
    sys.settrace(None)
    print(l)
    assert l == [('f', 'call', None, 0), ('g', 'call', None, 0), ('g', 'return', 6, 1), ('f', 'return', 42, 2)]

test_disable_line_tracing()

def test_opcode_tracing():
    import sys
    assert not sys._getframe().f_trace_opcodes

    l = []
    def trace(frame, event, arg):
        l.append((frame.f_code.co_name, event, arg, frame.f_lasti, frame.f_lineno - frame.f_code.co_firstlineno))
        frame.f_trace_opcodes = True
        return trace
    def g(n):
        return n + 2
    def f(n):
        return g(n)
    sys.settrace(trace)
    x = f(4)
    sys.settrace(None)
    print(l)
    assert l == [
        ('f', 'call', None, -1, 0),
        ('f', 'line', None, 0, 1),
        ('f', 'opcode', None, 0, 1),
        ('f', 'opcode', None, 2, 1),
        ('f', 'opcode', None, 4, 1),
        ('g', 'call', None, -1, 0),
        ('g', 'line', None, 0, 1),
        ('g', 'opcode', None, 0, 1),
        ('g', 'opcode', None, 2, 1),
        ('g', 'opcode', None, 4, 1),
        ('g', 'opcode', None, 6, 1),
        ('g', 'return', 6, 6, 1),
        ('f', 'opcode', None, 6, 1),
        ('f', 'return', 6, 6, 1)]

test_opcode_tracing()

def test_preserve_exc_state_in_generators():
    import sys
    def yield_raise():
        try:
            raise KeyError("caught")
        except KeyError:
            yield sys.exc_info()[0]
            yield sys.exc_info()[0]

    it = yield_raise()
    assert next(it) is KeyError
    assert next(it) is KeyError

def test_frame_clear():
    import sys, gc, weakref
    #
    raises(RuntimeError, sys._getframe().clear)
    def g():
        yield 5
        raises(RuntimeError, sys._getframe().clear)
        yield 6
    assert list(g()) == [5, 6]
    #
    class A:
        pass
    a1 = A(); a1ref = weakref.ref(a1)
    a2 = A(); a2ref = weakref.ref(a2)
    seen = []
    def f():
        local_a1 = a1
        for loc in [5, 6, a2]:
            try:
                yield sys._getframe()
            finally:
                seen.append(42)
            seen.append(43)
    gen = f()
    frame = next(gen)
    a1 = a2 = None
    gc.collect(); gc.collect()
    assert a1ref() is not None
    assert a2ref() is not None
    assert seen == []
    frame.clear()
    assert seen == [42]
    gc.collect(); gc.collect()
    assert a1ref() is None, "locals not cleared"
    assert a2ref() is None, "stack not cleared"
    #
    raises(StopIteration, next, gen)

def test_frame_clear_really():
    import sys
    def f(x):
        return sys._getframe()
    frame = f(42)
    assert frame.f_locals['x'] == 42
    frame.clear()
    assert frame.f_locals == {}

def test_throw_trace_bug():
    import sys
    def f():
        yield 5
    gen = f()
    assert next(gen) == 5
    seen = []
    def trace_func(frame, event, *args):
        seen.append(event)
        return trace_func
    sys.settrace(trace_func)
    try:
        gen.throw(ValueError)
    except ValueError:
        pass
    sys.settrace(None)
    assert seen == ['call', 'exception', 'return']

def test_generator_trace_stopiteration():
    import sys
    def f():
        yield 5
    gen = f()
    assert next(gen) == 5
    seen = []
    frames = []
    def trace_func(frame, event, *args):
        print('TRACE:', frame, event, args)
        seen.append(event)
        frames.append(frame)
        return trace_func
    def g():
        for x in gen:
            never_entered
    sys.settrace(trace_func)
    g()
    sys.settrace(None)
    print('seen:', seen)
    # on Python 3 we get an extra 'exception' when 'for' catches
    # StopIteration (but not always! mess)
    assert seen == ['call', 'line', 'call', 'return', 'exception', 'return']
    assert frames[-2].f_code.co_name == 'g'

def test_nongenerator_trace_stopiteration():
    import sys
    gen = iter([5])
    assert next(gen) == 5
    seen = []
    frames = []
    def trace_func(frame, event, *args):
        print('TRACE:', frame, event, args)
        seen.append(event)
        frames.append(frame)
        return trace_func
    def g():
        for x in gen:
            never_entered
    sys.settrace(trace_func)
    g()
    sys.settrace(None)
    print('seen:', seen)
    # hack: don't report the StopIteration for some "simple"
    # iterators.
    assert seen == ['call', 'line', 'return']
    assert frames[-2].f_code.co_name == 'g'

def test_yieldfrom_trace_stopiteration():
    import sys
    def f2():
        yield 5
    def f():
        yield from f2()
    gen = f()
    assert next(gen) == 5
    seen = []
    frames = []
    def trace_func(frame, event, *args):
        print('TRACE:', frame, event, args)
        seen.append(event)
        frames.append(frame)
        return trace_func
    def g():
        for x in gen:
            never_entered
    sys.settrace(trace_func)
    g()      # invokes next_yield_from() from resume_execute_frame()
    sys.settrace(None)
    print('seen:', seen)
    assert seen == ['call', 'line', 'call', 'call', 'return',
                    'exception', 'return', 'exception', 'return']
    assert frames[-4].f_code.co_name == 'f'
    assert frames[-2].f_code.co_name == 'g'

def test_yieldfrom_trace_stopiteration_2():
    import sys
    def f2():
        if False:
            yield 5
    def f():
        yield from f2()
    gen = f()
    seen = []
    frames = []
    def trace_func(frame, event, *args):
        print('TRACE:', frame, event, args)
        seen.append(event)
        frames.append(frame)
        return trace_func
    def g():
        for x in gen:
            never_entered
    sys.settrace(trace_func)
    g()      # invokes next_yield_from() from YIELD_FROM()
    sys.settrace(None)
    print('seen:', seen)
    assert seen == ['call', 'line', 'call', 'line', 'call', 'line',
                    'return', 'exception', 'return', 'exception', 'return']
    assert frames[-4].f_code.co_name == 'f'
    assert frames[-2].f_code.co_name == 'g'

def test_yieldfrom_trace_stopiteration_3():
    import sys
    def f():
        yield from []
    gen = f()
    seen = []
    frames = []
    def trace_func(frame, event, *args):
        print('TRACE:', frame, event, args)
        seen.append(event)
        frames.append(frame)
        return trace_func
    def g():
        for x in gen:
            never_entered
    sys.settrace(trace_func)
    g()      # invokes next_yield_from() from YIELD_FROM()
    sys.settrace(None)
    print('seen:', seen)
    assert seen == ['call', 'line', 'call', 'line',
                    'return', 'exception', 'return']
    assert frames[-4].f_code.co_name == 'f'

def test_local_trace_function_returning_None_ignored():
    # behave the same as CPython does, and in contradiction with
    # the documentation.
    def tracer(f, event, arg):
        assert event == 'call'
        return local_tracer

    seen = []
    def local_tracer(f, event, arg):
        seen.append(event)
        return None     # but 'local_tracer' will be called again

    def function():
        a = 1
        a = 2
        a = 3

    import sys
    sys.settrace(tracer)
    function()
    sys.settrace(None)
    assert seen == ["line", "line", "line", "return"]

def test_clear_locals():
    def make_frames():
        def outer():
            x = 5
            y = 6
            def inner():
                z = x + 2
                1/0
                t = 9
            return inner()
        try:
            outer()
        except ZeroDivisionError as e:
            tb = e.__traceback__
            frames = []
            while tb:
                frames.append(tb.tb_frame)
                tb = tb.tb_next
        return frames

    f, outer, inner = make_frames()
    outer.clear()
    inner.clear()
    assert not outer.f_locals
    assert not inner.f_locals


def test_locals2fast_del_cell_var():
    import sys
    def t(frame, event, *args):
        if 'a' in frame.f_locals:
            del frame.f_locals['a']
        return t
    def f():
        def g(): a
        a = 1
        a = 2
        return a

    sys.settrace(t)
    try:
        with pytest.raises(UnboundLocalError):
            f()
    finally:
        sys.settrace(None)

