from .support import HPyTest
from .test_hpytype import PointTemplate


class TestSlots(HPyTest):

    ExtensionTemplate = PointTemplate

    def test_tp_init(self):
        mod = self.make_module("""
            @DEFINE_PointObject
            @DEFINE_Point_xy
            HPyDef_SLOT(Point_new, HPyType_GenericNew, HPy_tp_new)

            HPyDef_SLOT(Point_init, Point_init_impl, HPy_tp_init)
            static int Point_init_impl(HPyContext *ctx, HPy self, HPy *args,
                                       HPy_ssize_t nargs, HPy kw)
            {
                long x, y;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "ll", &x, &y))
                    return -1;

                PointObject *p = PointObject_AsStruct(ctx, self);
                p->x = x;
                p->y = y;
                return 0;
            }

            @EXPORT_POINT_TYPE(&Point_new, &Point_init, &Point_x, &Point_y)
            @INIT
        """)
        p = mod.Point(1, 2)
        assert p.x == 1
        assert p.y == 2

    def test_tp_destroy(self):
        import gc
        mod = self.make_module("""
            @DEFINE_PointObject
            @DEFINE_Point_new

            static long destroyed_x;

            HPyDef_SLOT(Point_destroy, Point_destroy_impl, HPy_tp_destroy)
            static void Point_destroy_impl(void *obj)
            {
                PointObject *point = (PointObject *)obj;
                destroyed_x += point->x;
            }

            HPyDef_METH(get_destroyed_x, "get_destroyed_x", get_destroyed_x_impl, HPyFunc_NOARGS)
            static HPy get_destroyed_x_impl(HPyContext *ctx, HPy self)
            {
                return HPyLong_FromLong(ctx, destroyed_x);
            }

            @EXPORT_POINT_TYPE(&Point_new, &Point_destroy)
            @EXPORT(get_destroyed_x)
            @INIT
        """)
        point = mod.Point(7, 3)
        assert mod.get_destroyed_x() == 0
        del point
        gc.collect()
        assert mod.get_destroyed_x() == 7
        gc.collect()
        assert mod.get_destroyed_x() == 7

    def test_nb_ops_binary(self):
        import operator
        mod = self.make_module(r"""
            @DEFINE_PointObject

            #define MYSLOT(NAME)                                               \
                HPyDef_SLOT(p_##NAME, NAME##_impl, HPy_nb_##NAME);             \
                static HPy NAME##_impl(HPyContext *ctx, HPy self, HPy other)    \
                {                                                              \
                    HPy s = HPyUnicode_FromString(ctx, #NAME);                 \
                    HPy res = HPyTuple_Pack(ctx, 3, self, s, other);           \
                    HPy_Close(ctx, s);                                         \
                    return res;                                                \
                }

            MYSLOT(add)
            MYSLOT(and)
            MYSLOT(divmod)
            MYSLOT(floor_divide)
            MYSLOT(lshift)
            MYSLOT(multiply)
            MYSLOT(or)
            MYSLOT(remainder)
            MYSLOT(rshift)
            MYSLOT(subtract)
            MYSLOT(true_divide)
            MYSLOT(xor)
            MYSLOT(matrix_multiply)

            @EXPORT_POINT_TYPE(&p_add, &p_and, &p_divmod, &p_floor_divide, &p_lshift, &p_multiply, &p_or, &p_remainder, &p_rshift, &p_subtract, &p_true_divide, &p_xor, &p_matrix_multiply)
            @INIT
        """)
        p = mod.Point()
        assert p + 42 == (p, "add", 42)
        assert p & 42 == (p, "and", 42)
        assert divmod(p, 42) == (p, "divmod", 42)
        assert p // 42 == (p, "floor_divide", 42)
        assert p << 42 == (p, "lshift", 42)
        assert p * 42 == (p, "multiply", 42)
        assert p | 42 == (p, "or", 42)
        assert p % 42 == (p, "remainder", 42)
        assert p >> 42 == (p, "rshift", 42)
        assert p - 42 == (p, "subtract", 42)
        assert p / 42 == (p, "true_divide", 42)
        assert p ^ 42 == (p, "xor", 42)
        # we can't use '@' because we want to be importable on py27
        assert operator.matmul(p, 42) == (p, "matrix_multiply", 42)

    def test_nb_ops_inplace(self):
        import operator
        mod = self.make_module(r"""
            @DEFINE_PointObject

            #define MYSLOT(NAME)                                               \
                HPyDef_SLOT(p_##NAME, NAME##_impl, HPy_nb_##NAME);             \
                static HPy NAME##_impl(HPyContext *ctx, HPy self, HPy other)    \
                {                                                              \
                    HPy s = HPyUnicode_FromString(ctx, #NAME);                 \
                    HPy res = HPyTuple_Pack(ctx, 3, self, s, other);           \
                    HPy_Close(ctx, s);                                         \
                    return res;                                                \
                }

            MYSLOT(inplace_add)
            MYSLOT(inplace_and)
            MYSLOT(inplace_floor_divide)
            MYSLOT(inplace_lshift)
            MYSLOT(inplace_multiply)
            MYSLOT(inplace_or)
            MYSLOT(inplace_remainder)
            MYSLOT(inplace_rshift)
            MYSLOT(inplace_subtract)
            MYSLOT(inplace_true_divide)
            MYSLOT(inplace_xor)
            MYSLOT(inplace_matrix_multiply)

            @EXPORT_POINT_TYPE(&p_inplace_add, &p_inplace_and, &p_inplace_floor_divide, &p_inplace_lshift, &p_inplace_multiply, &p_inplace_or, &p_inplace_remainder, &p_inplace_rshift, &p_inplace_subtract, &p_inplace_true_divide, &p_inplace_xor, &p_inplace_matrix_multiply)
            @INIT
        """)
        p = mod.Point()
        tmp = p; tmp += 42; assert tmp == (p, "inplace_add", 42)
        tmp = p; tmp &= 42; assert tmp == (p, "inplace_and", 42)
        tmp = p; tmp //= 42; assert tmp == (p, "inplace_floor_divide", 42)
        tmp = p; tmp <<= 42; assert tmp == (p, "inplace_lshift", 42)
        tmp = p; tmp *= 42; assert tmp == (p, "inplace_multiply", 42)
        tmp = p; tmp |= 42; assert tmp == (p, "inplace_or", 42)
        tmp = p; tmp %= 42; assert tmp == (p, "inplace_remainder", 42)
        tmp = p; tmp >>= 42; assert tmp == (p, "inplace_rshift", 42)
        tmp = p; tmp -= 42; assert tmp == (p, "inplace_subtract", 42)
        tmp = p; tmp /= 42; assert tmp == (p, "inplace_true_divide", 42)
        tmp = p; tmp ^= 42; assert tmp == (p, "inplace_xor", 42)
        #
        # we can't use '@=' because we want to be importable on py27
        tmp = p
        tmp = operator.imatmul(p, 42)
        assert tmp == (p, "inplace_matrix_multiply", 42)

    def test_nb_ops_unary(self):
        mod = self.make_module(r"""
            @DEFINE_PointObject

            #define MYSLOT(NAME)                                               \
                HPyDef_SLOT(p_##NAME, NAME##_impl, HPy_nb_##NAME);             \
                static HPy NAME##_impl(HPyContext *ctx, HPy self)               \
                {                                                              \
                    HPy s = HPyUnicode_FromString(ctx, #NAME);                 \
                    HPy res = HPyTuple_Pack(ctx, 2, s, self);                  \
                    HPy_Close(ctx, s);                                         \
                    return res;                                                \
                }

            MYSLOT(negative)
            MYSLOT(positive)
            MYSLOT(absolute)
            MYSLOT(invert)

            @EXPORT_POINT_TYPE(&p_negative, &p_positive, &p_absolute, &p_invert)
            @INIT
        """)
        p = mod.Point()
        assert +p == ('positive', p)
        assert -p == ('negative', p)
        assert abs(p) == ('absolute', p)
        assert ~p == ('invert', p)

    def test_nb_ops_type_conversion(self):
        import operator
        mod = self.make_module(r"""
            @DEFINE_PointObject
            @DEFINE_Point_new

            HPyDef_SLOT(p_int, p_int_impl, HPy_nb_int);
            static HPy p_int_impl(HPyContext *ctx, HPy self)
            {
                return HPyLong_FromLong(ctx, 42);
            }

            HPyDef_SLOT(p_float, p_float_impl, HPy_nb_float);
            static HPy p_float_impl(HPyContext *ctx, HPy self)
            {
                return HPyFloat_FromDouble(ctx, 123.4);
            }

            HPyDef_SLOT(p_index, p_index_impl, HPy_nb_index);
            static HPy p_index_impl(HPyContext *ctx, HPy self)
            {
                return HPyLong_FromLong(ctx, -456);
            }

            HPyDef_SLOT(p_bool, p_bool_impl, HPy_nb_bool);
            static int p_bool_impl(HPyContext *ctx, HPy self)
            {
                PointObject *point = PointObject_AsStruct(ctx, self);
                return (point->x != 0);
            }

            @EXPORT_POINT_TYPE(&Point_new, &p_int, &p_float, &p_index, &p_bool)
            @INIT
        """)
        p = mod.Point(0, 0)
        assert int(p) == 42
        assert float(p) == 123.4
        assert operator.index(p) == -456
        #
        assert bool(mod.Point(0, 0)) is False
        assert bool(mod.Point(1, 0)) is True

    def test_nb_ops_power(self):
        mod = self.make_module(r"""
            @DEFINE_PointObject

            HPyDef_SLOT(p_power, p_power_impl, HPy_nb_power);
            static HPy p_power_impl(HPyContext *ctx, HPy self, HPy x, HPy y)
            {
                HPy s = HPyUnicode_FromString(ctx, "power");
                HPy res = HPyTuple_Pack(ctx, 4, self, s, x, y);
                HPy_Close(ctx, s);
                return res;
            }

            HPyDef_SLOT(p_inplace_power, p_inplace_power_impl, HPy_nb_inplace_power);
            static HPy p_inplace_power_impl(HPyContext *ctx, HPy self, HPy x, HPy y)
            {
                HPy s = HPyUnicode_FromString(ctx, "inplace_power");
                HPy res = HPyTuple_Pack(ctx, 4, self, s, x, y);
                HPy_Close(ctx, s);
                return res;
            }

            @EXPORT_POINT_TYPE(&p_power, &p_inplace_power)
            @INIT
        """)
        p = mod.Point()
        assert p**42 == (p, 'power', 42, None)
        assert pow(p, 42, 123) == (p, 'power', 42, 123)
        tmp = p
        tmp **= 42
        assert tmp == (p, 'inplace_power', 42, None)

    def test_buffer(self):
        import pytest
        import sys
        mod = self.make_module("""
            @TYPE_STRUCT_BEGIN(FakeArrayObject)
                int exports;
            @TYPE_STRUCT_END

            HPyDef_SLOT(FakeArray_new, new_fakearray_impl, HPy_tp_new)
            static HPy new_fakearray_impl(HPyContext *ctx, HPy cls, HPy *args,
                                          HPy_ssize_t nargs, HPy kw)
            {
                if (!HPyArg_Parse(ctx, NULL, args, nargs, ""))
                    return HPy_NULL;
                FakeArrayObject *arr;
                HPy h_arr = HPy_New(ctx, cls, &arr);
                if (HPy_IsNull(h_arr))
                    return HPy_NULL;
                arr->exports = 0;
                return h_arr;
            }

            static char static_mem[12] = {0,1,2,3,4,5,6,7,8,9,10,11};
            static HPy_ssize_t _shape[1] = {12};
            static HPy_ssize_t _strides[1] = {1};

            HPyDef_SLOT(FakeArray_getbuffer, _getbuffer_impl, HPy_bf_getbuffer)
            static int _getbuffer_impl(HPyContext *ctx, HPy self, HPy_buffer* buf, int flags) {
                FakeArrayObject *arr = FakeArrayObject_AsStruct(ctx, self);
                if (arr->exports > 0) {
                    buf->obj = HPy_NULL;
                    HPyErr_SetString(ctx, ctx->h_BufferError,
                               "only one buffer allowed");
                    return -1;
                }
                arr->exports++;
                buf->buf = static_mem;
                buf->len = 12;
                buf->itemsize = 1;
                buf->readonly = 1;
                buf->ndim = 1;
                buf->format = "B";
                buf->shape = _shape;
                buf->strides = _strides;
                buf->suboffsets = NULL;
                buf->internal = NULL;
                buf->obj = HPy_Dup(ctx, self);
                return 0;
            }

            HPyDef_SLOT(FakeArray_releasebuffer, _relbuffer_impl, HPy_bf_releasebuffer)
            static void _relbuffer_impl(HPyContext *ctx, HPy h_obj, HPy_buffer* buf) {
                FakeArrayObject *arr = FakeArrayObject_AsStruct(ctx, h_obj);
                arr->exports--;
            }

            static HPyDef *FakeArray_defines[] = {
                &FakeArray_new,
                &FakeArray_getbuffer,
                &FakeArray_releasebuffer,
                NULL
            };

            static HPyType_Spec FakeArray_Spec = {
                .name = "mytest.FakeArray",
                .basicsize = sizeof(FakeArrayObject),
                .defines = FakeArray_defines,
                .legacy = FakeArrayObject_IS_LEGACY,
            };

            @EXPORT_TYPE("FakeArray", FakeArray_Spec)
            @INIT
        """)
        arr = mod.FakeArray()
        if self.supports_refcounts():
            init_refcount = sys.getrefcount(arr)
        with memoryview(arr) as mv:
            with pytest.raises(BufferError):
                mv2 = memoryview(arr)
            if self.supports_refcounts():
                assert sys.getrefcount(arr) == init_refcount + 1
            for i in range(12):
                assert mv[i] == i
        if self.supports_refcounts():
            assert sys.getrefcount(arr) == init_refcount
        mv2 = memoryview(arr)  # doesn't raise


class TestSqSlots(HPyTest):

    ExtensionTemplate = PointTemplate

    def test_sq_item_and_sq_length(self):
        mod = self.make_module("""
            @DEFINE_PointObject

            HPyDef_SLOT(Point_getitem, Point_getitem_impl, HPy_sq_item);
            static HPy Point_getitem_impl(HPyContext *ctx, HPy self, HPy_ssize_t idx)
            {
                return HPyLong_FromLong(ctx, (long)idx*2);
            }

            HPyDef_SLOT(Point_length, Point_length_impl, HPy_sq_length);
            static HPy_ssize_t Point_length_impl(HPyContext *ctx, HPy self)
            {
                return 1234;
            }

            @EXPORT_POINT_TYPE(&Point_getitem, &Point_length)
            @INIT
        """)
        p = mod.Point()
        assert len(p) == 1234
        assert p[4] == 8
        assert p[21] == 42
        assert p[-1] == 1233 * 2

    def test_sq_ass_item(self):
        import pytest
        mod = self.make_module("""
            @DEFINE_PointObject
            @DEFINE_Point_new
            @DEFINE_Point_xy

            HPyDef_SLOT(Point_len, Point_len_impl, HPy_sq_length);
            static HPy_ssize_t Point_len_impl(HPyContext *ctx, HPy self)
            {
                return 2;
            }

            HPyDef_SLOT(Point_setitem, Point_setitem_impl, HPy_sq_ass_item);
            static int Point_setitem_impl(HPyContext *ctx, HPy self, HPy_ssize_t idx,
                                          HPy h_value)
            {
                long value;
                if (HPy_IsNull(h_value))
                    value = -123; // this is the del p[] case
                else {
                    value = HPyLong_AsLong(ctx, h_value);
                    if (HPyErr_Occurred(ctx))
                        return -1;
                }
                PointObject *point = PointObject_AsStruct(ctx, self);
                if (idx == 0)
                    point->x = value;
                else if (idx == 1)
                    point->y = value;
                else {
                    HPyErr_SetString(ctx, ctx->h_IndexError, "invalid index");
                    return -1;
                }
                return 0;
            }

            @EXPORT_POINT_TYPE(&Point_new, &Point_x, &Point_y, &Point_len, &Point_setitem)
            @INIT
        """)
        p = mod.Point(1, 2)
        # check __setitem__
        p[0] = 100
        assert p.x == 100
        p[1] = 200
        assert p.y == 200
        with pytest.raises(IndexError):
            p[2] = 300
        # check __delitem__
        del p[0]
        assert p.x == -123
        del p[1]
        assert p.y == -123
        # check negative indexes
        p[-2] = 400
        p[-1] = 500
        assert p.x == 400
        assert p.y == 500
        del p[-2]
        assert p.x == -123
        del p[-1]
        assert p.y == -123

    def test_sq_concat_and_sq_inplace_concat(self):
        mod = self.make_module("""
            @DEFINE_PointObject

            HPyDef_SLOT(Point_concat, Point_concat_impl, HPy_sq_concat);
            static HPy Point_concat_impl(HPyContext *ctx, HPy self, HPy other)
            {
                HPy s = HPyUnicode_FromString(ctx, "sq_concat");
                HPy res = HPyTuple_Pack(ctx, 3, self, s, other);
                HPy_Close(ctx, s);
                return res;
            }

            HPyDef_SLOT(Point_inplace_concat, Point_inplace_concat_impl,
                        HPy_sq_inplace_concat);
            static HPy Point_inplace_concat_impl(HPyContext *ctx, HPy self, HPy other)
            {
                HPy s = HPyUnicode_FromString(ctx, "sq_inplace_concat");
                HPy res = HPyTuple_Pack(ctx, 3, self, s, other);
                HPy_Close(ctx, s);
                return res;
            }

            @EXPORT_POINT_TYPE(&Point_concat, &Point_inplace_concat)
            @INIT
        """)
        p = mod.Point()
        res = p + 42
        assert res == (p, "sq_concat", 42)
        #
        tmp = p
        tmp += 43
        assert tmp == (p, "sq_inplace_concat", 43)

    def test_sq_repeat_and_sq_inplace_repeat(self):
        mod = self.make_module("""
            @DEFINE_PointObject

            HPyDef_SLOT(Point_repeat, Point_repeat_impl, HPy_sq_repeat);
            static HPy Point_repeat_impl(HPyContext *ctx, HPy self, HPy_ssize_t t)
            {
                HPy s = HPyUnicode_FromString(ctx, "sq_repeat");
                HPy other = HPyLong_FromLong(ctx, (long) t);
                HPy res = HPyTuple_Pack(ctx, 3, self, s, other);
                HPy_Close(ctx, other);
                HPy_Close(ctx, s);
                return res;
            }

            HPyDef_SLOT(Point_inplace_repeat, Point_inplace_repeat_impl,
                        HPy_sq_inplace_repeat);
            static HPy Point_inplace_repeat_impl(HPyContext *ctx, HPy self, HPy_ssize_t t)
            {
                HPy s = HPyUnicode_FromString(ctx, "sq_inplace_repeat");
                HPy other = HPyLong_FromLong(ctx, (long) t);
                HPy res = HPyTuple_Pack(ctx, 3, self, s, other);
                HPy_Close(ctx, other);
                HPy_Close(ctx, s);
                return res;
            }

            @EXPORT_POINT_TYPE(&Point_repeat, &Point_inplace_repeat)
            @INIT
        """)
        p = mod.Point()
        res = p * 42
        assert res == (p, "sq_repeat", 42)
        #
        tmp = p
        tmp *= 43
        assert tmp == (p, "sq_inplace_repeat", 43)

    def test_sq_contains(self):
        import pytest
        mod = self.make_module("""
            @DEFINE_PointObject

            HPyDef_SLOT(Point_contains, Point_contains_impl, HPy_sq_contains);
            static int Point_contains_impl(HPyContext *ctx, HPy self, HPy other)
            {
                long val = HPyLong_AsLong(ctx, other);
                if (HPyErr_Occurred(ctx))
                    return -1;
                if (val == 42)
                    return 1;
                return 0;
            }

            @EXPORT_POINT_TYPE(&Point_contains)
            @INIT
        """)
        p = mod.Point()
        assert 42 in p
        assert 43 not in p
        with pytest.raises(TypeError):
            'hello' in p

    def test_tp_richcompare(self):
        import pytest
        mod = self.make_module("""
            @DEFINE_PointObject
            @DEFINE_Point_new

            HPyDef_SLOT(Point_cmp, Point_cmp_impl, HPy_tp_richcompare);
            static HPy Point_cmp_impl(HPyContext *ctx, HPy self, HPy o, HPy_RichCmpOp op)
            {
                // XXX we should check the type of o
                PointObject *p1 = PointObject_AsStruct(ctx, self);
                PointObject *p2 = PointObject_AsStruct(ctx, o);
                HPy_RETURN_RICHCOMPARE(ctx, p1->x, p2->x, op);
            }

            @EXPORT_POINT_TYPE(&Point_new, &Point_cmp)
            @INIT
        """)
        p1 = mod.Point(10, 10)
        p2 = mod.Point(20, 20)
        assert p1 == p1
        assert not p1 == p2
        #
        assert p1 != p2
        assert not p1 != p1
        #
        assert p1 < p2
        assert not p1 < p1
        #
        assert not p1 > p2
        assert not p1 > p1
        #
        assert p1 <= p2
        assert p1 <= p1
        #
        assert not p1 >= p2
        assert p1 >= p1
