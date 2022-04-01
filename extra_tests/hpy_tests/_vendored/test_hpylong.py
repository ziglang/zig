from .support import HPyTest

class TestLong(HPyTest):
    def unsigned_long_bits(self):
        """ Return the number of bits in an unsigned long. """
        import struct
        unsigned_long_bytes = len(struct.pack('l', 0))
        return 8 * unsigned_long_bytes

    def magic_int(self, v):
        """ Return an instance of a class that implements __int__
            and returns value v.
        """
        class MagicInt(object):
            def __int__(self):
                return v
        return MagicInt()

    def magic_index(self, v):
        """ Return an instance of a class that implements __index__
            and returns value v.
        """
        class MagicIndex(object):
            def __index__(self):
                return v
        return MagicIndex()

    def python_supports_magic_index(self):
        """ Return True if the Python version is 3.8 or later and thus
            should support calling __index__ in the various HPyLong_As...
            methods.
        """
        import sys
        vi = sys.version_info
        return (vi.major > 3 or (vi.major == 3 and vi.minor >= 8))

    def test_Long_FromLong(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                long a = 500;
                return HPyLong_FromLong(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == 500

    def test_Long_AsLong(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                long a = HPyLong_AsLong(ctx, arg);
                if (a == -1 && HPyErr_Occurred(ctx))
                    return HPy_NULL;
                return HPyLong_FromLong(ctx, a * 2);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(45) == 90
        with pytest.raises(TypeError):
            mod.f("this is not a number")
        assert mod.f(self.magic_int(2)) == 4
        if self.python_supports_magic_index():
            assert mod.f(self.magic_index(2)) == 4

    def test_Long_FromUnsignedLong(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                unsigned long a = 500;
                return HPyLong_FromUnsignedLong(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == 500

    def test_Long_AsUnsignedLong(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                unsigned long a = HPyLong_AsUnsignedLong(ctx, arg);
                if ((a == (unsigned long) -1) && HPyErr_Occurred(ctx))
                    return HPy_NULL;
                return HPyLong_FromUnsignedLong(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(45) == 45
        with pytest.raises(OverflowError):
            mod.f(-91)
        with pytest.raises(TypeError):
            mod.f("this is not a number")
        with pytest.raises(TypeError):
            mod.f(self.magic_int(2))
        with pytest.raises(TypeError):
            mod.f(self.magic_index(2))

    def test_Long_AsUnsignedLongMask(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                unsigned long a = HPyLong_AsUnsignedLongMask(ctx, arg);
                if ((a == (unsigned long) -1) && HPyErr_Occurred(ctx))
                    return HPy_NULL;
                return HPyLong_FromUnsignedLong(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(45) == 45
        assert mod.f(-1) == 2**self.unsigned_long_bits() - 1
        with pytest.raises(TypeError):
            mod.f("this is not a number")
        assert mod.f(self.magic_int(2)) == 2
        if self.python_supports_magic_index():
            assert mod.f(self.magic_index(2)) == 2

    def test_Long_FromLongLong(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                // take a value which doesn't fit in 32 bit
                long long val = 2147483648;
                return HPyLong_FromLongLong(ctx, val);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == 2147483648

    def test_Long_AsLongLong(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                long long a = HPyLong_AsLongLong(ctx, arg);
                if ((a == (long long) -1) && HPyErr_Occurred(ctx))
                    return HPy_NULL;
                return HPyLong_FromLongLong(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(2147483648) == 2147483648
        assert mod.f(-2147483648) == -2147483648
        with pytest.raises(TypeError):
            mod.f("this is not a number")
        assert mod.f(self.magic_int(2)) == 2
        if self.python_supports_magic_index():
            assert mod.f(self.magic_index(2)) == 2

    def test_Long_FromUnsignedLongLong(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                // take a value which doesn't fit in unsigned 32 bit
                unsigned long long val = 4294967296;
                return HPyLong_FromUnsignedLongLong(ctx, val);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == 4294967296

    def test_Long_AsUnsignedLongLong(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                unsigned long long a = HPyLong_AsUnsignedLongLong(ctx, arg);
                if ((a == (unsigned long long) -1) && HPyErr_Occurred(ctx))
                    return HPy_NULL;
                return HPyLong_FromUnsignedLongLong(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(4294967296) == 4294967296
        with pytest.raises(OverflowError):
            mod.f(-4294967296)
        with pytest.raises(TypeError):
            mod.f("this is not a number")
        with pytest.raises(TypeError):
            mod.f(self.magic_int(2))
        with pytest.raises(TypeError):
            mod.f(self.magic_index(2))

    def test_Long_AsUnsignedLongLongMask(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                unsigned long long a = HPyLong_AsUnsignedLongLongMask(ctx, arg);
                if ((a == (unsigned long long) -1) && HPyErr_Occurred(ctx))
                    return HPy_NULL;
                return HPyLong_FromUnsignedLongLong(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(45) == 45
        assert mod.f(-1) == 2**64 - 1
        with pytest.raises(TypeError):
            mod.f("this is not a number")
        assert mod.f(self.magic_int(2)) == 2
        if self.python_supports_magic_index():
            assert mod.f(self.magic_index(2)) == 2

    def test_Long_FromSize_t(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                // take a value which doesn't fit in 32 bit
                size_t a = 2147483648;
                return HPyLong_FromSize_t(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == 2147483648

    def test_Long_AsSize_t(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                size_t a = HPyLong_AsSize_t(ctx, arg);
                if ((a == (size_t) -1) && HPyErr_Occurred(ctx))
                    return HPy_NULL;
                return HPyLong_FromSize_t(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(2147483648) == 2147483648
        with pytest.raises(OverflowError):
            mod.f(-2147483648)
        with pytest.raises(TypeError):
            mod.f("this is not a number")
        with pytest.raises(TypeError):
            mod.f(self.magic_int(2))
        with pytest.raises(TypeError):
            mod.f(self.magic_index(2))

    def test_Long_FromSsize_t(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                HPy_ssize_t a = -42;
                return HPyLong_FromSsize_t(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == -42

    def test_Long_AsSsize_t(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy_ssize_t a = HPyLong_AsSsize_t(ctx, arg);
                if ((a == (HPy_ssize_t) -1) && HPyErr_Occurred(ctx))
                    return HPy_NULL;
                return HPyLong_FromSsize_t(ctx, a);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(41) == 41
        assert mod.f(-41) == -41
        with pytest.raises(TypeError):
            mod.f("this is not a number")
        with pytest.raises(TypeError):
            mod.f(self.magic_int(2))
        with pytest.raises(TypeError):
            mod.f(self.magic_index(2))
