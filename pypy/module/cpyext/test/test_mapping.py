from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.module.cpyext.pyobject import get_w_obj_and_decref


class TestMapping(BaseApiTest):
    def test_check(self, space, api):
        assert api.PyMapping_Check(space.newdict())
        assert not api.PyMapping_Check(space.newlist([]))
        assert not api.PyMapping_Check(space.newtuple([]))

    def test_size(self, space, api):
        w_d = space.newdict()
        space.setitem(w_d, space.wrap("a"), space.wrap("b"))

        assert api.PyMapping_Size(w_d) == 1
        assert api.PyMapping_Length(w_d) == 1

    def test_keys(self, space, api):
        w_d = space.newdict()
        space.setitem(w_d, space.wrap("a"), space.wrap("b"))

        assert space.eq_w(api.PyMapping_Keys(w_d), space.wrap(["a"]))
        assert space.eq_w(api.PyMapping_Values(w_d), space.wrap(["b"]))
        assert space.eq_w(api.PyMapping_Items(w_d), space.wrap([("a", "b")]))

    def test_setitemstring(self, space, api):
        w_d = space.newdict()
        key = rffi.str2charp("key")
        api.PyMapping_SetItemString(w_d, key, space.wrap(42))
        assert 42 == space.unwrap(get_w_obj_and_decref(space,
            api.PyMapping_GetItemString(w_d, key)))
        rffi.free_charp(key)

    def test_haskey(self, space, api):
        w_d = space.newdict()
        space.setitem(w_d, space.wrap("a"), space.wrap("b"))

        assert api.PyMapping_HasKey(w_d, space.wrap("a"))
        assert not api.PyMapping_HasKey(w_d, space.wrap("b"))

        assert api.PyMapping_HasKey(w_d, w_d) == 0
        # and no error is set

