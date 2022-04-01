import py
from pypy.interpreter import executioncontext
from pypy.interpreter.error import OperationError

class Finished(Exception):
    pass


class TestExecutionContext:
    def test_action(self):

        class DemoAction(executioncontext.AsyncAction):
            counter = 0
            def perform(self, ec, frame):
                self.counter += 1
                if self.counter == 10:
                    raise Finished

        space = self.space
        a1 = DemoAction(space)
        for i in range(20):
            # assert does not raise:
            space.appexec([], """():
                n = 5
                return n + 2
            """)
        try:
            for i in range(20):
                a1.fire()
                space.appexec([], """():
                    n = 5
                    return n + 2
                """)
                assert a1.counter == i + 1
        except Finished:
            pass
        assert i == 9

    def test_action_queue(self):
        events = []

        class Action1(executioncontext.AsyncAction):
            def perform(self, ec, frame):
                events.append('one')

        class Action2(executioncontext.AsyncAction):
            def perform(self, ec, frame):
                events.append('two')

        space = self.space
        a1 = Action1(space)
        a2 = Action2(space)
        a1.fire()
        a2.fire()
        space.appexec([], """():
            n = 5
            return n + 2
        """)
        assert events == ['one', 'two']
        #
        events[:] = []
        a1.fire()
        space.appexec([], """():
            n = 5
            return n + 2
        """)
        assert events == ['one']

    def test_fire_inside_perform(self):
        # test what happens if we call AsyncAction.fire() while we are in the
        # middle of an AsyncAction.perform(). In particular, this happens when
        # PyObjectDeallocAction.fire() is called by rawrefcount: see issue
        # 2805
        events = []

        class Action1(executioncontext.AsyncAction):
            _count = 0

            def perform(self, ec, frame):
                events.append('one')
                if self._count == 0:
                    # a1 is no longer in the queue, so it will be enqueued
                    a1.fire()
                    #
                    # a2 is still in the queue, so the fire() is ignored and
                    # it's performed in its normal order, i.e. BEFORE a3
                    a2.fire()
                self._count += 1

        class Action2(executioncontext.AsyncAction):
            def perform(self, ec, frame):
                events.append('two')

        class Action3(executioncontext.AsyncAction):
            def perform(self, ec, frame):
                events.append('three')

        space = self.space
        a1 = Action1(space)
        a2 = Action2(space)
        a3 = Action3(space)
        a1.fire()
        a2.fire()
        a3.fire()
        space.appexec([], """():
            pass
        """)
        assert events == ['one', 'two', 'three', 'one']


    def test_periodic_action(self):
        from pypy.interpreter.executioncontext import ActionFlag

        class DemoAction(executioncontext.PeriodicAsyncAction):
            counter = 0
            def perform(self, ec, frame):
                self.counter += 1
                print '->', self.counter
                if self.counter == 3:
                    raise Finished

        space = self.space
        a2 = DemoAction(space)
        try:
            space.actionflag.setcheckinterval(100)
            space.actionflag.register_periodic_action(a2, True)
            try:
                for i in range(500):
                    space.appexec([], """():
                        n = 5
                        return n + 2
                    """)
            except Finished:
                pass
        finally:
            space.actionflag = ActionFlag()   # reset to default
        assert 10 < i < 110

    def test_llprofile(self):
        l = []

        def profile_func(space, w_arg, frame, event, w_aarg):
            assert w_arg is space.w_None
            l.append(event)

        space = self.space
        space.getexecutioncontext().setllprofile(profile_func, space.w_None)
        space.appexec([], """():
        pass
        """)
        space.getexecutioncontext().setllprofile(None, None)
        assert l[-4:] == ['call', 'return', 'call', 'return']

    def test_llprofile_c_call(self):
        from pypy.interpreter.function import Function, Method
        l = []
        seen = []
        space = self.space

        def profile_func(space, w_arg, frame, event, w_func):
            assert w_arg is space.w_None
            l.append(event)
            if event == 'c_call':
                seen.append(w_func)

        def check_snippet(snippet, expected_c_call):
            del l[:]
            del seen[:]
            space.getexecutioncontext().setllprofile(profile_func,
                                                     space.w_None)
            space.appexec([], """():
            %s
            return
            """ % snippet)
            space.getexecutioncontext().setllprofile(None, None)
            assert l[-6:] == ['call', 'return', 'call', 'c_call', 'c_return', 'return']
            if isinstance(seen[-1], Method):
                w_class = space.type(seen[-1].w_instance)
                found = 'method %s of %s' % (
                    seen[-1].w_function.name,
                    w_class.getname(space))
            else:
                assert isinstance(seen[-1], Function)
                found = 'builtin %s' % seen[-1].name
            assert found == expected_c_call

        check_snippet('l = []; l.append(42)', 'method append of list')
        check_snippet('max(1, 2)', 'builtin max')
        check_snippet('args = (1, 2); max(*args)', 'builtin max')
        check_snippet('max(1, 2, **{})', 'builtin max')
        check_snippet('args = (1, 2); max(*args, **{})', 'builtin max')
        check_snippet('abs(val=0)', 'builtin abs')

    def test_llprofile_c_exception(self):
        l = []

        def profile_func(space, w_arg, frame, event, w_aarg):
            assert w_arg is space.w_None
            l.append(event)

        space = self.space
        space.getexecutioncontext().setllprofile(profile_func, space.w_None)

        def check_snippet(snippet):
            space.appexec([], """():
            try:
                %s
            except:
                pass
            return
            """ % snippet)
            space.getexecutioncontext().setllprofile(None, None)
            assert l[-6:] == ['call', 'return', 'call', 'c_call', 'c_exception', 'return']

        check_snippet('d = {}; d.__getitem__(42)')

    def test_c_call_setprofile_outer_frame(self):
        space = self.space
        w_events = space.appexec([], """():
        import sys
        l = []
        def profile(frame, event, arg):
            l.append(event)

        def foo():
            sys.setprofile(profile)

        def bar():
            foo()
            max(1, 2)

        bar()
        sys.setprofile(None)
        return l
        """)
        events = space.unwrap(w_events)
        assert events == ['return', 'c_call', 'c_return', 'return', 'c_call']

    def test_c_call_setprofile_kwargs(self):
        space = self.space
        w_events = space.appexec([], """():
        import sys
        l = []
        def profile(frame, event, arg):
            l.append(event)

        def bar():
            sys.setprofile(profile)
            [].sort(reverse=True)
            sys.setprofile(None)

        bar()
        return l
        """)
        events = space.unwrap(w_events)
        assert events == ['c_call', 'c_return', 'c_call']

    def test_c_call_setprofile_strange_method(self):
        space = self.space
        w_events = space.appexec([], """():
        import sys
        class A(object):
            def __init__(self, value):
                self.value = value
            def meth(self):
                pass
        MethodType = type(A(0).meth)
        strangemeth = MethodType(A, 42)
        l = []
        def profile(frame, event, arg):
            l.append(event)

        def foo():
            sys.setprofile(profile)

        def bar():
            foo()
            strangemeth()

        bar()
        sys.setprofile(None)
        return l
        """)
        events = space.unwrap(w_events)
        assert events == ['return', 'call', 'return', 'return', 'c_call']

    def test_c_call_profiles_immediately(self):
        space = self.space
        w_events = space.appexec([], """():
        import sys
        l = []
        def profile(frame, event, arg):
            l.append((event, arg))

        def bar():
            sys.setprofile(profile)
            max(3, 4)

        bar()
        sys.setprofile(None)
        return l
        """)
        events = space.unwrap(w_events)
        assert [i[0] for i in events] == ['c_call', 'c_return', 'return', 'c_call']
        assert events[0][1] == events[1][1]

    def test_profile_and_exception(self):
        space = self.space
        w_res = space.appexec([], """():
        l = []

        def profile(*args):
            l.append(sys.exc_info()[0])

        import sys
        try:
            sys.setprofile(profile)
            try:
                x
            except:
                expected = sys.exc_info()[0]
                assert expected is NameError
                for i in l:
                    assert expected is l[0]
        finally:
            sys.setprofile(None)
        """)


class AppTestProfile:

    def test_return(self):
        import sys
        l = []
        def profile(frame, event, arg):
            l.append((event, arg))

        def bar(x):
            return 40 + x

        sys.setprofile(profile)
        bar(2)
        sys.setprofile(None)
        assert l == [('call', None),
                     ('return', 42),
                     ('c_call', sys.setprofile)], repr(l)

    def test_c_return(self):
        import sys
        l = []
        def profile(frame, event, arg):
            l.append((event, arg))

        sys.setprofile(profile)
        max(2, 42)
        sys.setprofile(None)
        assert l == [('c_call', max),
                     ('c_return', max),
                     ('c_call', sys.setprofile)], repr(l)

    def test_exception(self):
        import sys
        l = []
        def profile(frame, event, arg):
            l.append((event, arg))

        def f():
            raise ValueError("foo")

        sys.setprofile(profile)
        try:
            f()
        except ValueError:
            pass
        sys.setprofile(None)
        assert l == [('call', None),
                     ('return', None),
                     ('c_call', sys.setprofile)], repr(l)

    def test_c_exception(self):
        import sys
        l = []
        def profile(frame, event, arg):
            l.append((event, arg))

        sys.setprofile(profile)
        try:
            divmod(5, 0)
        except ZeroDivisionError:
            pass
        sys.setprofile(None)
        assert l == [('c_call', divmod),
                     ('c_exception', divmod),
                     ('c_call', sys.setprofile)], repr(l)
