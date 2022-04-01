import sys
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC


if sys.maxsize == 2 ** 63 - 1:
    extra = """
        i8 = int_ge(i4, -2147483648)
        guard_true(i8, descr=...)
        i9 = int_le(i4, 2147483647)
        guard_true(i9, descr=...)
    """
else:
    extra = ""


class TestStruct(BaseTestPyPyC):
    def test_struct_function(self):
        def main(n):
            import struct
            i = 1
            while i < n:
                buf = struct.pack("<i", i)       # ID: pack
                x = struct.unpack("<i", buf)[0]  # ID: unpack
                i += x // i
            return i

        log = self.run(main, [1000])
        assert log.result == main(1000)

        loop, = log.loops_by_filename(self.filepath)
        # This could, of course stand some improvement, to remove all these
        # arithmatic ops, but we've removed all the core overhead.
        if sys.byteorder == 'little':
            # on little endian machines, we take the fast path and store the
            # value using gc_store_indexed
            assert loop.match_by_id("pack", """
                dummy_get_utf8?
                guard_not_invalidated(descr=...)
                # struct.pack
                %s
                p75 = newstr(4)
                gc_store_indexed(p75, 0, _, 1, _, 4, descr=...)
            """ % extra)
        else:
            assert loop.match_by_id("pack", """
                dummy_get_utf8?
                guard_not_invalidated(descr=...)
                # struct.pack
                %s
                i11 = int_and(i4, 255)
                i13 = int_rshift(i4, 8)
                i14 = int_and(i13, 255)
                i16 = int_rshift(i13, 8)
                i17 = int_and(i16, 255)
                i19 = int_rshift(i16, 8)
                i20 = int_and(i19, 255)
            """ % extra)

        if sys.byteorder == 'little':
            assert loop.match_by_id("unpack", """
                dummy_get_utf8?
                dummy_get_utf8?
                # struct.unpack
                i91 = gc_load_indexed_i(p88, 0, 1, _, -4)
            """)
        else:
            # on a big endian machine we cannot just write into
            # a char buffer and then use load gc to read the integer,
            # here manual shifting is applied
            assert loop.match_by_id("unpack", """
                dummy_get_utf8?
                dummy_get_utf8?
                # struct.unpack
                i95 = int_lshift(i90, 8)
                i96 = int_or(i88, i95)
                i97 = int_lshift(i92, 16)
                i98 = int_or(i96, i97)
                i99 = int_ge(i94, 128)
                guard_false(i99, descr=...)
                i100 = int_lshift(i94, 24)
                i101 = int_or(i98, i100)
            """)

    def test_struct_object(self):
        def main(n):
            import struct
            s = struct.Struct("ii")
            i = 1
            while i < n:
                buf = s.pack(-1, i)     # ID: pack
                x = s.unpack(buf)[1]    # ID: unpack
                i += x // i
            return i

        log = self.run(main, [1000])
        assert log.result == main(1000)

        if sys.byteorder == 'little':
            loop, = log.loops_by_filename(self.filepath)
            assert loop.match_by_id('pack', """
                dummy_get_utf8?
                guard_not_invalidated(descr=...)
                # struct.pack
                p85 = newstr(8)
                gc_store_indexed(p85, 0, -1, 1, _, 4, descr=...)
                %s
                gc_store_indexed(p85, 4, _, 1, _, 4, descr=...)
            """ % extra)

            assert loop.match_by_id('unpack', """
                dummy_get_utf8?
                # struct.unpack
                i90 = gc_load_indexed_i(p88, 0, 1, _, -4)
                i91 = gc_load_indexed_i(p88, 4, 1, _, -4)
            """)

    def test_unpack_raw_buffer(self):
        def main(n):
            import array
            import struct
            buf = struct.pack('H', 0x1234)
            buf = array.array('b', buf)
            i = 1
            res = 0
            while i < n:
                val = struct.unpack("h", buf)[0]     # ID: unpack
                res += val
                i += 1
            return res
        log = self.run(main, [1000])
        assert log.result == main(1000)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('unpack', """
            guard_not_invalidated(descr=...)
            i65 = raw_load_i(i49, 0, descr=<ArrayS 2>)
        """)

    def test_unpack_bytearray(self):
        def main(n):
            import struct
            buf = struct.pack('H', 0x1234)
            buf = bytearray(buf)
            i = 1
            res = 0
            while i < n:
                val = struct.unpack("h", buf)[0]     # ID: unpack
                res += val
                i += 1
            return res
        log = self.run(main, [1000])
        assert log.result == main(1000)
        loop, = log.loops_by_filename(self.filepath)
        # the offset of gc_load_indexed_i used to be the constant 0. However,
        # now it is 'i46' because we need to add 0 to
        # W_BytearrayObject._offset
        assert loop.match_by_id('unpack', """
            guard_not_invalidated(descr=...)
            i70 = gc_load_indexed_i(p48, i46, 1, _, -2)
        """)

    def test_pack_into_raw_buffer(self):
        def main(n):
            import array
            import struct
            buf = array.array('b', b'\x00'*8)
            i = 1
            while i < n:
                struct.pack_into("h", buf, 4, i)     # ID: pack_into
                i += 1
            return i
        log = self.run(main, [1000])
        assert log.result == main(1000)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('pack_into', """\
            guard_not_invalidated(descr=...)
            i65 = int_le(i58, 32767)
            guard_true(i65, descr=...)
            raw_store(i55, 4, i58, descr=<ArrayS 2>)
        """)

    def test_pack_into_bytearray(self):
        def main(n):
            import struct
            buf = bytearray(8)
            i = 1
            while i < n:
                struct.pack_into("h", buf, 4, i)     # ID: pack_into
                i += 1
            return i
        log = self.run(main, [1000])
        assert log.result == main(1000)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('pack_into', """\
            dummy_get_utf8?
            guard_not_invalidated(descr=...)
            dummy_get_utf8?
            p68 = getfield_gc_r(p14, descr=<FieldP pypy.objspace.std.bytearrayobject.W_BytearrayObject.inst__data \d+>)
            i69 = getfield_gc_i(p68, descr=<FieldS list.length \d+>)
            i70 = getfield_gc_i(p14, descr=<FieldS pypy.objspace.std.bytearrayobject.W_BytearrayObject.inst__offset \d+>)
            i71 = int_sub(i69, i70)
            i73 = int_sub(i71, 4)
            i75 = int_lt(i73, 2)
            guard_false(i75, descr=...)
            i77 = int_le(i62, 32767)
            guard_true(i77, descr=...)
            p78 = getfield_gc_r(p68, descr=<FieldP list.items \d+>)
            i81 = int_add(4, i70)
            gc_store_indexed(p78, i81, i62, 1, _, 2, descr=<ArrayS 2>)
        """)
