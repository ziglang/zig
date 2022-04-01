"""
NOTE: this tests are also meant to be run as PyPy "applevel" tests.

This means that global imports will NOT be visible inside the test
functions. In particular, you have to "import pytest" inside the test in order
to be able to use e.g. pytest.raises (which on PyPy will be implemented by a
"fake pytest module")
"""
from .support import HPyTest


class TestParseItem(HPyTest):

    def unsigned_long_bits(self):
        """ Return the number of bits in an unsigned long. """
        # XXX: Copied from test_hpylong.py
        import struct
        unsigned_long_bytes = len(struct.pack('l', 0))
        return 8 * unsigned_long_bytes


    def make_parse_item(self, fmt, type, hpy_converter):
        mod = self.make_module("""
            #ifndef _MSC_VER
            __attribute__((unused))
            #endif
            static inline
            HPy char_to_hpybytes(HPyContext *ctx, char a) {{
                return HPyBytes_FromStringAndSize(ctx, &a, 1);
            }}

            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs)
            {{
                {type} a;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "{fmt}", &a))
                    return HPy_NULL;
                return {hpy_converter}(ctx, a);
            }}
            @EXPORT(f)
            @INIT
        """.format(fmt=fmt, type=type, hpy_converter=hpy_converter))
        return mod

    def test_b(self):
        import pytest
        mod = self.make_parse_item("b", "char", "char_to_hpybytes")
        assert mod.f(0) == b"\x00"
        assert mod.f(1) == b"\x01"
        assert mod.f(255) == b"\xff"
        with pytest.raises(OverflowError) as err:
            mod.f(256)
        assert str(err.value) == (
            "function unsigned byte integer is greater than maximum"
        )
        with pytest.raises(OverflowError) as err:
            mod.f(-1)
        assert str(err.value) == (
            "function unsigned byte integer is less than minimum"
        )

    def test_s(self):
        import pytest
        mod = self.make_parse_item("s", "const char*", "HPyUnicode_FromString")
        assert mod.f("hello HPy") == "hello HPy"
        with pytest.raises(ValueError) as err:
            mod.f(b"hello\0HPy".decode('utf-8'))
        assert str(err.value) == (
            "function embedded null character"
        )
        with pytest.raises(TypeError) as err:
            mod.f(b"hello HPy")
        assert str(err.value) == (
            "function a str is required"
        )

    def test_B(self):
        mod = self.make_parse_item("B", "char", "char_to_hpybytes")
        assert mod.f(0) == b"\x00"
        assert mod.f(1) == b"\x01"
        assert mod.f(2**8 - 1) == b"\xff"
        assert mod.f(2**8) == b"\x00"
        assert mod.f(-1) == b"\xff"

    def test_h(self):
        import pytest
        mod = self.make_parse_item("h", "short", "HPyLong_FromLong")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == -1
        assert mod.f(2**15 - 1) == 2**15 - 1
        assert mod.f(-2**15) == -2**15
        with pytest.raises(OverflowError) as err:
            mod.f(2**15)
        assert str(err.value) == (
            "function signed short integer is greater than maximum"
        )
        with pytest.raises(OverflowError) as err:
            mod.f(-2**15 - 1)
        assert str(err.value) == (
            "function signed short integer is less than minimum"
        )

    def test_H_short(self):
        mod = self.make_parse_item("H", "short", "HPyLong_FromLong")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == -1
        assert mod.f(2**15 - 1) == 2**15 - 1
        assert mod.f(-2**15) == -2**15
        assert mod.f(2**16 - 1) == -1
        assert mod.f(-2**16 + 1) == 1
        assert mod.f(2**16) == 0
        assert mod.f(-2**16) == 0

    def test_H_unsigned_short(self):
        mod = self.make_parse_item(
            "H", "unsigned short", "HPyLong_FromUnsignedLong"
        )
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == 2**16 - 1
        assert mod.f(2**16 - 1) == 2**16 - 1
        assert mod.f(-2**16 + 1) == 1
        assert mod.f(2**16) == 0
        assert mod.f(-2**16) == 0

    def test_i(self):
        import pytest
        mod = self.make_parse_item("i", "int", "HPyLong_FromLong")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == -1
        assert mod.f(2**31 - 1) == 2**31 - 1
        assert mod.f(-2**31) == -2**31
        with pytest.raises(OverflowError) as err:
            mod.f(2**31)
        assert str(err.value) in (
            "function signed integer is greater than maximum",
            "Python int too large to convert to C long",  # where sizeof(long) == 4
        )
        with pytest.raises(OverflowError) as err:
            mod.f(-2**31 - 1)
        assert str(err.value) in (
            "function signed integer is less than minimum",
            "Python int too large to convert to C long",  # where sizeof(long) == 4
        )

    def test_I_signed(self):
        mod = self.make_parse_item("I", "int", "HPyLong_FromLong")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == -1
        assert mod.f(2**31 - 1) == 2**31 - 1
        assert mod.f(-2**31) == -2**31
        assert mod.f(2**32 - 1) == -1
        assert mod.f(-2**32 + 1) == 1
        assert mod.f(2**32) == 0
        assert mod.f(-2**32) == 0

    def test_I_unsigned(self):
        mod = self.make_parse_item(
            "I", "unsigned int", "HPyLong_FromUnsignedLong"
        )
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == 2**32 - 1
        assert mod.f(2**32 - 1) == 2**32 - 1
        assert mod.f(-2**32 + 1) == 1
        assert mod.f(2**32) == 0
        assert mod.f(-2**32) == 0

    def test_l(self):
        import pytest
        LONG_BITS = self.unsigned_long_bits() - 1
        mod = self.make_parse_item("l", "long", "HPyLong_FromLong")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == -1
        assert mod.f(2**LONG_BITS - 1) == 2**LONG_BITS - 1
        assert mod.f(-2**LONG_BITS) == -2**LONG_BITS
        with pytest.raises(OverflowError):
            mod.f(2**LONG_BITS)
        with pytest.raises(OverflowError):
            mod.f(-2**LONG_BITS - 1)

    def test_k_signed(self):
        LONG_BITS = self.unsigned_long_bits() - 1
        mod = self.make_parse_item("k", "long", "HPyLong_FromLong")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == -1
        assert mod.f(2**LONG_BITS - 1) == 2**LONG_BITS - 1
        assert mod.f(-2**LONG_BITS) == -2**LONG_BITS
        assert mod.f(2**(LONG_BITS + 1) - 1) == -1
        assert mod.f(-2**(LONG_BITS + 1) + 1) == 1
        assert mod.f(2**(LONG_BITS + 1)) == 0
        assert mod.f(-2**(LONG_BITS + 1)) == 0

    def test_k_unsigned(self):
        ULONG_BITS = self.unsigned_long_bits()
        mod = self.make_parse_item(
            "k", "unsigned long", "HPyLong_FromUnsignedLong"
        )
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == 2**ULONG_BITS - 1
        assert mod.f(2**ULONG_BITS - 1) == 2**ULONG_BITS - 1
        assert mod.f(-2**ULONG_BITS + 1) == 1
        assert mod.f(2**ULONG_BITS) == 0
        assert mod.f(-2**ULONG_BITS) == 0

    def test_L(self):
        import pytest
        mod = self.make_parse_item("L", "long long", "HPyLong_FromLongLong")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == -1
        assert mod.f(2**63 - 1) == 2**63 - 1
        assert mod.f(-2**63) == -2**63
        with pytest.raises(OverflowError):
            mod.f(2**63)
        with pytest.raises(OverflowError):
            mod.f(-2**63 - 1)

    def test_K_signed(self):
        mod = self.make_parse_item("K", "long long", "HPyLong_FromLongLong")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == -1
        assert mod.f(2**63 - 1) == 2**63 - 1
        assert mod.f(-2**63) == -2**63
        assert mod.f(2**64 - 1) == -1
        assert mod.f(-2**64 + 1) == 1
        assert mod.f(2**64) == 0
        assert mod.f(-2**64) == 0

    def test_K_unsigned(self):
        mod = self.make_parse_item(
            "K", "unsigned long long", "HPyLong_FromUnsignedLongLong"
        )
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == 2**64 - 1
        assert mod.f(2**64 - 1) == 2**64 - 1
        assert mod.f(-2**64 + 1) == 1
        assert mod.f(2**64) == 0
        assert mod.f(-2**64) == 0

    def test_n(self):
        import pytest
        mod = self.make_parse_item("n", "HPy_ssize_t", "HPyLong_FromSsize_t")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == -1
        assert mod.f(2**63 - 1) == 2**63 - 1
        assert mod.f(-2**63) == -2**63
        with pytest.raises(OverflowError):
            mod.f(2**63)
        with pytest.raises(OverflowError):
            mod.f(-2**63 - 1)

    def test_f(self):
        import pytest
        mod = self.make_parse_item("f", "float", "HPyFloat_FromDouble")
        assert mod.f(1.) == 1.
        assert mod.f(-2) == -2.
        with pytest.raises(TypeError):
            mod.f("x")

    def test_d(self):
        import pytest
        mod = self.make_parse_item("d", "double", "HPyFloat_FromDouble")
        assert mod.f(1.) == 1.
        assert mod.f(-2) == -2.
        with pytest.raises(TypeError):
            mod.f("x")

    def test_O(self):
        mod = self.make_parse_item("O", "HPy", "HPy_Dup")
        assert mod.f("a") == "a"
        assert mod.f(5) == 5

    def test_p(self):
        mod = self.make_parse_item("p", "int", "HPyLong_FromLong")
        assert mod.f(0) == 0
        assert mod.f(1) == 1
        assert mod.f(-1) == 1
        assert mod.f(False) == 0
        assert mod.f(True) == 1
        assert mod.f([]) == 0
        assert mod.f([0]) == 1
        assert mod.f("") == 0
        assert mod.f("0") == 1


class TestArgParse(HPyTest):
    def make_two_arg_add(self, fmt="OO"):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs)
            {{
                HPy a;
                HPy b = HPy_NULL;
                HPy res;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "{fmt}", &a, &b))
                    return HPy_NULL;
                if (HPy_IsNull(b)) {{
                    b = HPyLong_FromLong(ctx, 5);
                }} else {{
                    b = HPy_Dup(ctx, b);
                }}
                res = HPy_Add(ctx, a, b);
                HPy_Close(ctx, b);
                return res;
            }}
            @EXPORT(f)
            @INIT
        """.format(fmt=fmt))
        return mod

    def test_many_int_arguments(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs)
            {
                long a, b, c, d, e;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "lllll",
                                  &a, &b, &c, &d, &e))
                    return HPy_NULL;
                return HPyLong_FromLong(ctx,
                    10000*a + 1000*b + 100*c + 10*d + e);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(4, 5, 6, 7, 8) == 45678

    def test_many_handle_arguments(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs)
            {
                HPy a, b;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "OO", &a, &b))
                    return HPy_NULL;
                return HPy_Add(ctx, a, b);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f("a", "b") == "ab"

    def test_supplying_hpy_tracker(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs)
            {
                HPy a, b, result;
                HPyTracker ht;
                if (!HPyArg_Parse(ctx, &ht, args, nargs, "OO", &a, &b))
                    return HPy_NULL;
                result = HPy_Add(ctx, a, b);
                HPyTracker_Close(ctx, ht);
                return result;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f("a", "b") == "ab"

    def test_unsupported_fmt(self):
        import pytest
        mod = self.make_two_arg_add(fmt="ZZ:two_add")
        with pytest.raises(SystemError) as exc:
            mod.f("a")
        assert str(exc.value) == "two_add() unknown arg format code"

    def test_too_few_args(self):
        import pytest
        mod = self.make_two_arg_add("OO:two_add")
        with pytest.raises(TypeError) as exc:
            mod.f()
        assert str(exc.value) == "two_add() required positional argument missing"

    def test_too_many_args(self):
        import pytest
        mod = self.make_two_arg_add("OO:two_add")
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2, 3)
        assert str(exc.value) == "two_add() mismatched args (too many arguments for fmt)"

    def test_optional_args(self):
        mod = self.make_two_arg_add(fmt="O|O")
        assert mod.f(1) == 6
        assert mod.f(3, 4) == 7

    def test_keyword_only_args_fails(self):
        import pytest
        mod = self.make_two_arg_add(fmt="O$O:two_add")
        with pytest.raises(SystemError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == "two_add() unknown arg format code"

    def test_error_default_message(self):
        import pytest
        mod = self.make_two_arg_add(fmt="OOO")
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == "function required positional argument missing"

    def test_error_with_function_name(self):
        import pytest
        mod = self.make_two_arg_add(fmt="OOO:my_func")
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == "my_func() required positional argument missing"

    def test_error_with_overridden_message(self):
        import pytest
        mod = self.make_two_arg_add(fmt="OOO;my-error-message")
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == "my-error-message"


class TestArgParseKeywords(HPyTest):
    def make_two_arg_add(self, fmt="O+O+"):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_KEYWORDS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs, HPy kw)
            {{
                HPy a, b, result;
                HPyTracker ht;
                static const char *kwlist[] = {{ "a", "b", NULL }};
                if (!HPyArg_ParseKeywords(ctx, &ht, args, nargs, kw, "{fmt}",
                                          kwlist, &a, &b)) {{
                    return HPy_NULL;
                }}
                result = HPy_Add(ctx, a, b);
                HPyTracker_Close(ctx, ht);
                return result;
            }}
            @EXPORT(f)
            @INIT
        """.format(fmt=fmt))
        return mod

    def test_handle_two_arguments(self):
        mod = self.make_two_arg_add("OO")
        assert mod.f("x", b="y") == "xy"

    def test_handle_reordered_arguments(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_KEYWORDS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs, HPy kw)
            {
                HPy a, b, result;
                HPyTracker ht;
                static const char *kwlist[] = { "a", "b", NULL };
                if (!HPyArg_ParseKeywords(ctx, &ht, args, nargs, kw, "OO", kwlist, &a, &b)) {
                    return HPy_NULL;
                }
                result = HPy_Add(ctx, a, b);
                HPyTracker_Close(ctx, ht);
                return result;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(b="y", a="x") == "xy"

    def test_handle_optional_arguments(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_KEYWORDS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs, HPy kw)
            {
                HPy a;
                HPy b = HPy_NULL;
                HPyTracker ht;
                HPy res;
                static const char *kwlist[] = { "a", "b", NULL };
                if (!HPyArg_ParseKeywords(ctx, &ht, args, nargs, kw, "O|O", kwlist, &a, &b)) {
                    return HPy_NULL;
                }
                if (HPy_IsNull(b)) {
                    b = HPyLong_FromLong(ctx, 5);
                    HPyTracker_Add(ctx, ht, b);
                }
                res = HPy_Add(ctx, a, b);
                HPyTracker_Close(ctx, ht);
                return res;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(a=3, b=2) == 5
        assert mod.f(3, 2) == 5
        assert mod.f(a=3) == 8
        assert mod.f(3) == 8

    def test_unsupported_fmt(self):
        import pytest
        mod = self.make_two_arg_add(fmt="ZZ:two_add")
        with pytest.raises(SystemError) as exc:
            mod.f("a")
        assert str(exc.value) == "two_add() unknown arg format code"

    def test_missing_required_argument(self):
        import pytest
        mod = self.make_two_arg_add(fmt="OO:add_two")
        with pytest.raises(TypeError) as exc:
            mod.f(1)
        assert str(exc.value) == "add_two() no value for required argument"

    def test_mismatched_args_too_few_keywords(self):
        import pytest
        mod = self.make_two_arg_add(fmt="OOO:add_two")
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == "add_two() mismatched args (too few keywords for fmt)"

    def test_mismatched_args_too_many_keywords(self):
        import pytest
        mod = self.make_two_arg_add(fmt="O:add_two")
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == "add_two() mismatched args (too many keywords for fmt)"

    def test_blank_keyword_argument_exception(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_KEYWORDS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs, HPy kw)
            {
                long a, b, c;
                static const char *kwlist[] = { "", "b", "", NULL };
                if (!HPyArg_ParseKeywords(ctx, NULL, args, nargs, kw, "lll", kwlist,
                                          &a, &b, &c))
                    return HPy_NULL;
                return HPy_Dup(ctx, ctx->h_None);
            }
            @EXPORT(f)
            @INIT
        """)
        with pytest.raises(SystemError) as exc:
            mod.f()
        assert str(exc.value) == "function empty keyword parameter name"

    def test_positional_only_argument(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_KEYWORDS)
            static HPy f_impl(HPyContext *ctx, HPy self,
                              HPy *args, HPy_ssize_t nargs, HPy kw)
            {
                HPy a;
                HPy b = HPy_NULL;
                HPyTracker ht;
                HPy res;
                static const char *kwlist[] = { "", "b", NULL };
                if (!HPyArg_ParseKeywords(ctx, &ht, args, nargs, kw, "O|O", kwlist, &a, &b)) {
                    return HPy_NULL;
                }
                if (HPy_IsNull(b)) {
                    b = HPyLong_FromLong(ctx, 5);
                    HPyTracker_Add(ctx, ht, b);
                }
                res = HPy_Add(ctx, a, b);
                HPyTracker_Close(ctx, ht);
                return res;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(1, b=2) == 3
        assert mod.f(1, 2) == 3
        assert mod.f(1) == 6
        with pytest.raises(TypeError) as exc:
            mod.f(a=1, b=2)
        assert str(exc.value) == "function no value for required argument"

    def test_keyword_only_argument(self):
        import pytest
        mod = self.make_two_arg_add(fmt="O$O")
        assert mod.f(1, b=2) == 3
        assert mod.f(a=1, b=2) == 3
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == (
            "function keyword only argument passed as positional argument")

    def test_error_default_message(self):
        import pytest
        mod = self.make_two_arg_add(fmt="OOO")
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == "function mismatched args (too few keywords for fmt)"

    def test_error_with_function_name(self):
        import pytest
        mod = self.make_two_arg_add(fmt="OOO:my_func")
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == "my_func() mismatched args (too few keywords for fmt)"

    def test_error_with_overridden_message(self):
        import pytest
        mod = self.make_two_arg_add(fmt="OOO;my-error-message")
        with pytest.raises(TypeError) as exc:
            mod.f(1, 2)
        assert str(exc.value) == "my-error-message"
