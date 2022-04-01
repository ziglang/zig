import py

from rpython.rtyper.extfunc import register_external
from rpython.annotator.model import SomeInteger, SomeString, AnnotatorError
from rpython.annotator.annrpython import RPythonAnnotator
from rpython.annotator.policy import AnnotatorPolicy
from rpython.annotator.signature import SignatureError
from rpython.rtyper.test.test_llinterp import interpret

class TestExtFuncEntry:

    def test_basic(self):
        """
        A ExtFuncEntry provides an annotation for a function, no need to flow
        its graph.
        """
        def b(x):
            "NOT_RPYTHON"
            return eval("x+40")

        register_external(b, [int], result=int)

        def f():
            return b(2)

        policy = AnnotatorPolicy()
        a = RPythonAnnotator(policy=policy)
        s = a.build_types(f, [])
        assert isinstance(s, SomeInteger)

        res = interpret(f, [])
        assert res == 42

    def test_lltypeimpl(self):
        """
        interpret() calls lltypeimpl instead of of the function/
        """
        def c(y, x):
            yyy

        def llimpl(y, x):
            return y + x

        register_external(c, [int, int], result=int, llimpl=llimpl,
                          export_name='ccc')

        def f():
            return c(3, 4)

        res = interpret(f, [])
        assert res == 7

    def test_register_external_tuple_args(self):
        """
        Verify the annotation of a registered external function which takes a
        tuple argument.
        """

        def function_with_tuple_arg():
            """
            Dummy function which is declared via register_external to take a
            tuple as an argument so that register_external's behavior for
            tuple-taking functions can be verified.
            """
        register_external(function_with_tuple_arg, [(int,)], int)

        def f():
            return function_with_tuple_arg((1,))

        policy = AnnotatorPolicy()
        a = RPythonAnnotator(policy=policy)
        s = a.build_types(f, [])

        # Not a very good assertion, but at least it means _something_ happened.
        assert isinstance(s, SomeInteger)

    def test_register_external_return_goes_back(self):
        """
        Check whether it works to pass the same list from one external
        fun to another
        [bookkeeper and list joining issues]
        """
        def function_with_list():
            pass
        register_external(function_with_list, [[int]], int)

        def function_returning_list():
            pass
        register_external(function_returning_list, [], [int])

        def f():
            return function_with_list(function_returning_list())

        policy = AnnotatorPolicy()
        a = RPythonAnnotator(policy=policy)
        s = a.build_types(f, [])
        assert isinstance(s, SomeInteger)

    def test_str0(self):
        str0 = SomeString(no_nul=True)
        def os_open(s):
            pass
        register_external(os_open, [str0], None)
        def f(s):
            return os_open(s)
        policy = AnnotatorPolicy()
        a = RPythonAnnotator(policy=policy)
        a.build_types(f, [str])  # Does not raise
        assert a.translator.config.translation.check_str_without_nul == False
        # Now enable the str0 check, and try again with a similar function
        a.translator.config.translation.check_str_without_nul=True
        def g(s):
            return os_open(s)
        with py.test.raises(SignatureError):
            a.build_types(g, [str])
        a.build_types(g, [str0])  # Does not raise

    def test_list_of_str0_unchecked(self):
        str0 = SomeString(no_nul=True)

        def os_execve(l):
            pass

        register_external(os_execve, [[str0]], None)

        def f(l):
            return os_execve(l)

        policy = AnnotatorPolicy()
        a = RPythonAnnotator(policy=policy)
        assert a.translator.config.translation.check_str_without_nul == False
        a.build_types(f, [[str]])  # Does not raise
        # Now enable the str0 check, and try again with a similar function
        a.translator.config.translation.check_str_without_nul=True

        def g(l):
            return os_execve(l)

        with py.test.raises(AnnotatorError):
            # fails with TooLateForChange
            a.build_types(g, [[str]])
        a.build_types(g, [[str0]])  # Does not raise

    def test_register_external_llfakeimpl(self):
        def a(i):
            return i
        def a_llimpl(i):
            return i * 2
        def a_llfakeimpl(i):
            return i * 3
        register_external(a, [int], int, llimpl=a_llimpl,
                          llfakeimpl=a_llfakeimpl)
        def f(i):
            return a(i)

        res = interpret(f, [7])
        assert res == 21

        from rpython.translator.c.test.test_genc import compile
        fc = compile(f, [int])
        assert fc(7) == 14
