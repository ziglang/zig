from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC


class TestBuffers(BaseTestPyPyC):
    def test_re_match(self):
        def main(n):
            import re
            import array
            p = re.compile(b'.+')
            a = array.array('B', b'test' * 1000)
            i = 0
            while i < n:
                i += 1
                p.match(a)  # ID: match
            return i
        log = self.run(main, [1000])
        assert log.result == 1000
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('match', """
            guard_not_invalidated(descr=...)
            p71 = getfield_gc_r(p15, descr=...) # check that the pattern is not None and a W_BytesObject
            guard_nonnull_class(p71, ConstClass(W_BytesObject), descr=...)
            i74 = instance_ptr_eq(_, p71)
            guard_false(i74, descr=...)
            i65 = getfield_gc_i(p18, descr=...)
            i67 = int_gt(0, i65)
            guard_false(i67, descr=...)
            i69 = int_gt(#, i65)
            guard_true(i69, descr=...)
            --TICK--
        """)

    def test_struct_unpack(self):
        def main(n):
            import _struct as struct
            import array
            a = array.array('B', struct.pack('i', 42))
            i = 0
            while i < n:
                i += 1
                struct.unpack('i', a)  # ID: unpack
            return i
        log = self.run(main, [1000])
        assert log.result == 1000
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('unpack', """
            guard_not_invalidated(descr=...)
            i66 = raw_load_i(i53, 0, descr=<ArrayS 4>)
            --TICK--
        """)
