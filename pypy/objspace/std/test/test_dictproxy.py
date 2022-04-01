class AppTestUserObject:
    def test_dictproxy(self):
        class NotEmpty(object):
            a = 1
        NotEmpty.a = 1
        NotEmpty.a = 1
        NotEmpty.a = 1
        NotEmpty.a = 1
        assert 'a' in NotEmpty.__dict__
        assert 'a' in NotEmpty.__dict__.keys()
        assert 'b' not in NotEmpty.__dict__
        assert NotEmpty.__dict__.get("b") is None
        raises(TypeError, "NotEmpty.__dict__['b'] = 4")
        raises(TypeError, 'NotEmpty.__dict__[15] = "y"')
        raises(TypeError, 'del NotEmpty.__dict__[15]')

        raises(AttributeError, 'NotEmpty.__dict__.setdefault')

    def test_dictproxy_getitem(self):
        class NotEmpty(object):
            a = 1
        assert 'a' in NotEmpty.__dict__
        class substr(str):
            pass
        assert substr('a') in NotEmpty.__dict__

    def test_dictproxyeq(self):
        class a(object):
            pass
        class b(a):
            stuff = 42
        class c(a):
            stuff = 42
        assert a.__dict__ == a.__dict__
        assert a.__dict__ != b.__dict__
        assert a.__dict__ != {'123': '456'}
        assert {'123': '456'} != a.__dict__
        assert b.__dict__ == c.__dict__

    def test_str_repr(self):
        class a(object):
            pass
        s1 = repr(a.__dict__)
        assert s1.startswith('mappingproxy({') and s1.endswith('})')
        s2 = str(a.__dict__)
        assert s1 == 'mappingproxy(%s)' % s2

    def test_immutable_dict_on_builtin_type(self):
        raises(TypeError, "int.__dict__['a'] = 1")
        raises((AttributeError, TypeError), "int.__dict__.popitem()")
        raises((AttributeError, TypeError), "int.__dict__.clear()")

    def test_mappingproxy(self):
        dictproxy = type(int.__dict__)
        assert dictproxy is not dict
        assert dictproxy.__name__ == 'mappingproxy'
        raises(TypeError, dictproxy)
        mapping = dict(a=1, b=2, c=3)
        proxy = dictproxy(mapping)
        assert proxy['a'] == 1
        assert 'a' in proxy
        assert 'z' not in proxy
        assert repr(proxy) == 'mappingproxy(%r)' % mapping
        assert proxy.keys() == mapping.keys()
        raises(TypeError, "proxy['a'] = 4")
        raises(TypeError, "del proxy['a']")
        raises(AttributeError, "proxy.clear()")
        #
        class D(dict):
            def copy(self): return 3
        proxy = dictproxy(D(a=1, b=2, c=3))
        assert proxy.copy() == 3
        #
        raises(TypeError, dictproxy, 3)
        raises(TypeError, dictproxy, [3])
        #
        {}.update(proxy)

    def test_or(self):
        dictproxy = type(int.__dict__)
        mapping = orig = dictproxy(dict(a=1, b=2, c=3))
        mapping2 = mapping | dict(a=2, d=5)
        assert type(mapping2) is dict
        assert mapping2 == dict(a=2, b=2, c=3, d=5)

        mapping2 = mapping | dictproxy(dict(a=2, d=5))
        assert type(mapping2) is dict
        assert mapping2 == dict(a=2, b=2, c=3, d=5)

        # __ior__ raises
        with raises(TypeError):
            mapping = dictproxy(dict(a=1, b=2, c=3))
            mapping |= 'not a dict'
            
        # __ror__
        mapping = dictproxy(dict(a=1, b=2, c=3))
        res = dict(a=2, d=5) | mapping
        assert res == dict(a=1, b=2, c=3, d=5)


    def test_reversed(self):
        dictproxy = type(int.__dict__)
        mapping = dictproxy(dict(a=1, b=2, c=3))
        assert list(reversed(mapping)) == list(reversed(list(mapping)))


class AppTestUserObjectMethodCache(AppTestUserObject):
    spaceconfig = {"objspace.std.withmethodcachecounter": True}
