import pytest
from pytest import raises

import sys


class suspend:
    """
    A simple awaitable that returns control to the "event loop" with `msg`
    as value.
    """
    def __init__(self, msg=None):
        self.msg = msg

    def __await__(self):
        yield self.msg


def test_cannot_iterate():
    async def f(x):
        pass
    pytest.raises(TypeError, "for i in f(5): pass")
    pytest.raises(TypeError, iter, f(5))
    pytest.raises(TypeError, next, f(5))


def test_async_for():
    class X:
        def __aiter__(self):
            return MyAIter()

    class MyAIter:
        async def __anext__(self):
            return 42
    async def f(x):
        sum = 0
        async for a in x:
            sum += a
            if sum > 100:
                break
        return sum
    cr = f(X())
    try:
        cr.send(None)
    except StopIteration as e:
        assert e.value == 42 * 3
    else:
        assert False, "should have raised"


def test_StopAsyncIteration():
    class X:
        def __aiter__(self):
            return MyAIter()
    class MyAIter:
        count = 0
        async def __anext__(self):
            if self.count == 3:
                raise StopAsyncIteration
            self.count += 1
            return 42
    async def f(x):
        sum = 0
        async for a in x:
            sum += a
        return sum
    cr = f(X())
    try:
        cr.send(None)
    except StopIteration as e:
        assert e.value == 42 * 3
    else:
        assert False, "should have raised"

def test_for_error_cause():
    class F:
        def __aiter__(self):
            return self
        def __anext__(self):
            return self
        def __await__(self):
            1 / 0

    async def main():
        async for _ in F():
            pass

    c = pytest.raises(TypeError, main().send, None)
    assert 'an invalid object from __anext__' in c.value.args[0], c.value
    assert isinstance(c.value.__cause__, ZeroDivisionError)

def test_async_with():
    seen = []
    class X:
        async def __aenter__(self):
            seen.append('aenter')
        async def __aexit__(self, *args):
            seen.append('aexit')
    async def f(x):
        async with x:
            return 42
    c = f(X())
    try:
        c.send(None)
    except StopIteration as e:
        assert e.value == 42
    else:
        assert False, "should have raised"
    assert seen == ['aenter', 'aexit']

def test_async_with_exit_True():
    seen = []
    class X:
        async def __aenter__(self):
            seen.append('aenter')
        async def __aexit__(self, *args):
            seen.append('aexit')
            return True
    async def f(x):
        async with x:
            return 42
    c = f(X())
    try:
        c.send(None)
    except StopIteration as e:
        assert e.value == 42
    else:
        assert False, "should have raised"
    assert seen == ['aenter', 'aexit']

def test_await():
    class X:
        def __await__(self):
            i1 = yield 40
            assert i1 == 82
            i2 = yield 41
            assert i2 == 93
    async def f():
        await X()
        await X()
    c = f()
    assert c.send(None) == 40
    assert c.send(82) == 41
    assert c.send(93) == 40
    assert c.send(82) == 41
    pytest.raises(StopIteration, c.send, 93)


def test_await_error():
    async def f():
        await [42]
    c = f()
    try:
        c.send(None)
    except TypeError as e:
        assert str(e) == "object list can't be used in 'await' expression"
    else:
        assert False, "should have raised"


def test_async_with_exception_context():
    class CM:
        async def __aenter__(self):
            pass
        async def __aexit__(self, *e):
            1/0
    async def f():
        async with CM():
            raise ValueError
    c = f()
    try:
        c.send(None)
    except ZeroDivisionError as e:
        assert e.__context__ is not None
        assert isinstance(e.__context__, ValueError)
    else:
        assert False, "should have raised"


def test_runtime_warning():
    import gc, warnings  # XXX: importing warnings is expensive untranslated
    async def foobaz():
        pass
    gc.collect()   # emit warnings from unrelated older tests
    with warnings.catch_warnings(record=True) as l:
        foobaz()
        gc.collect()
        gc.collect()
        gc.collect()

    assert len(l) == 1, repr(l)
    w = l[0].message
    assert isinstance(w, RuntimeWarning)
    assert str(w).startswith("coroutine ")
    assert str(w).endswith("foobaz' was never awaited")


def test_async_for_with_tuple_subclass():
    class Done(Exception): pass

    class AIter(tuple):
        i = 0
        def __aiter__(self):
            return self
        async def __anext__(self):
            if self.i >= len(self):
                raise StopAsyncIteration
            self.i += 1
            return self[self.i - 1]

    result = []
    async def foo():
        async for i in AIter([42]):
            result.append(i)
        raise Done

    try:
        foo().send(None)
    except Done:
        pass
    assert result == [42]

def test_async_yield():
    class Done(Exception): pass

    async def mygen():
        yield 5

    result = []
    async def foo():
        async for i in mygen():
            result.append(i)
        raise Done

    try:
        foo().send(None)
    except Done:
        pass
    assert result == [5]

def test_async_yield_already_finished():
    class Done(Exception): pass

    async def mygen():
        yield 5

    result = []
    async def foo():
        g = mygen()
        async for i in g:
            result.append(i)
        async for i in g:
            assert False   # should not be reached
        raise Done

    try:
        foo().send(None)
    except Done:
        pass
    assert result == [5]

def test_async_yield_with_await():
    class Done(Exception): pass

    class X:
        def __await__(self):
            i1 = yield 40
            assert i1 == 82
            i2 = yield 41
            assert i2 == 93

    async def mygen():
        yield 5
        await X()
        yield 6

    result = []
    async def foo():
        async for i in mygen():
            result.append(i)
        raise Done

    co = foo()
    x = co.send(None)
    assert x == 40
    assert result == [5]
    x = co.send(82)
    assert x == 41
    assert result == [5]
    raises(Done, co.send, 93)
    assert result == [5, 6]

def test_async_yield_with_explicit_send():
    class X:
        def __await__(self):
            i1 = yield 40
            assert i1 == 82
            i2 = yield 41
            assert i2 == 93

    async def mygen():
        x = yield 5
        assert x == 2189
        await X()
        y = yield 6
        assert y == 319

    result = []
    async def foo():
        gen = mygen()
        result.append(await gen.asend(None))
        result.append(await gen.asend(2189))
        try:
            await gen.asend(319)
        except StopAsyncIteration:
            return 42
        else:
            raise AssertionError

    co = foo()
    x = co.send(None)
    assert x == 40
    assert result == [5]
    x = co.send(82)
    assert x == 41
    assert result == [5]
    e = raises(StopIteration, co.send, 93)
    assert e.value.args == (42,)
    assert result == [5, 6]

def test_async_yield_explicit_asend_and_next():
    async def mygen(y):
        assert y == 4983
        x = yield 5
        assert x == 2189
        yield "ok"

    g = mygen(4983)
    raises(TypeError, g.asend(42).__next__)
    e = raises(StopIteration, g.asend(None).__next__)
    assert e.value.args == (5,)
    e = raises(StopIteration, g.asend(2189).__next__)
    assert e.value.args == ("ok",)

def test_async_yield_explicit_asend_and_send():
    async def mygen(y):
        assert y == 4983
        x = yield 5
        assert x == 2189
        yield "ok"

    g = mygen(4983)
    e = raises(TypeError, g.asend(None).send, 42)
    assert str(e.value) == ("can't send non-None value to a just-started "
                            "async generator")
    e = raises(StopIteration, g.asend(None).send, None)
    assert e.value.args == (5,)
    e = raises(StopIteration, g.asend("IGNORED").send, 2189)  # xxx
    assert e.value.args == ("ok",)

def test_async_yield_explicit_asend_used_several_times():
    class X:
        def __await__(self):
            r = yield -2
            assert r == "cont1"
            r = yield -3
            assert r == "cont2"
            return -4
    async def mygen(y):
        x = await X()
        assert x == -4
        r = yield -5
        assert r == "foo"
        r = yield -6
        assert r == "bar"

    g = mygen(4983)
    gs = g.asend(None)
    r = gs.send(None)
    assert r == -2
    r = gs.send("cont1")
    assert r == -3
    e = raises(StopIteration, gs.send, "cont2")
    assert e.value.args == (-5,)
    e = raises(RuntimeError, gs.send, None)
    e = raises(RuntimeError, gs.send, None)
    #
    gs = g.asend("foo")
    e = raises(StopIteration, gs.send, None)
    assert e.value.args == (-6,)
    e = raises(RuntimeError, gs.send, "bar")

def test_async_yield_asend_notnone_throw():
    async def f():
        yield 123

    raises(ValueError, f().asend(42).throw, ValueError)

def test_async_yield_asend_none_throw():
    async def f():
        yield 123

    raises(ValueError, f().asend(None).throw, ValueError)

def test_async_yield_athrow_send_none():
    async def ag():
        yield 42

    raises(ValueError, ag().athrow(ValueError).send, None)

def test_async_yield_athrow_send_notnone():
    async def ag():
        yield 42

    ex = raises(RuntimeError, ag().athrow(ValueError).send, 42)
    expected = ("can't send non-None value to a just-started coroutine", )
    assert ex.value.args == expected

def test_async_yield_athrow_send_after_exception():
    async def ag():
        yield 42

    athrow_coro = ag().athrow(ValueError)
    raises(ValueError, athrow_coro.send, None)
    raises(RuntimeError, athrow_coro.send, None)

def test_async_yield_athrow_throw():
    async def ag():
        yield 42

    raises(RuntimeError, ag().athrow(ValueError).throw, LookupError)
    # CPython's message makes little sense; PyPy's message is different

def test_async_yield_athrow_while_running():
    values = []
    async def ag():
        try:
            received = yield 1
        except ValueError:
            values.append(42)
            return
        yield 2


    async def run():
        running = ag()
        x = await running.asend(None)
        assert x == 1
        try:
            await running.athrow(ValueError)
        except StopAsyncIteration:
            pass


    try:
        run().send(None)
    except StopIteration:
        assert values == [42]

def test_async_aclose():
    raises_generator_exit = False
    async def ag():
        nonlocal raises_generator_exit
        try:
            yield
        except GeneratorExit:
            raises_generator_exit = True
            raise

    async def run():
        a = ag()
        async for i in a:
            break
        await a.aclose()
    try:
        run().send(None)
    except StopIteration:
        pass
    assert raises_generator_exit

def test_async_aclose_ignore_generator_exit():
    async def ag():
        try:
            yield
        except GeneratorExit:
            yield

    async def run():
        a = ag()
        async for i in a:
            break
        await a.aclose()
    raises(RuntimeError, run().send, None)

def test_async_aclose_await_in_finally():
    state = 0
    async def ag():
        nonlocal state
        try:
            yield
        finally:
            state = 1
            await suspend('coro')
            state = 2

    async def run():
        a = ag()
        async for i in a:
            break
        await a.aclose()
    a = run()
    assert state == 0
    assert a.send(None) == 'coro'
    assert state == 1
    try:
        a.send(None)
    except StopIteration:
        pass
    assert state == 2

def test_async_aclose_await_in_finally_with_exception():
    state = 0
    async def ag():
        nonlocal state
        try:
            yield
        finally:
            state = 1
            try:
                await suspend('coro')
            except Exception as exc:
                state = exc

    async def run():
        a = ag()
        async for i in a:
            break
        await a.aclose()
    a = run()
    assert state == 0
    assert a.send(None) == 'coro'
    assert state == 1
    exc = RuntimeError()
    try:
        a.throw(exc)
    except StopIteration:
        pass
    assert state == exc

def test_agen_aclose_await_and_yield_in_finally():
    async def foo():
        try:
            yield 1
            1 / 0
        finally:
            await suspend(42)
            yield 12

    async def run():
        gen = foo()
        it = gen.__aiter__()
        await it.__anext__()
        await gen.aclose()

    coro = run()
    assert coro.send(None) == 42
    with pytest.raises(RuntimeError):
        coro.send(None)

def test_async_aclose_in_finalize_hook_await_in_finally():
    import gc
    state = 0
    async def ag():
        nonlocal state
        try:
            yield
        finally:
            state = 1
            await suspend('coro')
            state = 2

    async def run():
        a = ag()
        async for i in a:
            break
        del a
        gc.collect()
        gc.collect()
        gc.collect()
    a = run()

    a2 = None
    assert sys.get_asyncgen_hooks() == (None, None)
    def _finalize(g):
        nonlocal a2
        a2 = g.aclose()
    sys.set_asyncgen_hooks(finalizer=_finalize)
    assert state == 0
    with pytest.raises(StopIteration):
        a.send(None)
    assert a2.send(None) == 'coro'
    assert state == 1
    with pytest.raises(StopIteration):
        a2.send(None)
    assert state == 2
    sys.set_asyncgen_hooks(None, None)

def test_async_anext_close():
    async def ag():
        yield 42

    an = ag().__anext__()
    an.close()
    try:
        next(an)
    except RuntimeError:
        pass
    else:
        assert False, "didn't raise"

def run_async(coro):
    buffer = []
    result = None
    while True:
        try:
            buffer.append(coro.send(None))
        except StopIteration as ex:
            result = ex.args[0] if ex.args else None
            break
    return buffer, result

def test_async_generator():
    async def f(i):
        return i

    async def run_list():
        return [await c for c in [f(1), f(41)]]

    assert run_async(run_list()) == ([], [1, 41])

def test_async_genexpr():
    async def f(it):
        for i in it:
            yield i

    async def run_gen():
        gen = (i + 1 async for i in f([10, 20]))
        return [g + 100 async for g in gen]

    assert run_async(run_gen()) == ([], [111, 121])

def test_anext_tuple():
    async def foo():
        try:
            yield (1,)
        except ZeroDivisionError:
            yield (2,)

    async def run():
        it = foo().__aiter__()
        return await it.__anext__()

    assert run_async(run()) == ([], (1,))

def test_async_genexpr_in_regular_function():
    async def arange(n):
        for i in range(n):
            yield i

    def make_arange(n):
        # This syntax is legal starting with Python 3.7
        return (i * 2 async for i in arange(n))

    async def run():
        return [i async for i in make_arange(10)]
    res = run_async(run())
    assert res[1] == [i * 2 for i in range(10)]

# Helpers for test_async_gen_exception_11() below
def sync_iterate(g):
    res = []
    while True:
        try:
            res.append(g.__next__())
        except StopIteration:
            res.append('STOP')
            break
        except Exception as ex:
            res.append(str(type(ex)))
    return res

def async_iterate(g):
    res = []
    while True:
        try:
            g.__anext__().__next__()
        except StopAsyncIteration:
            res.append('STOP')
            break
        except StopIteration as ex:
            if ex.args:
                res.append(ex.args[0])
            else:
                res.append('EMPTY StopIteration')
                break
        except Exception as ex:
            res.append(str(type(ex)))
    return res


def test_async_gen_exception_11():
    # bpo-33786
    def sync_gen():
        yield 10
        yield 20

    def sync_gen_wrapper():
        yield 1
        sg = sync_gen()
        sg.send(None)
        try:
            sg.throw(GeneratorExit())
        except GeneratorExit:
            yield 2
        yield 3

    async def async_gen():
        yield 10
        yield 20

    async def async_gen_wrapper():
        yield 1
        asg = async_gen()
        await asg.asend(None)
        try:
            await asg.athrow(GeneratorExit())
        except GeneratorExit:
            yield 2
        yield 3

    sync_gen_result = sync_iterate(sync_gen_wrapper())
    async_gen_result = async_iterate(async_gen_wrapper())
    assert sync_gen_result == async_gen_result

def test_asyncgen_yield_stopiteration():
    async def foo():
        yield 1
        yield StopIteration(2)

    async def run():
        it = foo().__aiter__()
        val1 = await it.__anext__()
        assert val1 == 1
        val2 = await it.__anext__()
        assert isinstance(val2, StopIteration)
        assert val2.value == 2

    run_async(run())

def test_asyncgen_hooks_shutdown():
    finalized = 0
    asyncgens = []

    def register_agen(agen):
        asyncgens.append(agen)

    async def waiter(timeout):
        nonlocal finalized
        try:
            await suspend('running waiter')
            yield 1
        finally:
            await suspend('closing waiter')
            finalized += 1

    async def wait():
        async for _ in waiter(1):
            pass

    task1 = wait()
    task2 = wait()
    old_hooks = sys.get_asyncgen_hooks()
    try:
        sys.set_asyncgen_hooks(firstiter=register_agen)
        assert task1.send(None) == 'running waiter'
        assert task2.send(None) == 'running waiter'
        assert len(asyncgens) == 2

        assert run_async(asyncgens[0].aclose()) == (['closing waiter'], None)
        assert run_async(asyncgens[1].aclose()) == (['closing waiter'], None)
        assert finalized == 2
    finally:
        sys.set_asyncgen_hooks(*old_hooks)

def test_coroutine_capture_origin():
    import contextlib

    def here():
        f = sys._getframe().f_back
        return (f.f_code.co_filename, f.f_lineno)

    try:
        async def corofn():
            pass

        with contextlib.closing(corofn()) as coro:
            assert coro.cr_origin is None

        sys.set_coroutine_origin_tracking_depth(1)

        fname, lineno = here()
        with contextlib.closing(corofn()) as coro:
            print(coro.cr_origin)
            assert coro.cr_origin == (
                (fname, lineno + 1, "test_coroutine_capture_origin"),)


        sys.set_coroutine_origin_tracking_depth(2)

        def nested():
            return (here(), corofn())
        fname, lineno = here()
        ((nested_fname, nested_lineno), coro) = nested()
        with contextlib.closing(coro):
            print(coro.cr_origin)
            assert coro.cr_origin == (
                (nested_fname, nested_lineno, "nested"),
                (fname, lineno + 1, "test_coroutine_capture_origin"))

        # Check we handle running out of frames correctly
        sys.set_coroutine_origin_tracking_depth(1000)
        with contextlib.closing(corofn()) as coro:
            print(coro.cr_origin)
            assert 1 <= len(coro.cr_origin) < 1000
    finally:
        sys.set_coroutine_origin_tracking_depth(0)

def test_runtime_warning_origin_tracking():
    import gc, warnings  # XXX: importing warnings is expensive untranslated
    async def foobaz():
        pass
    gc.collect()   # emit warnings from unrelated older tests
    with warnings.catch_warnings(record=True) as l:
        foobaz()
        gc.collect()
        gc.collect()
        gc.collect()

    assert len(l) == 1, repr(l)
    w = l[0].message
    assert isinstance(w, RuntimeWarning)
    assert str(w).startswith("coroutine ")
    assert str(w).endswith("foobaz' was never awaited")
    assert "test_runtime_warning_origin_tracking" in str(w)

def test_await_multiple_times_same_gen():
    async def async_iterate():
        yield 1
        yield 2

    async def run():
        it = async_iterate()
        nxt = it.__anext__()
        await nxt
        with pytest.raises(RuntimeError):
            await nxt

        coro = it.aclose()
        await coro
        with pytest.raises(RuntimeError):
            await coro

    run_async(run())

def test_async_generator_wrapped_value_is_real_type():
    def tracer(frame, evt, *args):
        str(args) # used to crash when seeing the AsyncGenValueWrapper
        return tracer

    async def async_gen():
        yield -2

    async def async_test():
        a = 2
        async for i in async_gen():
            a = 4
        else:
            a = 6

    def run():
        x = async_test()
        try:
            sys.settrace(tracer)
            x.send(None)
        finally:
            sys.settrace(None)
    raises(StopIteration, run)
