import py


py.test.skip("XXX: crashes: issue 1773")


class AppTestCopy:
    spaceconfig = dict(usemodules=['_continuation'],
                       continuation=True)

    def test_basic_setup(self):
        from _continuation import continulet
        lst = [4]
        co = continulet(lst.append)
        assert lst == [4]
        res = co.switch()
        assert res is None
        assert lst == [4, co]

    def test_copy_continulet_not_started(self):
        from _continuation import continulet, error
        import copy
        lst = []
        co = continulet(lst.append)
        co2, lst2 = copy.deepcopy((co, lst))
        #
        assert lst == []
        co.switch()
        assert lst == [co]
        #
        assert lst2 == []
        co2.switch()
        assert lst2 == [co2]

    def test_copy_continulet_not_started_multiple(self):
        from _continuation import continulet, error
        import copy
        lst = []
        co = continulet(lst.append)
        co2, lst2 = copy.deepcopy((co, lst))
        co3, lst3 = copy.deepcopy((co, lst))
        co4, lst4 = copy.deepcopy((co, lst))
        #
        assert lst == []
        co.switch()
        assert lst == [co]
        #
        assert lst2 == []
        co2.switch()
        assert lst2 == [co2]
        #
        assert lst3 == []
        co3.switch()
        assert lst3 == [co3]
        #
        assert lst4 == []
        co4.switch()
        assert lst4 == [co4]

    def test_copy_continulet_real(self):
        import types, sys
        mod = types.ModuleType('test_copy_continulet_real')
        sys.modules['test_copy_continulet_real'] = mod
        exec('''if 1:
            from _continuation import continulet
            import copy
            def f(co, x):
                co.switch(x + 1)
                co.switch(x + 2)
                return x + 3
            co = continulet(f, 40)
            res = co.switch()
            assert res == 41
            co2 = copy.deepcopy(co)
            #
            res = co2.switch()
            assert res == 42
            assert co2.is_pending()
            res = co2.switch()
            assert res == 43
            assert not co2.is_pending()
            #
            res = co.switch()
            assert res == 42
            assert co.is_pending()
            res = co.switch()
            assert res == 43
            assert not co.is_pending()
        ''',  mod.__dict__)

    def test_copy_continulet_already_finished(self):
        from _continuation import continulet, error
        import copy
        lst = []
        co = continulet(lst.append)
        co.switch()
        co2 = copy.deepcopy(co)
        assert not co.is_pending()
        assert not co2.is_pending()
        raises(error, co.__init__, lst.append)
        raises(error, co2.__init__, lst.append)
        raises(error, co.switch)
        raises(error, co2.switch)


class AppTestPickle:
    version = 0
    spaceconfig = {
        "usemodules": ['_continuation', 'struct', 'binascii'],
        "continuation": True,
    }

    def setup_class(cls):
        cls.space.appexec([], """():
            global continulet, A, __name__

            import sys
            __name__ = 'test_pickle_continulet'
            thismodule = type(sys)(__name__)
            sys.modules[__name__] = thismodule

            from _continuation import continulet
            class A(continulet):
                pass

            thismodule.__dict__.update(globals())
        """)
        cls.w_version = cls.space.wrap(cls.version)

    def test_pickle_continulet_empty(self):
        from _continuation import continulet
        lst = [4]
        co = continulet.__new__(continulet)
        import pickle
        pckl = pickle.dumps(co, self.version)
        print(repr(pckl))
        co2 = pickle.loads(pckl)
        assert co2 is not co
        assert not co.is_pending()
        assert not co2.is_pending()
        # the empty unpickled coroutine can still be used:
        result = [5]
        co2.__init__(result.append)
        res = co2.switch()
        assert res is None
        assert result == [5, co2]

    def test_pickle_continulet_empty_subclass(self):
        from test_pickle_continulet import continulet, A
        lst = [4]
        co = continulet.__new__(A)
        co.foo = 'bar'
        co.bar = 'baz'
        import pickle
        pckl = pickle.dumps(co, self.version)
        print(repr(pckl))
        co2 = pickle.loads(pckl)
        assert co2 is not co
        assert not co.is_pending()
        assert not co2.is_pending()
        assert type(co) is type(co2) is A
        assert co.foo == co2.foo == 'bar'
        assert co.bar == co2.bar == 'baz'
        # the empty unpickled coroutine can still be used:
        result = [5]
        co2.__init__(result.append)
        res = co2.switch()
        assert res is None
        assert result == [5, co2]

    def test_pickle_continulet_not_started(self):
        from _continuation import continulet, error
        import pickle
        lst = []
        co = continulet(lst.append)
        pckl = pickle.dumps((co, lst))
        print(pckl)
        del co, lst
        for i in range(2):
            print('resume...')
            co2, lst2 = pickle.loads(pckl)
            assert lst2 == []
            co2.switch()
            assert lst2 == [co2]

    def test_pickle_continulet_real(self):
        import types, sys
        mod = types.ModuleType('test_pickle_continulet_real')
        sys.modules['test_pickle_continulet_real'] = mod
        mod.version = self.version
        exec('''if 1:
            from _continuation import continulet
            import pickle
            def f(co, x):
                co.switch(x + 1)
                co.switch(x + 2)
                return x + 3
            co = continulet(f, 40)
            res = co.switch()
            assert res == 41
            pckl = pickle.dumps(co, version)
            print(repr(pckl))
            co2 = pickle.loads(pckl)
            #
            res = co2.switch()
            assert res == 42
            assert co2.is_pending()
            res = co2.switch()
            assert res == 43
            assert not co2.is_pending()
            #
            res = co.switch()
            assert res == 42
            assert co.is_pending()
            res = co.switch()
            assert res == 43
            assert not co.is_pending()
        ''', mod.__dict__)

    def test_pickle_continulet_real_subclass(self):
        import types, sys
        mod = types.ModuleType('test_pickle_continulet_real_subclass')
        sys.modules['test_pickle_continulet_real_subclass'] = mod
        mod.version = self.version
        exec('''if 1:
            from _continuation import continulet
            import pickle
            class A(continulet):
                def __init__(self):
                    crash
            def f(co):
                co.switch(co.x + 1)
                co.switch(co.x + 2)
                return co.x + 3
            co = A.__new__(A)
            continulet.__init__(co, f)
            co.x = 40
            res = co.switch()
            assert res == 41
            pckl = pickle.dumps(co, version)
            print(repr(pckl))
            co2 = pickle.loads(pckl)
            #
            assert type(co2) is A
            res = co2.switch()
            assert res == 42
            assert co2.is_pending()
            res = co2.switch()
            assert res == 43
            assert not co2.is_pending()
            #
            res = co.switch()
            assert res == 42
            assert co.is_pending()
            res = co.switch()
            assert res == 43
            assert not co.is_pending()
        ''', mod.__dict__)


class AppTestPickle_v1(AppTestPickle):
    version = 1

class AppTestPickle_v2(AppTestPickle):
    version = 2
