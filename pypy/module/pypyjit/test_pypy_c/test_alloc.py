import py, sys
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

class TestAlloc(BaseTestPyPyC):

    SIZES = dict.fromkeys([2 ** n for n in range(26)] +     # up to 32MB
                          [2 ** n - 1 for n in range(26)])

    def test_newstr_constant_size(self):
        for size in sorted(TestAlloc.SIZES):
            yield self.newstr_constant_size, size

    def newstr_constant_size(self, size):
        print 'size =', size
        src = """if 1:
                    N = %(size)d
                    part_a = 'a' * N
                    part_b = 'b' * N
                    for i in range(20):
                        ao = '%%s%%s' %% (part_a, part_b)
                    def main():
                        return 42
""" % {'size': size}
        log = self.run(src, [], threshold=10)
        assert log.result == 42
        loop, = log.loops_by_filename(self.filepath)
        # assert did not crash
