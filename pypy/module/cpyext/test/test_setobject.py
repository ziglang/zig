from rpython.rtyper.lltypesystem import lltype
from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.setobject import (
    PySet_Check, PyFrozenSet_Check, PyFrozenSet_CheckExact,
    PySet_Add, PySet_Size, PySet_GET_SIZE)
from pypy.module.cpyext.api import Py_ssize_tP, PyObjectP
from pypy.module.cpyext.pyobject import from_ref


class TestTupleObject(BaseApiTest):
    def test_setobj(self, space):
        assert not PySet_Check(space, space.w_None)
        assert not PyFrozenSet_Check(space, space.w_None)
        with raises_w(space, SystemError):
            PySet_Add(space, space.w_None, space.w_None)
        w_set = space.call_function(space.w_set)
        assert not PyFrozenSet_CheckExact(space, w_set)
        space.call_method(w_set, 'update', space.wrap([1, 2, 3, 4]))
        assert PySet_Size(space, w_set) == 4
        assert PySet_GET_SIZE(space, w_set) == 4
        with raises_w(space, TypeError):
            PySet_Size(space, space.newlist([]))

    def test_set_add_discard(self, space, api):
        w_set = api.PySet_New(None)
        assert api.PySet_Size(w_set) == 0
        w_set = api.PyFrozenSet_New(space.wrap([1, 2, 3, 4]))
        assert api.PySet_Size(w_set) == 4
        w_set = api.PySet_New(space.wrap([1, 2, 3, 4]))
        assert api.PySet_Size(w_set) == 4
        api.PySet_Add(w_set, space.wrap(6))
        assert api.PySet_Size(w_set) == 5
        res = api.PySet_Discard(w_set, space.wrap(6))
        assert res == 1
        assert api.PySet_Size(w_set) == 4
        res = api.PySet_Discard(w_set, space.wrap(6))
        assert res == 0
        assert api.PySet_Size(w_set) == 4

    def test_frozenset_add(self, space, api):
        w_set = api.PyFrozenSet_New(None)
        api.PySet_Add(w_set, space.wrap(4))
        assert api.PySet_Size(w_set) == 1
        api.PySet_Add(w_set, space.wrap(5))
        assert api.PySet_Size(w_set) == 2
        assert space.hash_w(w_set) != 0   # makes the set really frozen
        with raises_w(space, SystemError):
            api.PySet_Add(w_set, space.wrap(6))

    def test_set_contains(self, space, api):
        w_set = api.PySet_New(space.wrap([1, 2, 3, 4]))
        assert api.PySet_Contains(w_set, space.wrap(1))
        assert not api.PySet_Contains(w_set, space.wrap(0))

    def test_set_pop_clear(self, space, api):
        w_set = api.PySet_New(space.wrap([1, 2, 3, 4]))
        w_obj = api.PySet_Pop(w_set)
        assert space.int_w(w_obj) in (1, 2, 3, 4)
        assert space.len_w(w_set) == 3
        api.PySet_Clear(w_set)
        assert space.len_w(w_set) == 0

    def test_anyset_check(self, space, api):
        w_set = api.PySet_New(space.wrap([1, 2, 3, 4]))
        w_frozenset = space.newfrozenset([space.wrap(i) for i in [1, 2, 3, 4]])
        assert api.PyAnySet_CheckExact(w_set)
        assert api.PyAnySet_CheckExact(w_frozenset)
        assert api.PyAnySet_Check(w_set)
        assert api.PyAnySet_Check(w_frozenset)
        w_instance = space.appexec([], """():
            class MySet(set):
                pass
            return MySet()
        """)
        assert api.PyAnySet_Check(w_instance)

    def test_pyset_next(self, space, api):
        w_set = space.call_function(space.w_set, space.newtext("ab"))
        with lltype.scoped_alloc(Py_ssize_tP.TO, 1) as pos_p:
            with lltype.scoped_alloc(PyObjectP.TO, 1) as result_p:
                pos_p[0] = 0
                res = api._PySet_Next(w_set, pos_p, result_p)
                assert res == 1
                letter1 = space.text_w(from_ref(space, result_p[0]))
                res = api._PySet_Next(w_set, pos_p, result_p)
                assert res == 1
                letter2 = space.text_w(from_ref(space, result_p[0]))
                res = api._PySet_Next(w_set, pos_p, result_p)
                assert res == 0
        assert set([letter1, letter2]) == set("ab")

    def test_pyset_nextentry(self, space, api):
        w_set = space.call_function(space.w_set, space.newtext("ab"))
        with lltype.scoped_alloc(Py_ssize_tP.TO, 1) as pos_p:
            with lltype.scoped_alloc(PyObjectP.TO, 1) as result_p:
                with lltype.scoped_alloc(Py_ssize_tP.TO, 1) as hash_p:
                    pos_p[0] = 0
                    res = api._PySet_NextEntry(w_set, pos_p, result_p, hash_p)
                    assert res == 1
                    w_obj = from_ref(space, result_p[0])
                    letter1 = space.text_w(w_obj)
                    assert hash_p[0] == space.hash_w(w_obj)
                    res = api._PySet_NextEntry(w_set, pos_p, result_p, hash_p)
                    assert res == 1
                    w_obj = from_ref(space, result_p[0])
                    letter2 = space.text_w(w_obj)
                    assert hash_p[0] == space.hash_w(w_obj)
                    res = api._PySet_NextEntry(w_set, pos_p, result_p, hash_p)
                    assert res == 0
        assert set([letter1, letter2]) == set("ab")


class AppTestSetObject(AppTestCpythonExtensionBase):
    def test_set_macro_cast(self):
        module = self.import_extension('foo', [
            ("test_macro_cast", "METH_NOARGS",
             """
             PyObject* o = PySet_New(NULL);
             // no PySetObject
             char* dumb_pointer = (char*) o;

             PySet_GET_SIZE(o);
             PySet_GET_SIZE(dumb_pointer);

             return o;
             """)
        ])
