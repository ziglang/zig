"""
Tests for the struct module implemented at interp-level in pypy/module/struct.
"""

class AppTestFastPath(object):
    spaceconfig = dict(usemodules=['array', 'struct', '__pypy__'])

    def setup_class(cls):
        from rpython.rlib.rstruct import standardfmttable
        standardfmttable.ALLOW_SLOWPATH = False
        #
        cls.w_struct = cls.space.appexec([], """():
            import struct
            return struct
        """)
        cls.w_bytebuffer = cls.space.appexec([], """():
            import __pypy__
            return __pypy__.bytebuffer
        """)

    def teardown_class(cls):
        from rpython.rlib.rstruct import standardfmttable
        standardfmttable.ALLOW_SLOWPATH = True

    def test_unpack_simple(self):
        buf = self.struct.pack("iii", 0, 42, 43)
        assert self.struct.unpack("iii", buf) == (0, 42, 43)

    def test_unpack_from(self):
        buf = self.struct.pack("iii", 0, 42, 43)
        offset = self.struct.calcsize("i")
        assert self.struct.unpack_from("ii", buf, offset) == (42, 43)

    def test_unpack_bytearray(self):
        data = self.struct.pack("iii", 0, 42, 43)
        buf = bytearray(data)
        assert self.struct.unpack("iii", buf) == (0, 42, 43)

    def test_unpack_array(self):
        import array
        data = self.struct.pack("iii", 0, 42, 43)
        buf = array.array('B', data)
        assert self.struct.unpack("iii", buf) == (0, 42, 43)

    def test_pack_into_bytearray(self):
        expected = self.struct.pack("ii", 42, 43)
        buf = bytearray(len(expected))
        self.struct.pack_into("ii", buf, 0, 42, 43)
        assert buf == expected

    def test_pack_into_bytearray_padding(self):
        expected = self.struct.pack("xxi", 42)
        buf = bytearray(len(expected))
        self.struct.pack_into("xxi", buf, 0, 42)
        assert buf == expected

    def test_pack_into_bytearray_delete(self):
        expected = self.struct.pack("i", 42)
        # force W_BytearrayObject._delete_from_start
        buf = bytearray(64)
        del buf[:8]
        self.struct.pack_into("i", buf, 0, 42)
        buf = buf[:len(expected)]
        assert buf == expected
