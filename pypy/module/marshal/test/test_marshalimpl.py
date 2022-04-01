from pypy.module.marshal import interp_marshal
from pypy.interpreter.error import OperationError
from pypy.objspace.std.intobject import W_IntObject
import sys


class AppTestMarshalMore:
    spaceconfig = dict(usemodules=('array',))

    def test_marshal_bufferlike_object(self):
        import marshal, array
        s = marshal.dumps(array.array('b', b'asd'))
        t = marshal.loads(s)
        assert type(t) is bytes and t == b'asd'

        s = marshal.dumps(memoryview(b'asd'))
        t = marshal.loads(s)
        assert type(t) is bytes and t == b'asd'

    def test_unmarshal_evil_long(self):
        import marshal
        raises(ValueError, marshal.loads, b'l\x02\x00\x00\x00\x00\x00\x00\x00')

    def test_marshal_code_object(self):
        def foo(a, b):
            pass

        import marshal
        s = marshal.dumps(foo.__code__)
        code2 = marshal.loads(s)
        for attr_name in dir(code2):
            if attr_name.startswith("co_"):
                assert getattr(code2, attr_name) == getattr(foo.__code__, attr_name)

    def test_unmarshal_ascii(self):
        import marshal
        s = marshal.loads(b"a\x04\x00\x00\x00abcd")
        assert s == u"abcd"

    def test_marshal_ascii(self):
        import marshal
        s = marshal.dumps("a")
        assert s.endswith(b"\x01a")
        s = marshal.dumps("a" * 1000)
        assert s == b"\xe1\xe8\x03\x00\x00" + b"a" * 1000
        for x in ("?" * 255, "a" * 1000, "xyza"):
            s = marshal.dumps(x)
            s1 = marshal.dumps((x, x)) # check that sharing works
            assert s1 == b")\x02" + s + b"r\x00\x00\x00\x00"

    def test_shared_string(self):
        import marshal
        x = "hello, "
        x += "world"
        xl = 256
        xl **= 100
        for version in [2, 3]:
            s = marshal.dumps((x, x), version)
            assert s.count(b'hello, world') == 2 if version < 3 else 1
            y = marshal.loads(s)
            assert y == (x, x)
            #
            s = marshal.dumps((xl, xl), version)
            if version < 3:
                assert 200 < len(s) < 250
            else:
                assert 100 < len(s) < 125
            yl = marshal.loads(s)
            assert yl == (xl, xl)


class AppTestMarshalSmallLong(AppTestMarshalMore):
    spaceconfig = dict(usemodules=('array',),
                       **{"objspace.std.withsmalllong": True})


def test_long_more(space):
    import marshal, struct

    class FakeM:
        # NOTE: marshal is platform independent, running this test must assume
        # that self.seen gets values from the endianess of the marshal module.
        # (which is little endian!)
        version = 2
        def __init__(self):
            self.seen = []
        def start(self, code):
            self.seen.append(code)
        def put_int(self, value):
            self.seen.append(struct.pack("<i", value))
        def put_short(self, value):
            self.seen.append(struct.pack("<h", value))

    def _marshal_check(x):
        expected = marshal.dumps(long(x))
        w_obj = space.wraplong(x)
        m = FakeM()
        interp_marshal.marshal(space, w_obj, m)
        assert ''.join(m.seen) == expected
        #
        u = interp_marshal.StringUnmarshaller(space, space.newbytes(expected))
        w_long = u.load_w_obj()
        assert space.eq_w(w_long, w_obj)

    for sign in [1L, -1L]:
        for i in range(100):
            _marshal_check(sign * ((1L << i) - 1L))
            _marshal_check(sign * (1L << i))

def test_int_roundtrip(space):
    a = 0xffffffff
    w_a = space.newint(a)
    m = interp_marshal.StringMarshaller(space, 4)
    interp_marshal.marshal(space, w_a, m)
    s = m.get_value()
    u = interp_marshal.StringUnmarshaller(space, space.newbytes(s))
    w_res = u.load_w_obj()

    assert type(w_res) is W_IntObject
    assert w_res.intval == w_a.intval == a

def test_hidden_applevel(space):
    w_s = interp_marshal.dumps(space, space.appdef('''(): pass''').code)
    w_c = interp_marshal._loads(space, w_s)
    assert w_c.hidden_applevel == False
    w_c = interp_marshal._loads(space, w_s, hidden_applevel=True)
    assert w_c.hidden_applevel == True
