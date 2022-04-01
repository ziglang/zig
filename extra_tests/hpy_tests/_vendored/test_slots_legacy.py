""" HPyType slot tests on legacy types. """
import pytest

from .support import HPyTest
from .test_hpytype_legacy import LegacyPointTemplate
from .test_slots import TestSlots as _TestSlots, TestSqSlots as _TestSqSlots


class TestLegacySlots(_TestSlots):

    ExtensionTemplate = LegacyPointTemplate


class TestLegacySqSlots(_TestSqSlots):

    ExtensionTemplate = LegacyPointTemplate


class TestCustomLegacySlotsFeatures(HPyTest):

    def test_legacy_slots(self):
        mod = self.make_module("""
            #include <Python.h>

            static PyObject *Dummy_repr(PyObject *self)
            {
                return PyUnicode_FromString("myrepr");
            }

            static PyObject *Dummy_add(PyObject *self, PyObject *other)
            {
                return Py_BuildValue("OO", self, other);
            }

            HPyDef_SLOT(Dummy_abs, Dummy_abs_impl, HPy_nb_absolute);
            static HPy Dummy_abs_impl(HPyContext *ctx, HPy self)
            {
                return HPyLong_FromLong(ctx, 1234);
            }

            static HPyDef *Dummy_defines[] = {
                &Dummy_abs,
                NULL
            };
            static PyType_Slot Dummy_type_slots[] = {
                {Py_tp_repr, Dummy_repr},
                {Py_nb_add, Dummy_add},
                {0, 0},
            };
            static HPyType_Spec Dummy_spec = {
                .name = "mytest.Dummy",
                .legacy = true,
                .legacy_slots = Dummy_type_slots,
                .defines = Dummy_defines
            };

            @EXPORT_TYPE("Dummy", Dummy_spec)
            @INIT
        """)
        d = mod.Dummy()
        assert repr(d) == 'myrepr'
        assert d + 42 == (d, 42)
        assert abs(d) == 1234

    def test_legacy_slots_methods(self):
        mod = self.make_module("""
            #include <Python.h>

            static PyObject *Dummy_foo(PyObject *self, PyObject *arg)
            {
                Py_INCREF(arg);
                return arg;
            }

            HPyDef_METH(Dummy_bar, "bar", Dummy_bar_impl, HPyFunc_NOARGS)
            static HPy Dummy_bar_impl(HPyContext *ctx, HPy self)
            {
                return HPyLong_FromLong(ctx, 1234);
            }

            static PyMethodDef dummy_methods[] = {
               {"foo", Dummy_foo, METH_O},
               {NULL, NULL}         /* Sentinel */
            };

            static PyType_Slot dummy_type_slots[] = {
                {Py_tp_methods, dummy_methods},
                {0, 0},
            };

            static HPyDef *dummy_type_defines[] = {
                    &Dummy_bar,
                    NULL
            };

            static HPyType_Spec dummy_type_spec = {
                .name = "mytest.Dummy",
                .legacy = true,
                .legacy_slots = dummy_type_slots,
                .defines = dummy_type_defines
            };

            @EXPORT_TYPE("Dummy", dummy_type_spec)
            @INIT
        """)
        d = mod.Dummy()
        assert d.foo(21) == 21
        assert d.bar() == 1234

    def test_legacy_slots_members(self):
        import pytest
        mod = self.make_module("""
            #include <Python.h>
            #include "structmember.h"

            typedef struct {
                PyObject_HEAD
                long x;
                long y;
            } PointObject;

            HPyDef_SLOT(Point_new, Point_new_impl, HPy_tp_new)
            static HPy Point_new_impl(HPyContext *ctx, HPy cls, HPy *args,
                                      HPy_ssize_t nargs, HPy kw)
            {
                PointObject *point;
                HPy h_point = HPy_New(ctx, cls, &point);
                if (HPy_IsNull(h_point))
                    return HPy_NULL;
                point->x = 7;
                point->y = 3;
                return h_point;
            }

            HPyDef_MEMBER(Point_x, "x", HPyMember_LONG, offsetof(PointObject, x))

            // legacy members
            static PyMemberDef legacy_members[] = {
                {"y", T_LONG, offsetof(PointObject, y), 0},
                {"y_ro", T_LONG, offsetof(PointObject, y), READONLY},
                {NULL}
            };

            static PyType_Slot legacy_slots[] = {
                {Py_tp_members, legacy_members},
                {0, NULL}
            };

            static HPyDef *Point_defines[] = {
                &Point_new,
                &Point_x,
                NULL
            };
            static HPyType_Spec Point_spec = {
                .name = "mytest.Point",
                .basicsize = sizeof(PointObject),
                .defines = Point_defines,
                .legacy = true,
                .legacy_slots = legacy_slots
            };

            @EXPORT_TYPE("Point", Point_spec)
            @INIT
        """)
        p = mod.Point()
        assert p.x == 7
        assert p.y == 3
        assert p.y_ro == 3
        p.x = 123
        p.y = 456
        with pytest.raises(AttributeError):
            p.y_ro = 789
        assert p.x == 123
        assert p.y == 456

    @pytest.mark.xfail
    def test_legacy_slots_getsets(self):
        mod = self.make_module("""
            #include <Python.h>

            typedef struct {
                PyObject_HEAD
                long x;
                long y;
            } PointObject;

            HPyDef_SLOT(Point_new, Point_new_impl, HPy_tp_new)
            static HPy Point_new_impl(HPyContext *ctx, HPy cls, HPy *args,
                                      HPy_ssize_t nargs, HPy kw)
            {
                PointObject *point;
                HPy h_point = HPy_New(ctx, cls, &point);
                if (HPy_IsNull(h_point))
                    return HPy_NULL;
                point->x = 7;
                point->y = 3;
                return h_point;
            }

            static PyObject *z_get(PointObject *point, void *closure)
            {
                long z = point->x*10 + point->y + (long)(HPy_ssize_t)closure;
                return PyLong_FromLong(z);
            }

            // legacy getsets
            static PyGetSetDef legacy_getsets[] = {
                {"z", (getter)z_get, NULL, NULL, (void *)2000},
                {NULL}
            };

            static PyType_Slot legacy_slots[] = {
                {Py_tp_getset, legacy_getsets},
                {0, NULL}
            };

            static HPyDef *Point_defines[] = {
                &Point_new,
                NULL
            };
            static HPyType_Spec Point_spec = {
                .name = "mytest.Point",
                .basicsize = sizeof(PointObject),
                .defines = Point_defines,
                .legacy = true,
                .legacy_slots = legacy_slots
            };

            @EXPORT_TYPE("Point", Point_spec)
            @INIT
        """)
        p = mod.Point()
        assert p.z == 2073

    def test_legacy_slots_fails_without_legacy(self):
        import pytest
        mod_src = """
            #include <Python.h>

            static PyObject *Dummy_foo(PyObject *self, PyObject *arg)
            {
                Py_INCREF(arg);
                return arg;
            }

            static PyMethodDef dummy_methods[] = {
               {"foo", Dummy_foo, METH_O},
               {NULL, NULL}         /* Sentinel */
            };

            static PyType_Slot dummy_type_slots[] = {
                {Py_tp_methods, dummy_methods},
                {0, 0},
            };

            static HPyType_Spec dummy_type_spec = {
                .name = "mytest.Dummy",
                .legacy = false,
                .legacy_slots = dummy_type_slots,
            };

            @EXPORT_TYPE("Dummy", dummy_type_spec)
            @INIT
        """
        with pytest.raises(TypeError) as err:
            self.make_module(mod_src)
        assert str(err.value) == (
            "cannot specify .legacy_slots without setting .legacy=true")
