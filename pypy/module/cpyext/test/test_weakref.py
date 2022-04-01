from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.weakrefobject import PyWeakref_NewRef

class TestWeakReference(BaseApiTest):
    def test_weakref(self, space, api):
        w_obj = space.w_Exception
        w_ref = api.PyWeakref_NewRef(w_obj, space.w_None)
        assert w_ref is not None
        assert space.is_w(api.PyWeakref_GetObject(w_ref), w_obj)
        assert space.is_w(api.PyWeakref_LockObject(w_ref), w_obj)

        w_obj = space.newtuple([])
        with raises_w(space, TypeError):
            PyWeakref_NewRef(space, w_obj, space.w_None)

    def test_proxy(self, space, api):
        w_obj = space.w_Warning  # some weakrefable object
        w_proxy = api.PyWeakref_NewProxy(w_obj, None)
        assert space.unwrap(space.str(w_proxy)) == "<class 'Warning'>"
        assert space.unwrap(space.repr(w_proxy)).startswith('<weak')

    def test_weakref_lockobject(self, space, api):
        # some new weakrefable object
        w_obj = space.call_function(space.w_type, space.wrap("newtype"),
                                    space.newtuple([]), space.newdict())
        assert w_obj is not None

        w_ref = api.PyWeakref_NewRef(w_obj, space.w_None)
        assert w_obj is not None

        assert space.is_w(api.PyWeakref_LockObject(w_ref), w_obj)
        del w_obj
        import gc; gc.collect()
        assert space.is_w(api.PyWeakref_LockObject(w_ref), space.w_None)


class AppTestWeakReference(AppTestCpythonExtensionBase):

    def test_weakref_macro(self):
        module = self.import_extension('foo', [
            ("test_macro_cast", "METH_NOARGS",
             """
             // PyExc_Warning is some weak-reffable PyObject*.
             char* dumb_pointer;
             PyObject* weakref_obj = PyWeakref_NewRef(PyExc_Warning, NULL);
             if (!weakref_obj) return weakref_obj;
             // No public PyWeakReference type.
             dumb_pointer = (char*) weakref_obj;

             PyWeakref_GET_OBJECT(weakref_obj);
             PyWeakref_GET_OBJECT(dumb_pointer);

             return weakref_obj;
             """
            )
        ])
        module.test_macro_cast()

    def test_weakref_check(self):
        module = self.import_extension('foo', [
            ("test_weakref_cast", "METH_O",
             """
             return Py_BuildValue("iiii",
                                  (int)PyWeakref_Check(args),
                                  (int)PyWeakref_CheckRef(args),
                                  (int)PyWeakref_CheckRefExact(args),
                                  (int)PyWeakref_CheckProxy(args));
             """
            )
        ])
        import weakref
        def foo(): pass
        class Bar(object):
            pass
        bar = Bar()
        assert module.test_weakref_cast([]) == (0, 0, 0, 0)
        assert module.test_weakref_cast(weakref.ref(foo)) == (1, 1, 1, 0)
        assert module.test_weakref_cast(weakref.ref(bar)) == (1, 1, 1, 0)
        assert module.test_weakref_cast(weakref.proxy(foo)) == (1, 0, 0, 1)
        assert module.test_weakref_cast(weakref.proxy(bar)) == (1, 0, 0, 1)
        class X(weakref.ref):
            pass
        assert module.test_weakref_cast(X(foo)) == (1, 1, 0, 0)
        assert module.test_weakref_cast(X(bar)) == (1, 1, 0, 0)
