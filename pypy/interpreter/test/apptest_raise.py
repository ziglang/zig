import pytest

def test_arg_as_string():
    with pytest.raises(TypeError):
        raise "test"

def test_control_flow():
    try:
        raise Exception
        raise AssertionError("exception failed to raise")
    except:
        pass
    else:
        raise AssertionError("exception executing else clause!")

def test_store_exception():
    try:
        raise ValueError
    except Exception as e:
        assert e


def test_args():
    try:
        raise SystemError(1, 2)
    except Exception as e:
        assert e.args[0] == 1
        assert e.args[1] == 2

def test_builtin_exc():
    try:
        [][0]
    except IndexError as e:
        assert isinstance(e, IndexError)

def test_raise_cls():
    with pytest.raises(IndexError):
        raise IndexError

def test_raise_cls_catch():
    def f(r):
        try:
            raise r
        except LookupError:
            return 1
    with pytest.raises(Exception):
        f(Exception)
    assert f(IndexError) == 1

def test_raise_wrong():
    try:
        raise 1
    except TypeError:
        pass
    else:
        raise AssertionError("shouldn't be able to raise 1")

def test_revert_exc_info_1():
    import sys
    assert sys.exc_info() == (None, None, None)
    try:
        raise ValueError
    except:
        pass
    assert sys.exc_info() == (None, None, None)

def test_revert_exc_info_2():
    import sys
    assert sys.exc_info() == (None, None, None)
    try:
        raise ValueError
    except:
        try:
            raise IndexError
        except:
            assert sys.exc_info()[0] is IndexError
        assert sys.exc_info()[0] is ValueError
    assert sys.exc_info() == (None, None, None)

def test_revert_exc_info_2_finally():
    import sys
    assert sys.exc_info() == (None, None, None)
    try:
        try:
            raise ValueError
        finally:
            try:
                try:
                    raise IndexError
                finally:
                    assert sys.exc_info()[0] is IndexError
            except IndexError:
                pass
            assert sys.exc_info()[0] is ValueError
    except ValueError:
        pass
    assert sys.exc_info() == (None, None, None)

def test_reraise_1():
    with pytest.raises(IndexError):
        import sys
        try:
            raise ValueError
        except:
            try:
                raise IndexError
            finally:
                assert sys.exc_info()[0] is IndexError
                raise


def test_reraise_2():
    with pytest.raises(IndexError):
        def foo():
            import sys
            assert sys.exc_info()[0] is IndexError
            raise
        try:
            raise ValueError
        except:
            try:
                raise IndexError
            finally:
                foo()


def test_reraise_3():
    with pytest.raises(IndexError):
        def spam():
            import sys
            try:
                raise KeyError
            except KeyError:
                pass
            assert sys.exc_info()[0] is IndexError
        try:
            raise ValueError
        except:
            try:
                raise IndexError
            finally:
                spam()

def test_reraise_4():
    import sys
    try:
        raise ValueError
    except:
        try:
            raise KeyError
        except:
            ok = sys.exc_info()[0] is KeyError
    assert ok

def test_reraise_5():
    with pytest.raises(IndexError):
        import sys
        try:
            raise ValueError
        except:
            some_traceback = sys.exc_info()[2]
        try:
            raise KeyError
        except:
            try:
                raise IndexError().with_traceback(some_traceback)
            finally:
                assert sys.exc_info()[0] is IndexError
                assert sys.exc_info()[2].tb_next is some_traceback

def test_nested_reraise():
    with pytest.raises(TypeError):
        def nested_reraise():
            raise
        try:
            raise TypeError("foo")
        except:
            nested_reraise()


def test_with_reraise_1():
    class Context:
        def __enter__(self):
            return self
        def __exit__(self, exc_type, exc_value, exc_tb):
            return True

    def fn():
        try:
            raise ValueError("foo")
        except:
            with Context():
                pass
            raise
    with pytest.raises(ValueError):
        fn()

def test_with_reraise_2():
    class Context:
        def __enter__(self):
            return self
        def __exit__(self, exc_type, exc_value, exc_tb):
            return True

    def fn():
        try:
            raise ValueError("foo")
        except:
            with Context():
                raise KeyError("caught")
            raise
    with pytest.raises(ValueError):
        fn()

def test_userclass():
    # new-style classes can't be raised unless they inherit from
    # BaseException
    class A(object):
        def __init__(self, x=None):
            self.x = x

    with pytest.raises(TypeError):
        raise A
    with pytest.raises(TypeError):
        raise A(42)

def test_userclass_catch():
    # classes can't be caught unless they inherit from BaseException
    class A(object):
        pass

    for exc in A, (ZeroDivisionError, A):
        try:
            try:
                1 / 0
            except exc:
                pass
        except TypeError:
            pass
        else:
            fail('Expected TypeError')

def test_it():
    class C:
        pass
    # this used to explode in the exception normalization step:
    try:
        {}[C]
    except KeyError:
        pass

def test_catch_tuple():
    class A(Exception):
        pass

    try:
        raise ValueError
    except (ValueError, A):
        pass
    else:
        fail("Did not raise")

    try:
        raise A()
    except (ValueError, A):
        pass
    else:
        fail("Did not raise")

def test_obscure_bases():
    # this test checks bug-to-bug cpython compatibility
    e = ValueError()
    e.__bases__ = (5,)
    try:
        raise e
    except ValueError:
        pass

    # explodes on CPython and pytest, not sure why

    flag = False
    class metaclass(type):
        def __getattribute__(self, name):
            if flag and name == '__bases__':
                fail("someone read bases attr")
            else:
                return type.__getattribute__(self, name)
    class A(BaseException, metaclass=metaclass):
        pass
    try:
        a = A()
        flag = True
        raise a
    except A:
        pass

def test_new_returns_bad_instance():
    class MyException(Exception):
        def __new__(cls, *args):
            return object()

    with pytest.raises(TypeError):
        raise MyException

def test_with_exit_True():
    class X:
        def __enter__(self):
            pass
        def __exit__(self, *args):
            return True
    def g():
        with X():
            return 42
        assert False, "unreachable"
    assert g() == 42

def test_pop_exception_value():
    # assert that this code don't crash
    for i in range(10):
        try:
            raise ValueError
        except ValueError as e:
            continue

def test_clear_last_exception_on_break():
    import sys
    for i in [0]:
        try:
            raise ValueError
        except ValueError:
            break
    assert sys.exc_info() == (None, None, None)


def test_instance_context():
    context = IndexError()
    try:
        try:
            raise context
        except:
            raise OSError()
    except OSError as e:
        assert e.__context__ is context
    else:
        fail('No exception raised')

def test_class_context():
    context = IndexError
    try:
        try:
            raise context
        except:
            raise OSError()
    except OSError as e:
        assert e.__context__ != context
        assert isinstance(e.__context__, context)
    else:
        fail('No exception raised')

def test_internal_exception():
    try:
        try:
            1/0
        except:
            xyzzy
    except NameError as e:
        assert isinstance(e.__context__, ZeroDivisionError)
    else:
        fail("No exception raised")

def test_context_cycle_broken():
    try:
        try:
            1/0
        except ZeroDivisionError as e:
            raise e
    except ZeroDivisionError as e:
        assert e.__context__ is None
    else:
        fail("No exception raised")

def test_context_preexisting_cycle():
    def chain(e, i=0):
        res = Exception(i)
        res.__context__ = e
        return res
    def cycle():
        try:
            raise ValueError(1)
        except ValueError as ex:
            start = curr = Exception()
            for i in range(chainlength):
                curr = chain(curr, i) # make cycle ourselves
            start.__context__ = curr
            for i in range(prelength):
                curr = chain(curr, i + chainlength)
            ex.__context__ = curr
            raise TypeError(2) # shouldn't hang here
    for chainlength in range(2, 7):
        for prelength in range(2, 7):
            print(chainlength, prelength)
            raises(TypeError, cycle)

def test_context_long_cycle_broken():
    def chain(e, i=0):
        res = Exception(i)
        res.__context__ = e
        return res
    def cycle():
        try:
            raise ValueError(1)
        except ValueError as ex:
            start = curr = TypeError()
            for i in range(chainlength):
                curr = chain(curr, i) # make cycle ourselves
            ex.__context__ = curr
            raise start
    for chainlength in range(2, 7):
        print(chainlength)
        exc = raises(TypeError, cycle).value
        for i in range(chainlength + 1):
            exc = exc.__context__
        assert exc.__context__ is None # got broken

def test_context_reraise_cycle_broken():
    try:
        try:
            xyzzy
        except NameError as a:
            try:
                1/0
            except ZeroDivisionError:
                raise a
    except NameError as e:
        assert e.__context__.__context__ is None
    else:
        fail("No exception raised")

def test_context_once_removed():
    context = IndexError()
    def func1():
        func2()
    def func2():
        try:
            1/0
        except ZeroDivisionError as e:
            assert e.__context__ is context
        else:
            fail('No exception raised')
    try:
        raise context
    except:
        func1()

def test_context_frame_spanning_cycle_broken():
    context = IndexError()
    def func():
        try:
            1/0
        except Exception as e1:
            try:
                raise context
            except Exception as e2:
                assert e2.__context__ is e1
                assert e1.__context__ is None
        else:
            fail('No exception raised')
    try:
        raise context
    except:
        func()

def testCauseSyntax():
    """
    try:
        try:
            try:
                raise TypeError
            except Exception:
                raise ValueError from None
        except ValueError as exc:
            assert exc.__cause__ is None
            assert exc.__suppress_context__ is True
            assert isinstance(exc.__context__, TypeError)
            exc.__suppress_context__ = False
            raise exc
    except ValueError as exc:
        e = exc
    assert e.__cause__ is None
    assert e.__suppress_context__ is False
    assert isinstance(e.__context__, TypeError)
    """

def test_context_in_builtin():
    context = IndexError()
    try:
        try:
            raise context
        except:
            compile('pass', 'foo', 'doh')
    except ValueError as e:
        assert e.__context__ is context
    else:
        fail('No exception raised')

def test_context_with_suppressed():
    class RaiseExc:
        def __init__(self, exc):
            self.exc = exc
        def __enter__(self):
            return self
        def __exit__(self, *exc_details):
            raise self.exc

    class SuppressExc:
        def __enter__(self):
            return self
        def __exit__(self, *exc_details):
            return True

    try:
        with RaiseExc(IndexError):
            with SuppressExc():
                with RaiseExc(ValueError):
                    1/0
    except IndexError as exc:
        assert exc.__context__ is None
    else:
        assert False, "should have raised"

def test_with_exception_context():
    class Ctx:
        def __enter__(self):
            pass
        def __exit__(self, *e):
            1/0
    try:
        with Ctx():
            raise ValueError
    except ZeroDivisionError as e:
        assert e.__context__ is not None
        assert isinstance(e.__context__, ValueError)
    else:
        assert False, "should have raised"

def test_context_setter_ignored():
    class MyExc(Exception):
        def __setattr__(self, name, value):
            assert name != "__context__"

    with pytest.raises(MyExc) as excinfo:
        try:
            raise KeyError
        except KeyError:
            raise MyExc
    assert isinstance(excinfo.value.__context__, KeyError)

def test_context_getter_ignored():
    class MyExc(Exception):
        __context__ = property(None, None, None)

    with pytest.raises(KeyError):
        try:
            raise MyExc
        except MyExc:
            raise KeyError



def test_raise_with___traceback__():
    import sys
    try:
        raise ValueError
    except:
        exc_type,exc_val,exc_tb = sys.exc_info()
    try:
        exc_val.__traceback__ = exc_tb
        raise exc_val
    except:
        exc_type2,exc_val2,exc_tb2 = sys.exc_info()
    assert exc_type is exc_type2
    assert exc_val is exc_val2
    assert exc_tb is exc_tb2.tb_next

def test_sets_traceback():
    import types
    try:
        raise IndexError()
    except IndexError as e:
        assert isinstance(e.__traceback__, types.TracebackType)
    else:
        fail("No exception raised")

def test_accepts_traceback():
    import sys
    def get_tb():
        try:
            raise OSError()
        except:
            return sys.exc_info()[2]
    tb = get_tb()
    try:
        raise IndexError().with_traceback(tb)
    except IndexError as e:
        assert e.__traceback__ != tb
        assert e.__traceback__.tb_next is tb
    else:
        fail("No exception raised")

def test_invalid_reraise():
    try:
        raise
    except RuntimeError as e:
        assert "No active exception" in str(e)
    else:
        fail("Expected RuntimeError")

def test_invalid_cause():
    try:
        raise IndexError from 5
    except TypeError as e:
        assert "exception cause" in str(e)
    else:
        fail("Expected TypeError")

def test_invalid_cause_setter():
    class Setter(BaseException):
        def set_cause(self, cause):
            self.cause = cause
        __cause__ = property(fset=set_cause)
    try:
        raise Setter from 5
    except TypeError as e:
        assert "exception cause" in str(e)
    else:
        fail("Expected TypeError")
