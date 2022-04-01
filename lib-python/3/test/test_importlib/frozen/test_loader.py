from .. import abc
from .. import util

machinery = util.import_importlib('importlib.machinery')

from test.support import captured_stdout
import types
import unittest
import warnings


class ExecModuleTests(abc.LoaderTests):

    def exec_module(self, name):
        with util.uncache(name), captured_stdout() as stdout:
            spec = self.machinery.ModuleSpec(
                    name, self.machinery.FrozenImporter, origin='frozen',
                    is_package=self.machinery.FrozenImporter.is_package(name))
            module = types.ModuleType(name)
            module.__spec__ = spec
            assert not hasattr(module, 'initialized')
            self.machinery.FrozenImporter.exec_module(module)
            self.assertTrue(module.initialized)
            self.assertTrue(hasattr(module, '__spec__'))
            self.assertEqual(module.__spec__.origin, 'frozen')
            return module, stdout.getvalue()

    def test_module(self):
        name = '__hello__'
        module, output = self.exec_module(name)
        check = {'__name__': name}
        for attr, value in check.items():
            self.assertEqual(getattr(module, attr), value)
        self.assertEqual(output, 'Hello world!\n')
        self.assertTrue(hasattr(module, '__spec__'))

    def test_package(self):
        name = '__phello__'
        module, output = self.exec_module(name)
        check = {'__name__': name}
        for attr, value in check.items():
            attr_value = getattr(module, attr)
            self.assertEqual(attr_value, value,
                        'for {name}.{attr}, {given!r} != {expected!r}'.format(
                                 name=name, attr=attr, given=attr_value,
                                 expected=value))
        self.assertEqual(output, 'Hello world!\n')

    def test_lacking_parent(self):
        name = '__phello__.spam'
        with util.uncache('__phello__'):
            module, output = self.exec_module(name)
            check = {'__name__': name}
            for attr, value in check.items():
                attr_value = getattr(module, attr)
                self.assertEqual(attr_value, value,
                        'for {name}.{attr}, {given} != {expected!r}'.format(
                                 name=name, attr=attr, given=attr_value,
                                 expected=value))
            self.assertEqual(output, 'Hello world!\n')

    def test_module_repr(self):
        name = '__hello__'
        module, output = self.exec_module(name)
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', DeprecationWarning)
            repr_str = self.machinery.FrozenImporter.module_repr(module)
        self.assertEqual(repr_str,
                         "<module '__hello__' (frozen)>")

    def test_module_repr_indirect(self):
        name = '__hello__'
        module, output = self.exec_module(name)
        self.assertEqual(repr(module),
                         "<module '__hello__' (frozen)>")

    # No way to trigger an error in a frozen module.
    test_state_after_failure = None

    def test_unloadable(self):
        assert self.machinery.FrozenImporter.find_module('_not_real') is None
        with self.assertRaises(ImportError) as cm:
            self.exec_module('_not_real')
        self.assertEqual(cm.exception.name, '_not_real')


(Frozen_ExecModuleTests,
 Source_ExecModuleTests
 ) = util.test_both(ExecModuleTests, machinery=machinery)


class LoaderTests(abc.LoaderTests):

    def test_module(self):
        with util.uncache('__hello__'), captured_stdout() as stdout:
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', DeprecationWarning)
                module = self.machinery.FrozenImporter.load_module('__hello__')
            check = {'__name__': '__hello__',
                    '__package__': '',
                    '__loader__': self.machinery.FrozenImporter,
                    }
            for attr, value in check.items():
                self.assertEqual(getattr(module, attr), value)
            self.assertEqual(stdout.getvalue(), 'Hello world!\n')
            self.assertFalse(hasattr(module, '__file__'))

    def test_package(self):
        with util.uncache('__phello__'),  captured_stdout() as stdout:
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', DeprecationWarning)
                module = self.machinery.FrozenImporter.load_module('__phello__')
            check = {'__name__': '__phello__',
                     '__package__': '__phello__',
                     '__path__': [],
                     '__loader__': self.machinery.FrozenImporter,
                     }
            for attr, value in check.items():
                attr_value = getattr(module, attr)
                self.assertEqual(attr_value, value,
                                 "for __phello__.%s, %r != %r" %
                                 (attr, attr_value, value))
            self.assertEqual(stdout.getvalue(), 'Hello world!\n')
            self.assertFalse(hasattr(module, '__file__'))

    def test_lacking_parent(self):
        with util.uncache('__phello__', '__phello__.spam'), \
             captured_stdout() as stdout:
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', DeprecationWarning)
                module = self.machinery.FrozenImporter.load_module('__phello__.spam')
            check = {'__name__': '__phello__.spam',
                    '__package__': '__phello__',
                    '__loader__': self.machinery.FrozenImporter,
                    }
            for attr, value in check.items():
                attr_value = getattr(module, attr)
                self.assertEqual(attr_value, value,
                                 "for __phello__.spam.%s, %r != %r" %
                                 (attr, attr_value, value))
            self.assertEqual(stdout.getvalue(), 'Hello world!\n')
            self.assertFalse(hasattr(module, '__file__'))

    def test_module_reuse(self):
        with util.uncache('__hello__'), captured_stdout() as stdout:
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', DeprecationWarning)
                module1 = self.machinery.FrozenImporter.load_module('__hello__')
                module2 = self.machinery.FrozenImporter.load_module('__hello__')
            self.assertIs(module1, module2)
            self.assertEqual(stdout.getvalue(),
                             'Hello world!\nHello world!\n')

    def test_module_repr(self):
        with util.uncache('__hello__'), captured_stdout():
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', DeprecationWarning)
                module = self.machinery.FrozenImporter.load_module('__hello__')
                repr_str = self.machinery.FrozenImporter.module_repr(module)
            self.assertEqual(repr_str,
                             "<module '__hello__' (frozen)>")

    def test_module_repr_indirect(self):
        with util.uncache('__hello__'), captured_stdout():
            module = self.machinery.FrozenImporter.load_module('__hello__')
        self.assertEqual(repr(module),
                         "<module '__hello__' (frozen)>")

    # No way to trigger an error in a frozen module.
    test_state_after_failure = None

    def test_unloadable(self):
        assert self.machinery.FrozenImporter.find_module('_not_real') is None
        with self.assertRaises(ImportError) as cm:
            self.machinery.FrozenImporter.load_module('_not_real')
        self.assertEqual(cm.exception.name, '_not_real')


(Frozen_LoaderTests,
 Source_LoaderTests
 ) = util.test_both(LoaderTests, machinery=machinery)


class InspectLoaderTests:

    """Tests for the InspectLoader methods for FrozenImporter."""

    def test_get_code(self):
        # Make sure that the code object is good.
        name = '__hello__'
        with captured_stdout() as stdout:
            code = self.machinery.FrozenImporter.get_code(name)
            mod = types.ModuleType(name)
            exec(code, mod.__dict__)
            self.assertTrue(hasattr(mod, 'initialized'))
            self.assertEqual(stdout.getvalue(), 'Hello world!\n')

    def test_get_source(self):
        # Should always return None.
        result = self.machinery.FrozenImporter.get_source('__hello__')
        self.assertIsNone(result)

    def test_is_package(self):
        # Should be able to tell what is a package.
        test_for = (('__hello__', False), ('__phello__', True),
                    ('__phello__.spam', False))
        for name, is_package in test_for:
            result = self.machinery.FrozenImporter.is_package(name)
            self.assertEqual(bool(result), is_package)

    def test_failure(self):
        # Raise ImportError for modules that are not frozen.
        for meth_name in ('get_code', 'get_source', 'is_package'):
            method = getattr(self.machinery.FrozenImporter, meth_name)
            with self.assertRaises(ImportError) as cm:
                method('importlib')
            self.assertEqual(cm.exception.name, 'importlib')

(Frozen_ILTests,
 Source_ILTests
 ) = util.test_both(InspectLoaderTests, machinery=machinery)


if __name__ == '__main__':
    unittest.main()
