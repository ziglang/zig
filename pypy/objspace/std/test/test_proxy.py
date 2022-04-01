
""" test transparent proxy features
"""

import py

class AppProxyBasic(object):
    spaceconfig = {"objspace.std.withtproxy": True}

    def setup_method(self, meth):
        self.w_Controller = self.space.appexec([], """():
        class Controller(object):
            def __init__(self, obj):
                self.obj = obj

            def perform(self, name, *args, **kwargs):
                return getattr(self.obj, name)(*args, **kwargs)
        return Controller
        """)
        self.w_proxy = self.space.appexec([], """():
        from __pypy__ import tproxy
        return tproxy
        """)

class AppTestListProxy(AppProxyBasic):
    def setup_class(cls):
        py.test.skip("removed support for lists")

    def test_proxy(self):
        lst = self.proxy(list, lambda : None)
        assert type(lst) is list

    def test_proxy_repr(self):
        def controller(name, *args):
            lst = [1,2,3]
            if name == '__repr__':
                return repr(lst)

        lst = self.proxy(list, controller)
        assert repr(lst) == repr([1,2,3])

    def test_proxy_append(self):
        c = self.Controller([])
        lst = self.proxy(list, c.perform)
        lst.append(1)
        lst.append(2)
        assert repr(lst) == repr([1,2])

    def test_gt_lt_list(self):
        c = self.Controller([])
        lst = self.proxy(list, c.perform)
        lst.append(1)
        lst.append(2)
        assert lst < [1,2,3]
        assert [1,2,3] > lst
        assert lst == [1,2]
        assert [1,2] == lst
        assert [2,3] >= list(iter(lst))
        assert lst < [2,3]
        assert [2,3] >= lst
        assert lst <= [1,2]

    def test_add_list(self):
        c = self.Controller([])
        lst = self.proxy(list, c.perform)
        lst.append(1)
        assert lst + lst == [1,1]
        assert lst + [1] == [1,1]
        assert [1] + lst == [1,1]

    def test_list_getitem(self):
        c = self.Controller([1,2,3])
        lst = self.proxy(list, c.perform)
        assert lst[2] == 3
        lst[1] = 0
        assert lst[0] + lst[1] == 1

    def test_list_setitem(self):
        c = self.Controller([1,2,3])
        lst = self.proxy(list, c.perform)
        try:
            lst[3] = "x"
        except IndexError:
            pass
        else:
            fail("Accessing outside a list didn't raise")

    def test_list_inplace_add(self):
        c = self.Controller([1,2,3])
        lst = self.proxy(list, c.perform)
        lst += [1,2,3]
        assert len(lst) == 6

    def test_list_reverse_add(self):
        c = self.Controller([1,2,3])
        lst = self.proxy(list, c.perform)
        l = [1] + lst
        assert l == [1,1,2,3]

class AppTestDictProxy(AppProxyBasic):
    def setup_class(cls):
        py.test.skip("removed support for dicts")

    def test_dict(self):
        c = self.Controller({"xx":1})
        d = self.proxy(dict, c.perform)
        assert d['xx'] == 1
        assert 'yy' not in d
        d2 = {'yy':3}
        d.update(d2, x=4)
        assert sorted(d.keys()) == ['x', 'xx', 'yy']
        assert sorted(d.values()) == [1, 3, 4]

    def test_dict_pop(self):
        c = self.Controller({'x':1})
        d = self.proxy(dict, c.perform)
        assert d.pop('x') == 1
        assert d.pop('x', None) is None

    def test_dict_iter(self):
        c = self.Controller({'a':1, 'b':2, 'c':3})
        d = self.proxy(dict, c.perform)
        d['z'] = 4
        assert sorted(list(d.iterkeys())) == ['a', 'b', 'c', 'z']
