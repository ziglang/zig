# encoding: utf-8
import py
from pypy.interpreter.error import OperationError
from pypy.interpreter.module import Module

class TestModule:
    def test_name(self, space):
        w = space.wrap
        m = Module(space, space.wrap('m'))
        w_m = w(m)
        assert space.eq_w(space.getattr(w_m, w('__name__')), w('m'))

    def test_attr(self, space):
        w = space.wrap
        w_m = w(Module(space, space.wrap('m')))
        self.space.setattr(w_m, w('x'), w(15))
        assert space.eq_w(space.getattr(w_m, w('x')), w(15))
        space.delattr(w_m, w('x'))
        space.raises_w(space.w_AttributeError,
                       space.delattr, w_m, w('x'))

    def test___file__(self, space):
        w = space.wrap
        m = Module(space, space.wrap('m'))
        py.test.raises(OperationError, space.getattr, w(m), w('__file__'))
        m._cleanup_()
        py.test.raises(OperationError, space.getattr, w(m), w('__file__'))
        space.setattr(w(m), w('__file__'), w('m.py'))
        space.getattr(w(m), w('__file__'))   # does not raise
        m._cleanup_()
        py.test.raises(OperationError, space.getattr, w(m), w('__file__'))


class AppTest_ModuleObject:
    def test_attr(self):
        m = __import__('builtins')
        m.x = 15
        assert m.x == 15
        assert getattr(m, 'x') == 15
        setattr(m, 'x', 23)
        assert m.x == 23
        assert getattr(m, 'x') == 23
        del m.x
        raises(AttributeError, getattr, m, 'x')
        m.x = 15
        delattr(m, 'x')
        raises(AttributeError, getattr, m, 'x')
        raises(AttributeError, delattr, m, 'x')
        raises(AttributeError, setattr, m, '__dict__', {})

    def test_docstring(self):
        import sys
        foo = type(sys)('foo')
        assert foo.__name__ == 'foo'
        assert foo.__doc__ is None
        bar = type(sys)('bar','docstring')
        assert bar.__doc__ == 'docstring'

    def test___file__(self):
        import sys
        assert not hasattr(sys, '__file__')

    def test_repr(self):
        import sys
        if not hasattr(sys, "pypy_objspaceclass"):
            skip("need PyPy for _pypy_interact")
        r = repr(sys)
        assert r == "<module 'sys' (built-in)>"

        import _pypy_interact # known to be in lib_pypy
        r = repr(_pypy_interact)
        assert (r.startswith("<module '_pypy_interact' from ") and
                ('lib_pypy/_pypy_interact.py' in r or
                 r'lib_pypy\\_pypy_interact.py' in r.lower()) and
                r.endswith('>'))
        nofile = type(_pypy_interact)('nofile', 'foo')
        assert repr(nofile) == "<module 'nofile'>"

        m = type(_pypy_interact).__new__(type(_pypy_interact))
        assert repr(m).startswith("<module '?'")

    def test_repr_with_loader_with_valid_module_repr(self):
        import sys
        test_module = type(sys)("test_module", "doc")

        # If the module has a __loader__ and that loader has a module_repr()
        # method, call it with a single argument, which is the module object.
        # The value returned is used as the module’s repr.
        class CustomLoader:
            @classmethod
            def module_repr(cls, module):
                mod_repr = ("<module {mod_name}: "
                            "{cls} Test>".format(mod_name=repr(module.__name__),
                                                cls=repr(cls.__name__)))
                return mod_repr
        test_module.__loader__ = CustomLoader
        assert repr(test_module) == "<module 'test_module': 'CustomLoader' Test>"

    def test_repr_with_loader_with_module_repr_wrong_type(self):
        import sys
        test_module = type(sys)("test_module", "doc")

        # This return value must be a string.
        class BuggyCustomLoader:
            @classmethod
            def module_repr(cls, module):
                return 5

        test_module.__loader__ = BuggyCustomLoader
        raises(TypeError, repr, test_module)

    def test_repr_with_loader_with_raising_module_repr(self):
        import sys
        test_module = type(sys)("test_module", "doc")
        # If an exception occurs in module_repr(), the exception is caught
        # and discarded, and the calculation of the module’s repr continues
        # as if module_repr() did not exist.
        class CustomLoaderWithRaisingRepr:
            @classmethod
            def module_repr(cls, module):
                return repr(1/0)

        test_module.__loader__ = CustomLoaderWithRaisingRepr
        mod_repr = repr(test_module)

        # The module has no __file__ attribute, so the repr should use
        # the loader and name
        loader_repr = repr(test_module.__loader__)
        expected_repr = "<module 'test_module' ({})>".format(loader_repr)
        assert mod_repr == expected_repr

    def test_repr_with_loader_with_raising_module_repr2(self):
        import sys
        test_module = type(sys)("test_module", "doc")
        # If an exception occurs in module_repr(), the exception is caught
        # and discarded, and the calculation of the module’s repr continues
        # as if module_repr() did not exist.
        class CustomLoaderWithRaisingRepr:
            @classmethod
            def module_repr(cls, module):
                raise KeyboardInterrupt

        test_module.__loader__ = CustomLoaderWithRaisingRepr
        raises(KeyboardInterrupt, 'repr(test_module)')

    def test_repr_with_raising_loader_and___file__(self):
        import sys
        test_module = type(sys)("test_module", "doc")
        test_module.__file__ = "/fake_dir/test_module.py"
        class CustomLoaderWithRaisingRepr:
            """Operates just like the builtin importer, but implements a
            module_repr method that raises an exception."""
            @classmethod
            def module_repr(cls, module):
                return repr(1/0)

        test_module.__loader__ = CustomLoaderWithRaisingRepr

        # If the module has an __file__ attribute, this is used as part
        # of the module's repr.
        # (If we have a loader that doesn't correctly implement module_repr,
        # if we have a path, we always just use name and path.
        expected_repr = "<module 'test_module' from '/fake_dir/test_module.py'>"
        assert repr(test_module) == expected_repr

    def test_repr_with_missing_name(self):
        import sys
        test_module = type(sys)("test_module", "doc")
        del test_module.__name__
        mod_repr = repr(test_module)
        assert mod_repr == "<module '?'>"

    def test_dir(self):
        import sys
        items = sys.__dir__()
        assert sorted(items) == dir(sys)

    def test_package(self):
        import sys
        import os

        assert sys.__package__ == ''
        assert os.__package__ == ''
        assert type(sys)('foo').__package__ is None

    def test_name_nonascii(self):
        import sys
        m = type(sys)('日本')
        assert m.__name__ == '日本'
        assert repr(m).startswith("<module '日本'")

    def test_AttributeError_message(self):
        import sys
        test_module = type(sys)("test_module", "doc")
        excinfo = raises(AttributeError, 'test_module.does_not_exist')
        assert (excinfo.value.args[0] ==
            "module 'test_module' has no attribute 'does_not_exist'")

        nameless = type(sys)("nameless", "doc")
        del nameless.__name__
        assert not hasattr(nameless, '__name__')
        excinfo = raises(AttributeError, 'nameless.does_not_exist')
        assert (excinfo.value.args[0] ==
            "module has no attribute 'does_not_exist'")

    def test_weakrefable(self):
        import weakref
        weakref.ref(weakref)

    def test_all_dict_content(self):
        import sys
        m = type(sys)('foo')
        assert m.__dict__ == {'__name__': 'foo',
                              '__doc__': None,
                              '__package__': None,
                              '__loader__': None,
                              '__spec__': None}

    def test_module_new_makes_empty_dict(self):
        import sys
        m = type(sys).__new__(type(sys))
        assert not m.__dict__

    def test_class_assignment_for_module(self):
        import sys
        modtype = type(sys)
        class X(modtype):
            _foobar_ = 42

        m = X("yytest_moduleyy")
        assert type(m) is m.__class__ is X
        assert m._foobar_ == 42
        m.__class__ = modtype
        assert type(m) is m.__class__ is modtype
        assert not hasattr(m, '_foobar_')

        m = modtype("xxtest_modulexx")
        assert type(m) is m.__class__ is modtype
        m.__class__ = X
        assert m._foobar_ == 42
        assert type(m) is m.__class__ is X

        sys.__class__ = modtype
        assert type(sys) is sys.__class__ is modtype
        sys.__class__ = X
        assert sys._foobar_ == 42
        sys.__class__ = modtype

        class XX(modtype):
            __slots__ = ['a', 'b']

        x = XX("zztest_modulezz")
        assert x.__class__ is XX
        raises(AttributeError, "x.a")
        x.a = 42
        assert x.a == 42
        x.a = 43
        assert x.a == 43
        assert 'a' not in x.__dict__
        del x.a
        raises(AttributeError, "x.a")
        raises(AttributeError, "del x.a")
        raises(TypeError, "x.__class__ = X")
        raises(TypeError, "sys.__class__ = XX")

    def test_getattr_dir(self):
        def __getattr__(name):
            if name == 'y':
                return 42
            elif name == 'z':
                return
            raise AttributeError("No attribute '{}'".format(name))

        def __dir__():
            return ['x', 'y', 'z', 'w']

        import sys
        m = type(sys)('foo')
        m.x = 'x'
        m.__getattr__ = __getattr__
        print(m.__dir__)
        m.__dir__ = __dir__

        assert m.x == 'x'
        assert m.y == 42
        assert m.z == None
        excinfo = raises(AttributeError, 'm.w')
        assert str(excinfo.value) == "No attribute 'w'"
        print(dir(m))
        assert dir(m) == sorted(['x', 'y', 'z', 'w'])
