import py
from rpython.jit.backend.test.runner_test import LLtypeBackendTest
from rpython.jit.backend.llgraph.runner import LLGraphCPU

class TestLLTypeLLGraph(LLtypeBackendTest):
    # for individual tests see:
    # ====> ../../test/runner_test.py


    def get_cpu(self):
        return LLGraphCPU(None)

    def test_memoryerror(self):
        py.test.skip("does not make much sense on the llgraph backend")

    def test_call_release_gil_variable_function_and_arguments(self):
        py.test.skip("the arguments seem not correctly casted")
