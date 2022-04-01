import py
import sys

from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest


class AppTestDeprecations(BaseNumpyAppTest):
    spaceconfig = dict(usemodules=["micronumpy", "struct", "binascii"])

    def test_getitem(self):
        import numpy as np
        import warnings, sys
        warnings.simplefilter('error', np.VisibleDeprecationWarning)
        try:
            arr = np.ones((5, 4, 3))
            index = np.array([True])
            raises(np.VisibleDeprecationWarning, arr.__getitem__, index)

            index = np.array([False] * 6)
            raises(np.VisibleDeprecationWarning, arr.__getitem__, index)

            index = np.zeros((4, 4), dtype=bool)
            if '__pypy__' in sys.builtin_module_names:
                # boolean indexing matches the dims in index
                # to the first index.ndims in arr, not implemented in pypy yet
                raises(IndexError, arr.__getitem__, index)
                raises(IndexError, arr.__getitem__, (slice(None), index))
            else:
                raises(np.VisibleDeprecationWarning, arr.__getitem__, index)
                raises(np.VisibleDeprecationWarning, arr.__getitem__, (slice(None), index))
        finally:
            warnings.simplefilter('default', np.VisibleDeprecationWarning)

