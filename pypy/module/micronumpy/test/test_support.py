from py.test import raises
from pypy.module.micronumpy import support
from pypy.module.micronumpy.ufuncs import W_UfuncGeneric
from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest
from pypy.interpreter.error import OperationError

class TestParseSignatureDirect(BaseNumpyAppTest):
    def test_signature_basic(self):
        space = self.space
        funcs = [None]
        name = 'dummy ufunc'
        identity = None
        dtypes = [int, int, int]
        
        nin = 2
        nout = 1
        signature = '(), () -> (  ) '
        ufunc = W_UfuncGeneric(space, funcs, name, identity, nin, nout, dtypes, signature)
        # make sure no attributes are added
        attribs = set(ufunc.__dict__.keys())
        support._parse_signature(space, ufunc, ufunc.signature)
        new_attribs = set(ufunc.__dict__.keys())
        assert attribs == new_attribs
        assert sum(ufunc.core_num_dims) == 0
        assert ufunc.core_enabled == 0

        nin = 2
        nout = 1
        signature = '(i),(i)->()'
        ufunc = W_UfuncGeneric(space, funcs, name, identity, nin, nout, dtypes, signature)
        support._parse_signature(space, ufunc, ufunc.signature)
        assert ufunc.core_enabled == 1

        nin = 2
        nout = 1
        signature = '(i1, i2),(J_1)->(_kAB)'
        ufunc = W_UfuncGeneric(space, funcs, name, identity, nin, nout, dtypes, signature)
        support._parse_signature(space, ufunc, ufunc.signature)
        assert ufunc.core_enabled == 1

        nin = 2
        nout = 1
        signature = '(i1  i2),(J_1)->(_kAB)'
        ufunc = W_UfuncGeneric(space, funcs, name, identity, nin, nout, dtypes, signature)
        exc = raises(OperationError, support._parse_signature, space, ufunc, ufunc.signature)
        assert "expect dimension name" in exc.value.errorstr(space)

        nin = 2
        nout = 1
        signature = '(i),i(->()'
        ufunc = W_UfuncGeneric(space, funcs, name, identity, nin, nout, dtypes, signature)
        exc = raises(OperationError, support._parse_signature, space, ufunc, ufunc.signature)
        assert "expect '(' at 4" in exc.value.errorstr(space)
