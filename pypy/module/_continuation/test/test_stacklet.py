import pytest
import os
from rpython.rlib.rvmprof.test.support import fakevmprof
from pypy.interpreter.gateway import interp2app
from pypy.module._continuation.test.support import BaseAppTest

@pytest.mark.usefixtures('app_fakevmprof')
class AppTestStacklet(BaseAppTest):
    def setup_class(cls):
        BaseAppTest.setup_class.im_func(cls)
        cls.w_translated = cls.space.wrap(
            os.path.join(os.path.dirname(__file__),
                         'test_translated.py'))
        cls.w_stack = cls.space.appexec([], """():
            import sys
            def stack(f=None):
                '''
                get the call-stack of the caller or the specified frame
                '''
                if f is None:
                    f = sys._getframe(1)
                res = []
                seen = set()
                while f:
                    if f in seen:
                        # frame cycle
                        res.append('...')
                        break
                    if f.f_code.co_name == '<module>':
                        # if we are running with -A, cut all the stack above
                        # the test function
                        break
                    seen.add(f)
                    res.append(f.f_code.co_name)
                    f = f.f_back
                #print res
                return res
            return stack
       """)
        cls.w_appdirect = cls.space.wrap(cls.runappdirect)


    @pytest.fixture
    def app_fakevmprof(self, fakevmprof):
        """
        This is automaticaly re-initialized for every method: thanks to
        fakevmprof's finalizer, it checks that we called {start,stop}_sampling
        the in pairs
        """
        w = self.space.wrap
        i2a = interp2app
        def is_sampling_enabled(space):
            return space.wrap(fakevmprof.is_sampling_enabled)
        self.w_is_sampling_enabled = w(i2a(is_sampling_enabled))
        #
        def start_sampling(space):
            fakevmprof.start_sampling()
        self.w_start_sampling = w(i2a(start_sampling))
        #
        def stop_sampling(space):
            fakevmprof.stop_sampling()
        self.w_stop_sampling = w(i2a(stop_sampling))


    def test_new_empty(self):
        from _continuation import continulet
        #
        def empty_callback(c):
            never_called
        #
        c = continulet(empty_callback)
        assert type(c) is continulet

    def test_call_empty(self):
        from _continuation import continulet
        #
        def empty_callback(c1):
            assert c1 is c
            seen.append(1)
            return 42
        #
        seen = []
        c = continulet(empty_callback)
        res = c.switch()
        assert res == 42
        assert seen == [1]

    def test_no_double_init(self):
        from _continuation import continulet, error
        #
        def empty_callback(c1):
            never_called
        #
        c = continulet(empty_callback)
        raises(error, c.__init__, empty_callback)

    def test_no_init_after_started(self):
        from _continuation import continulet, error
        #
        def empty_callback(c1):
            raises(error, c1.__init__, empty_callback)
            return 42
        #
        c = continulet(empty_callback)
        res = c.switch()
        assert res == 42

    def test_no_init_after_finished(self):
        from _continuation import continulet, error
        #
        def empty_callback(c1):
            return 42
        #
        c = continulet(empty_callback)
        res = c.switch()
        assert res == 42
        raises(error, c.__init__, empty_callback)

    def test_propagate_exception(self):
        from _continuation import continulet
        #
        def empty_callback(c1):
            assert c1 is c
            seen.append(42)
            raise ValueError
        #
        seen = []
        c = continulet(empty_callback)
        raises(ValueError, c.switch)
        assert seen == [42]

    def test_callback_with_arguments(self):
        from _continuation import continulet
        #
        def empty_callback(c1, *args, **kwds):
            seen.append(c1)
            seen.append(args)
            seen.append(kwds)
            return 42
        #
        seen = []
        c = continulet(empty_callback, 42, 43, foo=44, bar=45)
        res = c.switch()
        assert res == 42
        assert seen == [c, (42, 43), {'foo': 44, 'bar': 45}]

    def test_switch(self):
        from _continuation import continulet
        #
        def switchbackonce_callback(c):
            seen.append(1)
            res = c.switch('a')
            assert res == 'b'
            seen.append(3)
            return 'c'
        #
        seen = []
        c = continulet(switchbackonce_callback)
        seen.append(0)
        res = c.switch()
        assert res == 'a'
        seen.append(2)
        res = c.switch('b')
        assert res == 'c'
        assert seen == [0, 1, 2, 3]

    def test_initial_switch_must_give_None(self):
        from _continuation import continulet
        #
        def empty_callback(c):
            return 'ok'
        #
        c = continulet(empty_callback)
        res = c.switch(None)
        assert res == 'ok'
        #
        c = continulet(empty_callback)
        raises(TypeError, c.switch, 'foo')  # "can't send non-None value"

    def test_continuation_error(self):
        from _continuation import continulet, error
        #
        def empty_callback(c):
            return 42
        #
        c = continulet(empty_callback)
        c.switch()
        e = raises(error, c.switch)
        assert str(e.value) == "continulet already finished"

    def test_go_depth2(self):
        from _continuation import continulet
        #
        def depth2(c):
            seen.append(3)
            return 4
        #
        def depth1(c):
            seen.append(1)
            c2 = continulet(depth2)
            seen.append(2)
            res = c2.switch()
            seen.append(res)
            return 5
        #
        seen = []
        c = continulet(depth1)
        seen.append(0)
        res = c.switch()
        seen.append(res)
        assert seen == [0, 1, 2, 3, 4, 5]

    def test_exception_depth2(self):
        from _continuation import continulet
        #
        def depth2(c):
            seen.append(2)
            raise ValueError
        #
        def depth1(c):
            seen.append(1)
            try:
                continulet(depth2).switch()
            except ValueError:
                seen.append(3)
            return 4
        #
        seen = []
        c = continulet(depth1)
        res = c.switch()
        seen.append(res)
        assert seen == [1, 2, 3, 4]

    def test_exception_with_switch(self):
        from _continuation import continulet
        #
        def depth1(c):
            seen.append(1)
            c.switch()
            seen.append(3)
            raise ValueError
        #
        seen = []
        c = continulet(depth1)
        seen.append(0)
        c.switch()
        seen.append(2)
        raises(ValueError, c.switch)
        assert seen == [0, 1, 2, 3]

    def test_is_pending(self):
        from _continuation import continulet
        #
        def switchbackonce_callback(c):
            assert c.is_pending()
            res = c.switch('a')
            assert res == 'b'
            assert c.is_pending()
            return 'c'
        #
        c = continulet.__new__(continulet)
        assert not c.is_pending()
        c.__init__(switchbackonce_callback)
        assert c.is_pending()
        res = c.switch()
        assert res == 'a'
        assert c.is_pending()
        res = c.switch('b')
        assert res == 'c'
        assert not c.is_pending()

    def test_switch_alternate(self):
        from _continuation import continulet
        #
        def func_lower(c):
            res = c.switch('a')
            assert res == 'b'
            res = c.switch('c')
            assert res == 'd'
            return 'e'
        #
        def func_upper(c):
            res = c.switch('A')
            assert res == 'B'
            res = c.switch('C')
            assert res == 'D'
            return 'E'
        #
        c_lower = continulet(func_lower)
        c_upper = continulet(func_upper)
        res = c_lower.switch()
        assert res == 'a'
        res = c_upper.switch()
        assert res == 'A'
        res = c_lower.switch('b')
        assert res == 'c'
        res = c_upper.switch('B')
        assert res == 'C'
        res = c_lower.switch('d')
        assert res == 'e'
        res = c_upper.switch('D')
        assert res == 'E'

    def test_switch_not_initialized(self):
        from _continuation import continulet
        c0 = continulet.__new__(continulet)
        res = c0.switch()
        assert res is None
        res = c0.switch(123)
        assert res == 123
        raises(ValueError, c0.throw, ValueError)

    def test_exception_with_switch_depth2(self):
        from _continuation import continulet
        #
        def depth2(c):
            seen.append(4)
            c.switch()
            seen.append(6)
            raise ValueError
        #
        def depth1(c):
            seen.append(1)
            c.switch()
            seen.append(3)
            c2 = continulet(depth2)
            c2.switch()
            seen.append(5)
            raises(ValueError, c2.switch)
            assert not c2.is_pending()
            seen.append(7)
            assert c.is_pending()
            raise KeyError
        #
        seen = []
        c = continulet(depth1)
        c.switch()
        seen.append(2)
        raises(KeyError, c.switch)
        assert not c.is_pending()
        assert seen == [1, 2, 3, 4, 5, 6, 7]

    def test_random_switching(self):
        from _continuation import continulet
        #
        seen = []
        #
        def t1(c1):
            seen.append(3)
            res = c1.switch()
            seen.append(6)
            return res
        #
        def s1(c1, n):
            seen.append(2)
            assert n == 123
            c2 = t1(c1)
            seen.append(7)
            res = c1.switch('a') + 1
            seen.append(10)
            return res
        #
        def s2(c2, c1):
            seen.append(5)
            res = c1.switch(c2)
            seen.append(8)
            assert res == 'a'
            res = c2.switch('b') + 2
            seen.append(12)
            return res
        #
        def f():
            seen.append(1)
            c1 = continulet(s1, 123)
            c2 = continulet(s2, c1)
            c1.switch()
            seen.append(4)
            res = c2.switch()
            seen.append(9)
            assert res == 'b'
            res = c1.switch(1000)
            seen.append(11)
            assert res == 1001
            res = c2.switch(2000)
            seen.append(13)
            return res
        #
        res = f()
        assert res == 2002
        assert seen == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

    def test_f_back(self):
        import sys
        from _continuation import continulet
        stack = self.stack
        #
        def bar(c):
            assert stack() == ['bar', 'foo', 'test_f_back']
            c.switch(sys._getframe(0))
            c.switch(sys._getframe(0).f_back)
            c.switch(sys._getframe(1))
            #
            assert stack() == ['bar', 'foo', 'main', 'test_f_back']
            c.switch(sys._getframe(1).f_back)
            #
            assert stack() == ['bar', 'foo', 'main2', 'test_f_back']
            assert sys._getframe(2) is f3_foo.f_back
            c.switch(sys._getframe(2))
        def foo(c):
            bar(c)
        #
        assert stack() == ['test_f_back']
        c = continulet(foo)
        f1_bar = c.switch()
        assert f1_bar.f_code.co_name == 'bar'
        f2_foo = c.switch()
        assert f2_foo.f_code.co_name == 'foo'
        f3_foo = c.switch()
        assert f3_foo is f2_foo
        assert f1_bar.f_back is f3_foo
        #
        def main():
            f4_main = c.switch()
            assert f4_main.f_code.co_name == 'main'
            assert f3_foo.f_back is f1_bar    # not running, so a loop
            assert stack() == ['main', 'test_f_back']
            assert stack(f1_bar) == ['bar', 'foo', '...']
        #
        def main2():
            f5_main2 = c.switch()
            assert f5_main2.f_code.co_name == 'main2'
            assert f3_foo.f_back is f1_bar    # not running, so a loop
            assert stack(f1_bar) == ['bar', 'foo', '...']
        #
        main()
        main2()
        res = c.switch()
        assert res is None
        assert f3_foo.f_back is None

    def test_traceback_is_complete(self):
        import sys
        from _continuation import continulet
        #
        def g():
            raise KeyError
        def f(c):
            g()
        #
        def do(c):
            c.switch()
        #
        c = continulet(f)
        try:
            do(c)
        except KeyError:
            tb = sys.exc_info()[2]
        else:
            raise AssertionError("should have raised!")
        #
        assert tb.tb_next.tb_frame.f_code.co_name == 'do'
        assert tb.tb_next.tb_next.tb_frame.f_code.co_name == 'f'
        assert tb.tb_next.tb_next.tb_next.tb_frame.f_code.co_name == 'g'
        assert tb.tb_next.tb_next.tb_next.tb_next is None

    def test_switch2_simple(self):
        from _continuation import continulet
        #
        def f1(c1):
            res = c1.switch('started 1')
            assert res == 'a'
            res = c1.switch('b', to=c2)
            assert res == 'c'
            return 42
        def f2(c2):
            res = c2.switch('started 2')
            assert res == 'b'
            res = c2.switch('c', to=c1)
            not_reachable
        #
        c1 = continulet(f1)
        c2 = continulet(f2)
        res = c1.switch()
        assert res == 'started 1'
        res = c2.switch()
        assert res == 'started 2'
        res = c1.switch('a')
        assert res == 42

    def test_switch2_pingpong(self):
        from _continuation import continulet
        #
        def f1(c1):
            res = c1.switch('started 1')
            assert res == 'go'
            for i in range(10):
                res = c1.switch(i, to=c2)
                assert res == 100 + i
            return 42
        def f2(c2):
            res = c2.switch('started 2')
            for i in range(10):
                assert res == i
                res = c2.switch(100 + i, to=c1)
            not_reachable
        #
        c1 = continulet(f1)
        c2 = continulet(f2)
        res = c1.switch()
        assert res == 'started 1'
        res = c2.switch()
        assert res == 'started 2'
        res = c1.switch('go')
        assert res == 42

    def test_switch2_more_complex(self):
        from _continuation import continulet
        #
        def f1(c1):
            res = c1.switch(to=c2)
            assert res == 'a'
            res = c1.switch('b', to=c2)
            assert res == 'c'
            return 41
        def f2(c2):
            res = c2.switch('a', to=c1)
            assert res == 'b'
            return 42
        #
        c1 = continulet(f1)
        c2 = continulet(f2)
        res = c1.switch()
        assert res == 42
        assert not c2.is_pending()    # finished by returning 42
        res = c1.switch('c')
        assert res == 41

    def test_switch2_no_op(self):
        from _continuation import continulet
        #
        def f1(c1):
            res = c1.switch('a', to=c1)
            assert res == 'a'
            return 42
        #
        c1 = continulet(f1)
        res = c1.switch()
        assert res == 42

    def test_switch2_immediately_away(self):
        from _continuation import continulet
        #
        def f1(c1):
            print('in f1')
            return 'm'
        #
        def f2(c2):
            res = c2.switch('z')
            print('got there!')
            assert res == 'a'
            return None
        #
        c1 = continulet(f1)
        c2 = continulet(f2)
        res = c2.switch()
        assert res == 'z'
        assert c1.is_pending()
        assert c2.is_pending()
        print('calling!')
        res = c1.switch('a', to=c2)
        print('back')
        assert res == 'm'

    def test_switch2_immediately_away_corner_case(self):
        from _continuation import continulet
        #
        def f1(c1):
            this_is_never_seen
        #
        def f2(c2):
            res = c2.switch('z')
            assert res is None
            return 'b'    # this goes back into the caller, which is f1,
                          # but f1 didn't start yet, so a None-value value
                          # has nowhere to go to...
        c1 = continulet(f1)
        c2 = continulet(f2)
        res = c2.switch()
        assert res == 'z'
        raises(TypeError, c1.switch, to=c2)  # "can't send non-None value"

    def test_switch2_not_initialized(self):
        from _continuation import continulet
        c0 = continulet.__new__(continulet)
        c0bis = continulet.__new__(continulet)
        res = c0.switch(123, to=c0)
        assert res == 123
        res = c0.switch(123, to=c0bis)
        assert res == 123
        raises(ValueError, c0.throw, ValueError, to=c0)
        raises(ValueError, c0.throw, ValueError, to=c0bis)
        #
        def f1(c1):
            c1.switch('a')
            raises(ValueError, c1.switch, 'b')
            raises(KeyError, c1.switch, 'c')
            return 'd'
        c1 = continulet(f1)
        res = c0.switch(to=c1)
        assert res == 'a'
        res = c1.switch(to=c0)
        assert res == 'b'
        res = c1.throw(ValueError, to=c0)
        assert res == 'c'
        res = c0.throw(KeyError, to=c1)
        assert res == 'd'

    def test_switch2_already_finished(self):
        from _continuation import continulet, error
        #
        def f1(c1):
            not_reachable
        def empty_callback(c):
            return 42
        #
        c1 = continulet(f1)
        c2 = continulet(empty_callback)
        c2.switch()
        e = raises(error, c1.switch, to=c2)
        assert str(e.value) == "continulet already finished"

    def test_throw(self):
        import sys
        from _continuation import continulet
        #
        def f1(c1):
            try:
                c1.switch()
            except KeyError:
                res = "got keyerror"
            try:
                c1.switch(res)
            except IndexError as exc:
                e = exc
            try:
                c1.switch(e)
            except IndexError as exc:
                e2 = exc
            try:
                c1.switch(e2)
            except IndexError:
                c1.throw(*sys.exc_info())
            should_never_reach_here
        #
        c1 = continulet(f1)
        c1.switch()
        res = c1.throw(KeyError)
        assert res == "got keyerror"
        class FooError(IndexError):
            pass
        foo = FooError()
        res = c1.throw(foo)
        assert res is foo
        res = c1.throw(IndexError, foo)
        assert res is foo
        #
        def main():
            def do_raise():
                raise foo
            try:
                do_raise()
            except IndexError:
                tb = sys.exc_info()[2]
            try:
                c1.throw(IndexError, foo, tb)
            except IndexError:
                tb = sys.exc_info()[2]
            return tb
        #
        tb = main()
        assert tb.tb_frame.f_code.co_name == 'main'
        assert tb.tb_next.tb_frame.f_code.co_name == 'f1'
        assert tb.tb_next.tb_next.tb_frame.f_code.co_name == 'main'
        assert tb.tb_next.tb_next.tb_next.tb_frame.f_code.co_name == 'do_raise'
        assert tb.tb_next.tb_next.tb_next.tb_next.tb_frame.f_code.co_name == 'f1'
        assert tb.tb_next.tb_next.tb_next.tb_next.tb_next is None

    def test_throw_to_starting(self):
        from _continuation import continulet
        #
        def f1(c1):
            not_reached
        #
        c1 = continulet(f1)
        raises(IndexError, c1.throw, IndexError)

    def test_throw2_simple(self):
        from _continuation import continulet
        #
        def f1(c1):
            not_reached
        def f2(c2):
            try:
                c2.switch("ready")
            except IndexError:
                raise ValueError
        #
        c1 = continulet(f1)
        c2 = continulet(f2)
        res = c2.switch()
        assert res == "ready"
        assert c1.is_pending()
        assert c2.is_pending()
        raises(ValueError, c1.throw, IndexError, to=c2)
        assert not c1.is_pending()
        assert not c2.is_pending()

    def test_throw2_no_op(self):
        from _continuation import continulet
        #
        def f1(c1):
            raises(ValueError, c1.throw, ValueError, to=c1)
            return "ok"
        #
        c1 = continulet(f1)
        res = c1.switch()
        assert res == "ok"

    def test_permute(self):
        import sys
        from _continuation import continulet, permute
        #
        def f1(c1):
            res = c1.switch()
            assert res == "ok"
            return "done"
        #
        def f2(c2):
            assert sys._getframe(1).f_code.co_name == 'main'
            permute(c1, c2)
            assert sys._getframe(1).f_code.co_name == 'f1'
            return "ok"
        #
        c1 = continulet(f1)
        c2 = continulet(f2)
        def main():
            c1.switch()
            res = c2.switch()
            assert res == "done"
        main()

    def test_permute_noninitialized(self):
        from _continuation import continulet, permute
        permute(continulet.__new__(continulet))    # ignored
        permute(continulet.__new__(continulet),    # ignored
                continulet.__new__(continulet))

    def test_bug_finish_with_already_finished_stacklet(self):
        from _continuation import continulet, error
        # make an already-finished continulet
        c1 = continulet(lambda x: x)
        c1.switch()
        # make another continulet
        c2 = continulet(lambda x: x)
        # this switch is forbidden, because it causes a crash when c2 finishes
        raises(error, c1.switch, to=c2)

    def test_various_depths(self):
        skip("may fail on top of CPython")
        # run it from test_translated, but not while being actually translated
        d = {}
        execfile(self.translated, d)
        d['set_fast_mode']()
        d['test_various_depths']()

    def test_exc_info_doesnt_follow_continuations(self):
        import sys
        from _continuation import continulet
        #
        def f1(c1):
            return sys.exc_info()
        #
        c1 = continulet(f1)
        try:
            1 // 0
        except ZeroDivisionError:
            got = c1.switch()
        assert got == (None, None, None)

    def test_bug_issue1984(self):
        from _continuation import continulet, error

        c1 = continulet.__new__(continulet)
        c2 = continulet(lambda g: None)

        continulet.switch(c1, to=c2)
        raises(error, continulet.switch, c1, to=c2)

    def test_exc_info_save_restore(self):
        from _continuation import continulet
        import sys
        main = []

        def f(c):
            print("in f... 222")
            try:
                raise ValueError('fun')
            except:
                print("333")
                exc_info = sys.exc_info()
                print("444")
                c17650 = continulet(h)
                bd50.switch(to=c17650)
                print("back in f...")
                assert exc_info == sys.exc_info()

        def h(c):
            print("in h... 555")
            assert sys.exc_info() == (None, None, None)
            print("666")

        main = continulet.__new__(continulet)
        print(111)
        bd50 = continulet(f)
        main.switch(to=bd50)
        print(999)

    def test_sampling_inside_callback(self):
        if self.appdirect:
            # see also
            # extra_tests.test_vmprof_greenlet.test_sampling_inside_callback
            # for a "translated" version of this test
            skip("we can't run this until we have _vmprof.is_sampling_enabled")
        from _continuation import continulet
        #
        def my_callback(c1):
            assert self.is_sampling_enabled()
            return 42
        #
        try:
            self.start_sampling()
            assert self.is_sampling_enabled()
            c = continulet(my_callback)
            res = c.switch()
            assert res == 42
            assert self.is_sampling_enabled()
        finally:
            self.stop_sampling()
