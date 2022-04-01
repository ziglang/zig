import pytest

def test_yield_in_nested_try_excepts():
    #Issue #25612
    class MainError(Exception):
        pass

    class SubError(Exception):
        pass

    def main():
        try:
            raise MainError()
        except MainError:
            try:
                yield
            except SubError:
                pass
            raise

    coro = main()
    coro.send(None)
    with pytest.raises(MainError):
        coro.throw(SubError())

def test_generator_doesnt_retain_old_exc2():
    pytest.skip("broken right now :-(")
    # Issue bpo 28884#msg282532
    # Fixed in CPython via https://github.com/python/cpython/pull/1773
    import sys
    def g():
        try:
            raise ValueError
        except ValueError:
            yield 1
        assert sys.exc_info() == (None, None, None)
        yield 2

    gen = g()

    try:
        raise IndexError
    except IndexError:
        assert next(gen) == 1
    assert next(gen) == 2

def test_raise_in_generator():
    #Issue 25612#msg304117
    def g():
        yield 1
        raise
        yield 2

    with pytest.raises(ZeroDivisionError):
        i = g()
        try:
            1/0
        except:
            next(i)
            next(i)

def test_assertion_error_global_ignored():
    if hasattr(pytest, 'py3k_skip'):
        pytest.py3k_skip('only untranslated')
    global AssertionError

    class Foo(Exception):
        pass
    OrigAssertionError = AssertionError
    AssertionError = Foo
    try:
        with pytest.raises(OrigAssertionError): # not Foo!
            exec("assert 0") # to stop the pytest ast rewriting from touching it
    finally:
        AssertionError = OrigAssertionError
