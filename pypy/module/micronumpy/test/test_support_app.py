"""App-level tests for support.py"""
import sys
import py

from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest
from pypy.conftest import option

class AppTestSupport(BaseNumpyAppTest):
    def setup_class(cls):
        if option.runappdirect and '__pypy__' not in sys.builtin_module_names:
            py.test.skip("pypy only test")
        BaseNumpyAppTest.setup_class.im_func(cls)

    def test_add_docstring(self):
        import numpy as np
        foo = lambda: None
        np.add_docstring(foo, "Does a thing")
        assert foo.__doc__ == "Does a thing"

    def test_type_docstring(self):
        import numpy as np
        import types
        obj = types.ModuleType
        doc = obj.__doc__
        try:
            np.set_docstring(obj, 'foo')
            assert obj.__doc__ == 'foo'
        finally:
            np.set_docstring(obj, doc)

        raises(RuntimeError, np.add_docstring, obj, 'foo')

    def test_method_docstring(self):
        import numpy as np
        doc = int.bit_length.__doc__
        try:
            np.set_docstring(np.ndarray.shape, 'foo')
            assert np.ndarray.shape.__doc__ == 'foo'
        finally:
            np.set_docstring(np.ndarray.shape, doc)

    def test_property_docstring(self):
        import numpy as np
        doc = np.flatiter.base.__doc__
        try:
            np.set_docstring(np.flatiter.base, 'foo')
            assert np.flatiter.base.__doc__ == 'foo'
        finally:
            np.set_docstring(np.flatiter.base, doc)
