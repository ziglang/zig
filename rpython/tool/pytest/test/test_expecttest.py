from rpython.tool.pytest.expecttest import ExpectTest

class TestExpect(ExpectTest):
    def test_one(self):
        def func():
            import os
            import sys
            assert os.ttyname(sys.stdin.fileno())
        self.run_test(func)
