from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest


class AppTestAppBridge(BaseNumpyAppTest):
    def test_array_methods(self):
        import numpy as np
        a = np.array(1.5)
        for op in [a.mean, a.var, a.std]:
            try:
                op()
            except ImportError as e:
                assert str(e) == 'No module named numpy.core'

    def test_dtype_commastring(self):
        import numpy as np
        try:
            d = np.dtype('u4,u4,u4')
        except ImportError as e:
            assert str(e) == 'No module named numpy.core'
