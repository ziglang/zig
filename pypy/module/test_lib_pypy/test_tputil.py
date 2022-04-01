class AppTest_make_proxy:
    spaceconfig = {"objspace.std.withtproxy": True}

    def test_errors(self):
        from tputil import make_proxy
        raises(TypeError, "make_proxy(None)")
        raises(TypeError, "make_proxy(None, None)")
        def f(): pass
        raises(TypeError, "make_proxy(f)")
        raises(TypeError, "make_proxy(f, None, None)")

    def test_repr(self):
        from tputil import make_proxy

        class A(object):
            def append(self, item):
                pass

        l = []
        def func(operation):
            l.append(repr(operation))
            return operation.delegate()
        tp = make_proxy(func, obj=A())
        tp.append(3)
        for rep in l:
            assert isinstance(rep, str)
            assert rep.find("append") != -1

    def test_virtual_proxy(self):
        skip("XXX seems that proxies are more than a bit broken by now, but noone cares")
        class A(object):
            def __getitem__(self, item):
                pass

            def __getslice__(self, start, stop):
                xxx

        from tputil import make_proxy
        l = []

        def f(*args):
            print(args)

        tp = make_proxy(f, type=A)
        #tp.__getslice__(0, 1)
        tp[0:1]
        assert len(l) == 1
        assert l[0].opname == '__getitem__'

    def test_simple(self):
        from tputil import make_proxy

        class A(object):
            def append(self, item):
                pass

        record = []
        def func(operation):
            record.append(operation)
            return operation.delegate()
        l = make_proxy(func, obj=A())
        l.append(1)
        assert len(record) == 1
        i1, = record
        assert i1.opname == '__getattribute__'

    def test_missing_attr(self):
        from tputil import make_proxy

        class A(object):
            pass

        def func(operation):
            return operation.delegate()
        l = make_proxy(func, obj=A())
        raises(AttributeError, "l.asdasd")

    def test_proxy_double(self):
        from tputil import make_proxy

        class A(object):
            def append(self, item):
                pass
        r1 = []
        r2 = []
        def func1(operation):
            r1.append(operation)
            return operation.delegate()
        def func2(operation):
            r2.append(operation)
            return operation.delegate()

        l = make_proxy(func1, obj=A())
        l2 = make_proxy(func2, obj=l)
        assert not r1 and not r2
        l2.append
        assert len(r2) == 1
        assert r2[0].opname == '__getattribute__'
        assert len(r1) == 2
        assert r1[0].opname == '__getattribute__'
        assert r1[0].args[0] == '__getattribute__'
        assert r1[1].opname == '__getattribute__'
        assert r1[1].args[0] == 'append'

    def test_proxy_inplace_add(self):
        r = []
        from tputil import make_proxy

        class A(object):
            def __iadd__(self, other):
                return self

        def func1(operation):
            r.append(operation)
            return operation.delegate()

        l2 = make_proxy(func1, obj=A())
        l = l2
        l += [3]
        assert l is l2
