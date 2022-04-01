import py

from rpython.translator.translator import TranslationContext
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.llinterp import LLException
from rpython.rtyper.error import MissingRTypeOperation, TyperError


class MyException(Exception):
    pass

class MyStrangeException:   # no (Exception) here
    pass

def rtype(fn, argtypes=[]):
    t = TranslationContext()
    t.buildannotator().build_types(fn, argtypes)
    typer = t.buildrtyper()
    typer.specialize()
    #t.view()
    t.checkgraphs()
    return t

def test_simple():
    def g():
        raise MyException
    def dummyfn():
        try:
            return g()
        except MyException:
            pass

    rtype(dummyfn)


class TestException(BaseRtypingTest):
    def test_exception_with_arg(self):
        def g(n):
            raise IOError("test")
        def h(n):
            raise OSError(n, "?", None)
        def i(n):
            raise EnvironmentError(n, "?", "test")
        def j(n):
            raise IOError(0, "test")
        def k(n):
            raise OSError
        def f(n):
            try:
                g(n)
            except IOError as e:
                assert e.errno == 0
                assert e.strerror == "test"
                assert e.filename is None
            else:
                assert False
            try:
                h(n)
            except OSError as e:
                assert e.errno == 42
                assert e.strerror == "?"
                assert e.filename is None
            else:
                assert False
            try:
                i(n)
            except EnvironmentError as e:
                assert e.errno == 42
                assert e.strerror == "?"
                assert e.filename == "test"
            else:
                assert False
            try:
                j(n)
            except (IOError, OSError) as e:
                assert e.errno == 0
                assert e.strerror == "test"
                assert e.filename is None
            try:
                k(n)
            except EnvironmentError as e:
                assert e.errno == 0
                assert e.strerror is None
                assert e.filename is None
        self.interpret(f, [42])

    def test_catch_incompatible_class(self):
        class MyError(Exception):
            pass
        def h(x):
            pass
        def f(n):
            try:
                assert n < 10
            except MyError as operr:
                h(operr)
        res = self.interpret(f, [7])
        assert res is None

    def test_raise_and_catch_other(self):
        class BytecodeCorruption(Exception):
            pass
        class OperationError(Exception):
            def __init__(self, a):
                self.a = a
        def f(next_instr):
            if next_instr < 7:
                raise OperationError(next_instr)
            try:
                raise BytecodeCorruption()
            except OperationError as operr:
                next_instr -= operr.a
        py.test.raises(LLException, self.interpret, f, [10])

    def test_raise_prebuilt_and_catch_other(self):
        class BytecodeCorruption(Exception):
            pass
        class OperationError(Exception):
            def __init__(self, a):
                self.a = a
        bcerr = BytecodeCorruption()
        def f(next_instr):
            if next_instr < 7:
                raise OperationError(next_instr)
            try:
                raise bcerr
            except OperationError as operr:
                next_instr -= operr.a
        py.test.raises(LLException, self.interpret, f, [10])

    def test_catch_KeyboardInterrupt(self):
        def g(n):
            return n
        def f(n):
            try:
                return g(n)
            except KeyboardInterrupt:
                return -1
        res = self.interpret(f, [11])
        assert res == 11

    def test_pop_inside_try(self):
        class MyException(Exception):
            pass
        def f(n):
            lst = []
            lst.append(n)
            try:
                return lst.pop()
            except MyException:
                return -1
        res = self.interpret(f, [42])
        assert res == 42

    def test_cannot_raise_ll_exception(self):
        from rpython.rtyper.annlowlevel import cast_instance_to_base_ptr
        def g():
            e = OverflowError()
            lle = cast_instance_to_base_ptr(e)
            raise lle  # instead, must cast back from a base ptr to an instance
        def f():
            try:
                g()
            except OverflowError:
                return 42
        py.test.raises(MissingRTypeOperation, self.interpret, f, [])

    def test_cannot_raise_something_annotated_as_none(self):
        def g():
            return None
        def f():
            raise g()
        py.test.raises(TyperError, rtype, f)
