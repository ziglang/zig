class AppTest(object):
    spaceconfig = dict(usemodules=['__pypy__'])

    def test_bytebuffer(self):
        from __pypy__ import bytebuffer
        b = bytebuffer(12)
        assert len(b) == 12
        b[3] = ord(b'!')
        b[5] = ord(b'?')
        assert b[2:7] == b'\x00!\x00?\x00'
        b[9:] = b'+-*'
        assert b[-1] == ord(b'*')
        assert b[-2] == ord(b'-')
        assert b[-3] == ord(b'+')
        exc = raises(ValueError, "b[3:5] = b'abc'")
        assert str(exc.value) == "cannot modify size of memoryview object"

        b = bytebuffer(10)
        b[1:3] = b'xy'
        assert bytes(b) == b"\x00xy" + b"\x00" * 7
        b[4:8:2] = b'zw'
        assert bytes(b) == b"\x00xy\x00z\x00w" + b"\x00" * 3

    def test_buffer_getslice_empty(self):
        from __pypy__ import bytebuffer
        b = bytebuffer(10)
        assert b[1:0] == b''

    def test_bytebuffer_object(self):
        from __pypy__ import bytebuffer
        b = bytebuffer(10)
        assert b.obj is None

