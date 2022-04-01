class AppTestFFIType(object):
    spaceconfig = dict(usemodules=('_rawffi',))

    def test_simple_types(self):
        from _rawffi.alt import types
        assert str(types.sint) == "<ffi type sint>"
        assert str(types.uint) == "<ffi type uint>"
        assert types.sint.name == 'sint'
        assert types.uint.name == 'uint'

    def test_sizeof(self):
        from _rawffi.alt import types
        assert types.sbyte.sizeof() == 1
        assert types.sint.sizeof() == 4

    def test_typed_pointer(self):
        from _rawffi.alt import types
        intptr = types.Pointer(types.sint) # create a typed pointer to sint
        assert intptr.deref_pointer() is types.sint
        assert str(intptr) == '<ffi type (pointer to sint)>'
        assert types.sint.deref_pointer() is None
        raises(TypeError, "types.Pointer(42)")

    def test_pointer_identity(self):
        from _rawffi.alt import types
        x = types.Pointer(types.slong)
        y = types.Pointer(types.slong)
        z = types.Pointer(types.char)
        assert x is y
        assert x is not z

    def test_char_p_cached(self):
        from _rawffi.alt import types
        x = types.Pointer(types.char)
        assert x is types.char_p
        x = types.Pointer(types.unichar)
        assert x is types.unichar_p
