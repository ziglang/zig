import py
from rpython.jit.backend.llsupport.llmodel import AbstractLLCPU
from rpython.jit.backend.test.runner_test import LLtypeBackendTest


class FakeStats(object):
    pass

class MyLLCPU(AbstractLLCPU):
    supports_floats = True

    class assembler(object):
        @staticmethod
        def set_debug(flag):
            pass
    
    def compile_loop(self, inputargs, operations, looptoken):
        py.test.skip("llsupport test: cannot compile operations")


class TestAbstractLLCPU(LLtypeBackendTest):

    # for the individual tests see
    # ====> ../../test/runner_test.py

    def get_cpu(self):
        return MyLLCPU(rtyper=None, stats=FakeStats(), opts=None)
