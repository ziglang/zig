import pytest
from pypy.interpreter import gateway
from rpython.rtyper.lltypesystem import rffi
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.api import generic_cpy_call
from pypy.module.cpyext.pyobject import make_ref, from_ref, decref, as_pyobj
from pypy.module.cpyext.typeobject import cts, PyTypeObjectPtr, W_PyCTypeObject



class AppTestTypeObject(AppTestCpythonExtensionBase):

    def setup_class(cls):
        AppTestCpythonExtensionBase.setup_class.im_func(cls)
        def _check_uses_shortcut(w_inst):
            res = hasattr(w_inst, "_cpy_ref") and w_inst._cpy_ref
            res = res and as_pyobj(cls.space, w_inst) == w_inst._cpy_ref
            return cls.space.newbool(res)
        cls.w__check_uses_shortcut = cls.space.wrap(
            gateway.interp2app(_check_uses_shortcut))

    def test_typeobject(self):
        import sys
        module = self.import_module(name='foo')
        assert 'foo' in sys.modules
        assert "copy" in dir(module.fooType)
        obj = module.new()
        #print(obj.foo)
        assert obj.foo == 42
        #print("Obj has type", type(obj))
        assert type(obj) is module.fooType
        #print("type of obj has type", type(type(obj)))
        #print("type of type of obj has type", type(type(type(obj))))
        assert module.fooType.__doc__ == "foo is for testing."

    def test_typeobject_method_descriptor(self):
        module = self.import_module(name='foo')
        obj = module.new()
        obj2 = obj.copy()
        assert module.new().name == "Foo Example"
        c = module.fooType.copy
        assert not "im_func" in dir(module.fooType.copy)
        assert module.fooType.copy.__objclass__ is module.fooType
        assert "copy" in repr(module.fooType.copy)
        assert repr(module.fooType) == "<class 'foo.foo'>"
        assert repr(obj2) == "<Foo>"
        assert repr(module.fooType.__call__) == "<slot wrapper '__call__' of 'foo.foo' objects>"
        assert obj2(foo=1, bar=2) == dict(foo=1, bar=2)

        print(obj.foo)
        assert obj.foo == 42
        assert obj.int_member == obj.foo

    def test_typeobject_data_member(self):
        module = self.import_module(name='foo')
        obj = module.new()
        obj.int_member = 23
        assert obj.int_member == 23
        obj.int_member = 42
        raises(TypeError, "obj.int_member = 'not a number'")
        raises(TypeError, "del obj.int_member")
        raises(AttributeError, "obj.int_member_readonly = 42")
        exc = raises(AttributeError, "del obj.int_member_readonly")
        assert "readonly" in str(exc.value)
        raises(SystemError, "obj.broken_member")
        raises(SystemError, "obj.broken_member = 42")
        assert module.fooType.broken_member.__doc__ is None
        assert module.fooType.object_member.__doc__ == "A Python object."
        assert str(type(module.fooType.int_member)) == "<class 'member_descriptor'>"

    def test_typeobject_object_member(self):
        module = self.import_module(name='foo')
        obj = module.new()
        assert obj.object_member is None
        obj.object_member = "hello"
        assert obj.object_member == "hello"
        del obj.object_member
        del obj.object_member
        assert obj.object_member is None
        raises(AttributeError, "obj.object_member_ex")
        obj.object_member_ex = None
        assert obj.object_member_ex is None
        obj.object_member_ex = 42
        assert obj.object_member_ex == 42
        del obj.object_member_ex
        raises(AttributeError, "del obj.object_member_ex")

        obj.set_foo = 32
        assert obj.foo == 32

    def test_typeobject_string_member(self):
        module = self.import_module(name='foo')
        obj = module.new()
        assert obj.string_member == "Hello from PyPy"
        raises(TypeError, "obj.string_member = 42")
        raises(TypeError, "del obj.string_member")
        obj.unset_string_member()
        assert obj.string_member is None
        assert obj.string_member_inplace == "spam"
        raises(TypeError, "obj.string_member_inplace = 42")
        raises(TypeError, "del obj.string_member_inplace")
        assert obj.char_member == "s"
        obj.char_member = "a"
        assert obj.char_member == "a"
        raises(TypeError, "obj.char_member = 'spam'")
        raises(TypeError, "obj.char_member = 42")
        #
        import sys
        bignum = sys.maxsize - 42
        obj.short_member = -12345;     assert obj.short_member == -12345
        obj.long_member = -bignum;     assert obj.long_member == -bignum
        obj.ushort_member = 45678;     assert obj.ushort_member == 45678
        obj.uint_member = 3000000000;  assert obj.uint_member == 3000000000
        obj.ulong_member = 2*bignum;   assert obj.ulong_member == 2*bignum
        obj.byte_member = -99;         assert obj.byte_member == -99
        obj.ubyte_member = 199;        assert obj.ubyte_member == 199
        obj.bool_member = True;        assert obj.bool_member is True
        obj.float_member = 9.25;       assert obj.float_member == 9.25
        obj.double_member = 9.25;      assert obj.double_member == 9.25
        obj.longlong_member = -2**59;  assert obj.longlong_member == -2**59
        obj.ulonglong_member = 2**63;  assert obj.ulonglong_member == 2**63
        obj.ssizet_member = sys.maxsize;assert obj.ssizet_member == sys.maxsize
        #

    def test_staticmethod(self):
        module = self.import_module(name="foo")
        obj = module.fooType.create()
        assert obj.foo == 42
        obj2 = obj.create()
        assert obj2.foo == 42

    def test_classmethod(self):
        module = self.import_module(name="foo")
        classmeth = module.fooType.classmeth
        obj = classmeth()
        assert obj is module.fooType
        class _C:
            def _m(self): pass
        MethodType = type(_C()._m)
        print(type(classmeth).mro())
        print(MethodType.mro())
        assert not isinstance(classmeth, MethodType)

    def test_class_getitem(self):
        module = self.import_module(name='foo')
        f = module.fooType.__class_getitem__
        out = f(42)
        assert str(out) == 'foo.foo[42]'

    def test_methoddescr(self):
        module = self.import_module(name='foo')
        descr = module.fooType.copy
        assert type(descr).__name__ == 'method_descriptor'
        assert str(descr) in ("<method 'copy' of 'foo.foo' objects>",
            "<method 'copy' of 'foo' objects>")
        assert repr(descr) in ("<method 'copy' of 'foo.foo' objects>",
            "<method 'copy' of 'foo' objects>")
        raises(TypeError, descr, None)

    def test_cython_fake_classmethod(self):
        module = self.import_module(name='foo')

        # Check that objects are printable
        print(module.fooType.fake_classmeth)  # bound method on the class
        print(module.fooType.__dict__['fake_classmeth']) # raw descriptor

        assert module.fooType.fake_classmeth() is module.fooType

    def test_new(self):
        # XXX cpython segfaults but if run singly (with -k test_new) this passes
        module = self.import_module(name='foo')
        obj = module.new()
        # call __new__
        newobj = module.UnicodeSubtype(u"xyz")
        assert newobj == u"xyz"
        assert isinstance(newobj, module.UnicodeSubtype)

        assert isinstance(module.fooType(), module.fooType)
        class bar(module.fooType):
            pass
        assert isinstance(bar(), bar)

        fuu = module.UnicodeSubtype
        class fuu2(fuu):
            def baz(self):
                return self
        assert fuu2(u"abc").baz().escape()
        raises(TypeError, module.fooType.object_member.__get__, 1)

    def test_shortcut(self):
        # test that instances of classes that are defined in C become an
        # instance of W_BaseCPyObject and thus can be converted faster back to
        # their pyobj, because they store a pointer to it directly.
        if self.runappdirect:
            skip("can't run with -A")
        module = self.import_module(name='foo')
        obj = module.fooType()
        assert self._check_uses_shortcut(obj)
        # W_TypeObjects use shortcut
        assert self._check_uses_shortcut(object)
        assert self._check_uses_shortcut(type)
        # None, True, False use shortcut
        assert self._check_uses_shortcut(None)
        assert self._check_uses_shortcut(True)
        assert self._check_uses_shortcut(False)
        assert not self._check_uses_shortcut(1)
        assert not self._check_uses_shortcut(object())

    def test_multiple_inheritance1(self):
        module = self.import_module(name='foo')
        obj = module.UnicodeSubtype(u'xyz')
        obj2 = module.UnicodeSubtype2()
        obj3 = module.UnicodeSubtype3()
        assert obj3.get_val() == 42
        assert len(type(obj3).mro()) == 5

    def test_init(self):
        module = self.import_module(name="foo")
        newobj = module.UnicodeSubtype()
        assert newobj.get_val() == 42

        # this subtype should inherit tp_init
        newobj = module.UnicodeSubtype2()
        assert newobj.get_val() == 42

        # this subclass redefines __init__
        class UnicodeSubclass2(module.UnicodeSubtype):
            def __init__(self):
                self.foobar = 32
                super(UnicodeSubclass2, self).__init__()

        newobj = UnicodeSubclass2()
        assert newobj.get_val() == 42
        assert newobj.foobar == 32

    def test_metatype(self):
        module = self.import_module(name='foo')
        assert module.MetaType.__mro__ == (module.MetaType, type, object)
        x = module.MetaType('name', (), {})
        assert isinstance(x, type)
        assert isinstance(x, module.MetaType)
        x()

    def test_metaclass_compatible(self):
        # metaclasses should not conflict here
        module = self.import_module(name='foo')
        assert module.MetaType.__mro__ == (module.MetaType, type, object)
        assert type(module.fooType).__mro__ == (type, object)
        y = module.MetaType('other', (module.MetaType,), {})
        assert isinstance(y, module.MetaType)
        x = y('something', (type(y),), {})
        del x, y

    def test_metaclass_compatible2(self):
        skip('fails even with -A, fooType has BASETYPE flag')
        # XXX FIX - must raise since fooType (which is a base type)
        # does not have flag Py_TPFLAGS_BASETYPE
        module = self.import_module(name='foo')
        raises(TypeError, module.MetaType, 'other', (module.fooType,), {})

    def test_init_error(self):
        module = self.import_module("foo")
        raises(ValueError, module.InitErrType)

    def test_cmps(self):
        module = self.import_module("comparisons")
        cmpr = module.CmpType()
        assert cmpr == 3
        assert cmpr != 42

    def test_richcompare(self):
        module = self.import_module("comparisons")
        cmpr = module.CmpType()

        # should not crash
        raises(TypeError, "cmpr < 4")
        raises(TypeError, "cmpr <= 4")
        raises(TypeError, "cmpr > 4")
        raises(TypeError, "cmpr >= 4")

        assert cmpr.__le__(4) is NotImplemented

    def test_hash(self):
        module = self.import_module("comparisons")
        cmpr = module.CmpType()
        assert hash(cmpr) == 3
        d = {}
        d[cmpr] = 72
        assert d[cmpr] == 72
        assert d[3] == 72

    def test_hash_inheritance(self):
        foo = self.import_module("foo")
        assert hash(foo.UnicodeSubtype(u'xyz')) == hash(u'xyz')
        assert foo.UnicodeSubtype.__hash__ is str.__hash__
        assert hash(foo.UnicodeSubtype3(u'xyz')) == hash(u'xyz')
        assert foo.UnicodeSubtype3.__hash__ is str.__hash__

    def test_descriptor(self):
        module = self.import_module("foo")
        prop = module.Property()
        class C(object):
            x = prop
        obj = C()
        assert obj.x == (prop, obj, C)
        assert C.x == (prop, None, C)

        obj.x = 2
        assert obj.y == (prop, 2)
        del obj.x
        assert obj.z == prop

    def test_tp_dict(self):
        foo = self.import_module("foo")
        module = self.import_extension('test', [
            ("read_tp_dict", "METH_O",
            '''
                 PyObject *method;
                 if (!args->ob_type->tp_dict)
                 {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 method = PyDict_GetItemString(
                     args->ob_type->tp_dict, "copy");
                 Py_INCREF(method);
                 return method;
             '''),
            ("get_type_dict", "METH_O",
             '''
                PyObject* value = args->ob_type->tp_dict;
                if (value == NULL) value = Py_None;
                Py_INCREF(value);
                return value;
             '''),
            ])
        obj = foo.new()
        assert module.read_tp_dict(obj) == foo.fooType.copy
        d = module.get_type_dict(obj)
        assert type(d) is dict
        d["_some_attribute"] = 1
        assert type(obj)._some_attribute == 1
        del d["_some_attribute"]

        class A(object):
            pass
        obj = A()
        d = module.get_type_dict(obj)
        assert type(d) is dict
        d["_some_attribute"] = 1
        assert type(obj)._some_attribute == 1
        del d["_some_attribute"]

        d = module.get_type_dict(1)
        assert type(d) is dict
        try:
            d["_some_attribute"] = 1
        except TypeError:  # on PyPy, int.__dict__ is really immutable
            pass
        else:
            assert int._some_attribute == 1
            del d["_some_attribute"]

    def test_custom_allocation(self):
        foo = self.import_module("foo")
        obj = foo.newCustom()
        assert type(obj) is foo.Custom
        assert type(foo.Custom) is foo.MetaType

    def test_heaptype(self):
        module = self.import_extension('foo', [
           ("name_by_heaptype", "METH_O",
            '''
                 PyHeapTypeObject *heaptype = (PyHeapTypeObject *)args;
                 Py_INCREF(heaptype->ht_name);
                 return heaptype->ht_name;
             '''),
            ("setattr", "METH_O",
             '''
                int ret;
                PyObject* name = PyBytes_FromString("mymodule");
                PyObject *obj = PyType_Type.tp_alloc(&PyType_Type, 0);
                PyHeapTypeObject *type = (PyHeapTypeObject*)obj;
                /* this is issue #2434: logic from pybind11 */
                type->ht_type.tp_flags |= Py_TPFLAGS_HEAPTYPE;
                type->ht_type.tp_name = ((PyTypeObject*)args)->tp_name;
                type->ht_name = PyUnicode_FromString(type->ht_type.tp_name);
                PyType_Ready(&type->ht_type);
                ret = PyObject_SetAttrString((PyObject*)&type->ht_type,
                                    "__module__", name);
                Py_DECREF(name);
                if (ret < 0)
                    return NULL;
                return PyLong_FromLong(ret);
             '''),
            ])
        class C(object):
            pass
        assert module.name_by_heaptype(C) == "C"
        assert module.setattr(C) == 0


    def test_type_dict(self):
        foo = self.import_module("foo")
        module = self.import_extension('test', [
           ("hack_tp_dict", "METH_VARARGS",
            '''
                 PyTypeObject *type;
                 PyObject *a1 = PyLong_FromLong(1);
                 PyObject *a2 = PyLong_FromLong(2);
                 PyObject *obj, *value, *key;
                 if (!PyArg_ParseTuple(args, "OO", &obj, &key))
                     return NULL;
                 type = obj->ob_type;

                 if (PyDict_SetItem(type->tp_dict, key,
                         a1) < 0)
                     return NULL;
                 Py_DECREF(a1);
                 PyType_Modified(type);
                 value = PyObject_GetAttr((PyObject *)type, key);
                 Py_DECREF(value);

                 if (PyDict_SetItem(type->tp_dict, key,
                         a2) < 0)
                     return NULL;
                 Py_DECREF(a2);
                 PyType_Modified(type);
                 value = PyObject_GetAttr((PyObject *)type, key);
                 return value;
             '''
             )
            ])
        obj = foo.new()
        assert module.hack_tp_dict(obj, "a") == 2
        class Sub(foo.fooType):
            pass
        obj = Sub()
        assert module.hack_tp_dict(obj, "b") == 2


    def test_tp_dict_ready(self):
        module = self.import_extension('foo', [
           ("new_obj", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''
            )], prologue='''
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            ''', more_init = '''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_dict = PyDict_New();
                PyDict_SetItemString(Foo_Type.tp_dict, "inserted", Py_True);
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')

        obj = module.new_obj()
        assert type(obj).inserted is True


    def test_tp_descr_get(self):
        module = self.import_extension('foo', [
           ("tp_descr_get", "METH_O",
            '''
                if (args->ob_type->tp_descr_get == NULL) {
                    Py_INCREF(Py_False);
                    return Py_False;
                }
                return args->ob_type->tp_descr_get(args, NULL,
                                                   (PyObject *)&PyLong_Type);
             '''
             )
            ])
        assert module.tp_descr_get(42) is False

        class Y(object):
            def __get__(self, *args):
                return 42
            def unbound_method_example(self):
                pass
        assert module.tp_descr_get(Y()) == 42
        #
        p = property(lambda self: 42)
        result = module.tp_descr_get(p)
        assert result is p
        #
        f = lambda x: x + 1
        ubm = module.tp_descr_get(f)
        assert type(ubm) is type(Y.unbound_method_example)
        assert ubm(42) == 43

    def test_tp_descr_set(self):
        module = self.import_extension('foo', [
           ("tp_descr_set", "METH_O",
            '''
                if (args->ob_type->tp_descr_set == NULL) {
                    Py_INCREF(Py_False);
                    return Py_False;
                }
                if (args->ob_type->tp_descr_set(args, Py_False, Py_True) != 0)
                    return NULL;
                if (args->ob_type->tp_descr_set(args, Py_Ellipsis, NULL) != 0)
                    return NULL;

                Py_INCREF(Py_True);
                return Py_True;
             '''
             )
            ])
        assert module.tp_descr_set(42) is False

        class Y(object):
            def __set__(self, obj, value):
                assert obj is False
                assert value is True
            def __delete__(self, obj):
                assert obj is Ellipsis
        assert module.tp_descr_set(Y()) is True
        #
        def pset(obj, value):
            assert obj is False
            assert value is True
        def pdel(obj):
            assert obj is Ellipsis
        p = property(lambda: "never used", pset, pdel)
        assert module.tp_descr_set(p) is True

    def test_text_signature(self):
        import sys
        module = self.import_module(name='docstrings')
        assert module.SomeType.__text_signature__ == '()'
        assert module.SomeType.__doc__ == 'A type with a signature'
        if '__pypy__' in sys.modules:
            assert module.HeapType.__text_signature__ == '()'
        else:  # XXX: bug in CPython?
            assert module.HeapType.__text_signature__ is None
        assert module.HeapType.__doc__ == 'A type with a signature'

    def test_heaptype_attributes(self):
        module = self.import_module(name='docstrings')
        htype = module.HeapType
        assert htype.__module__ == 'docstrings'
        assert htype.__name__ == 'HeapType'
        assert htype.__qualname__ == 'HeapType'


class TestTypes(BaseApiTest):
    def test_type_attributes(self, space, api):
        w_class = space.appexec([], """():
            class A(object):
                pass
            return A
            """)
        ref = make_ref(space, w_class)

        py_type = rffi.cast(PyTypeObjectPtr, ref)
        assert py_type.c_tp_alloc
        w_tup = from_ref(space, py_type.c_tp_mro)
        assert space.fixedview(w_tup) == w_class.mro_w

        decref(space, ref)

    def test_type_dict(self, space, api):
        w_class = space.appexec([], """():
            class A(object):
                pass
            return A
            """)
        ref = make_ref(space, w_class)

        py_type = rffi.cast(PyTypeObjectPtr, ref)
        w_dict = from_ref(space, py_type.c_tp_dict)
        w_name = space.newtext('a')
        space.setitem(w_dict, w_name, space.wrap(1))
        assert space.int_w(space.getattr(w_class, w_name)) == 1
        space.delitem(w_dict, w_name)

    def test_multiple_inheritance2(self, space, api):
        w_class = space.appexec([], """():
            class A(object):
                pass
            class B(object):
                pass
            class C(A, B):
                pass
            return C
            """)
        ref = make_ref(space, w_class)
        decref(space, ref)

    def test_lookup(self, space, api):
        w_type = space.w_bytes
        w_obj = api._PyType_Lookup(w_type, space.wrap("upper"))
        assert space.is_w(w_obj, space.w_bytes.getdictvalue(space, "upper"))

        w_obj = api._PyType_Lookup(w_type, space.wrap("__invalid"))
        assert w_obj is None
        assert api.PyErr_Occurred() is None

    def test_typeslots(self, space):
        assert cts.macros['Py_tp_doc'] == 56

    def test_subclass_not_PyCTypeObject(self, space, api):
        pyobj = make_ref(space, api.PyLong_Type)
        py_type = rffi.cast(PyTypeObjectPtr, pyobj)
        w_pyclass = W_PyCTypeObject(space, py_type)
        w_class = space.appexec([w_pyclass], """(base):
            class Sub(base):
                def addattrib(self, value):
                    self.attrib = value
            return Sub
            """)
        assert w_pyclass in w_class.mro_w
        assert isinstance(w_pyclass, W_PyCTypeObject)
        assert not isinstance(w_class, W_PyCTypeObject)
        assert w_pyclass.is_cpytype()
        # XXX document the current status, not clear if this is desirable
        assert w_class.is_cpytype()


class AppTestSlots(AppTestCpythonExtensionBase):
    def setup_class(cls):
        AppTestCpythonExtensionBase.setup_class.im_func(cls)
        def _check_type_object(w_X):
            assert w_X.is_cpytype()
            assert not w_X.is_heaptype()
        cls.w__check_type_object = cls.space.wrap(
            gateway.interp2app(_check_type_object))

    def test_some_slots(self):
        module = self.import_extension('foo', [
            ("test_type", "METH_O",
             '''
                 /* "args->ob_type" is a strange way to get at 'type',
                    which should have a different tp_getattro/tp_setattro
                    than its tp_base, which is 'object'.
                  */

                 if (!args->ob_type->tp_setattro)
                 {
                     PyErr_SetString(PyExc_ValueError, "missing tp_setattro");
                     return NULL;
                 }
                 if (args->ob_type->tp_setattro ==
                     args->ob_type->tp_base->tp_setattro)
                 {
                     /* Note that unlike CPython, in PyPy 'type.tp_setattro'
                        is the same function as 'object.tp_setattro'.  This
                        test used to check that it was not, but that was an
                        artifact of the bootstrap logic only---in the final
                        C sources I checked and they are indeed the same.
                        So we ignore this problem here. */
                 }
                 if (!args->ob_type->tp_getattro)
                 {
                     PyErr_SetString(PyExc_ValueError, "missing tp_getattro");
                     return NULL;
                 }
                 if (args->ob_type->tp_getattro ==
                     args->ob_type->tp_base->tp_getattro)
                 {
                     PyErr_SetString(PyExc_ValueError, "recursive tp_getattro");
                     return NULL;
                 }
                 Py_RETURN_TRUE;
             '''
             )
            ])
        assert module.test_type(type(None))

    def test_tp_getattro(self):
        module = self.import_extension('foo', [
            ("test_tp_getattro", "METH_VARARGS",
             '''
                 #if PY_MAJOR_VERSION > 2
                 #define PyString_FromString PyUnicode_FromString
                 #define PyIntObject PyLongObject
                 #define PyInt_AsLong PyLong_AsLong
                 #endif
                 PyObject *name, *obj = PyTuple_GET_ITEM(args, 0);
                 PyObject *attr, *value = PyTuple_GET_ITEM(args, 1);
                 if (!obj->ob_type->tp_getattro)
                 {
                     PyErr_SetString(PyExc_ValueError, "missing tp_getattro");
                     return NULL;
                 }
                 name = PyString_FromString("attr1");
                 attr = obj->ob_type->tp_getattro(obj, name);
                 if (PyInt_AsLong(attr) != PyInt_AsLong(value))
                 {
                     PyErr_SetString(PyExc_ValueError,
                                     "tp_getattro returned wrong value");
                     return NULL;
                 }
                 Py_DECREF(name);
                 Py_DECREF(attr);
                 name = PyString_FromString("attr2");
                 attr = obj->ob_type->tp_getattro(obj, name);
                 if (attr == NULL && PyErr_ExceptionMatches(PyExc_AttributeError))
                 {
                     PyErr_Clear();
                 } else {
                     PyErr_SetString(PyExc_ValueError,
                                     "tp_getattro should have raised");
                     return NULL;
                 }
                 Py_DECREF(name);
                 Py_RETURN_TRUE;
             '''
             )
            ])
        class C:
            def __init__(self):
                self.attr1 = 123
        assert module.test_tp_getattro(C(), 123)

    def test_issue_2760_getattr(self):
        module = self.import_extension('foo', [
            ("get_foo", "METH_O",
             '''
             #if PY_MAJOR_VERSION > 2
             #define PyString_FromString PyUnicode_FromString
             #endif
             char* name = "foo";
             PyTypeObject *tp = Py_TYPE(args);
             PyObject *res;
             if (tp->tp_getattr != NULL) {
                res = (*tp->tp_getattr)(args, name);
             }
             else if (tp->tp_getattro != NULL) {
                 PyObject *w = PyString_FromString(name);
                 res = (*tp->tp_getattro)(args, w);
                 Py_DECREF(w);
             }
             else {
                 res = Py_None;
             }
             return res;
             ''')])
        class Passthrough(object):
            def __getattr__(self, name):
                return name

        obj = Passthrough()
        assert module.get_foo(obj) == 'foo'

    def test_nb_int(self):
        module = self.import_extension('foo', [
            ("nb_int", "METH_VARARGS",
             '''
                 PyTypeObject *type = (PyTypeObject *)PyTuple_GET_ITEM(args, 0);
                 PyObject *obj = PyTuple_GET_ITEM(args, 1);
                 if (!type->tp_as_number ||
                     !type->tp_as_number->nb_int)
                 {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 return type->tp_as_number->nb_int(obj);
             '''
             )
            ])
        assert module.nb_int(int, 10) == 10
        assert module.nb_int(float, -12.3) == -12
        raises(ValueError, module.nb_int, str, "123")
        class F(float):
            def __int__(self):
                return 666
        expected = float.__int__(F(-12.3))
        assert module.nb_int(float, F(-12.3)) == expected
        assert module.nb_int(F, F(-12.3)) == 666
        class A:
            pass
        raises(TypeError, module.nb_int, A, A())

    def test_nb_float(self):
        module = self.import_extension('foo', [
            ("nb_float", "METH_VARARGS",
             '''
                 PyTypeObject *type = (PyTypeObject *)PyTuple_GET_ITEM(args, 0);
                 PyObject *obj = PyTuple_GET_ITEM(args, 1);
                 if (!type->tp_as_number ||
                     !type->tp_as_number->nb_float)
                 {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 return type->tp_as_number->nb_float(obj);
             '''
             )
            ])
        assert module.nb_float(int, 10) == 10.0
        assert module.nb_float(float, -12.3) == -12.3
        raises(ValueError, module.nb_float, str, "123")
        #
        # check that calling PyInt_Type->tp_as_number->nb_float(x)
        # does not invoke a user-defined __float__()
        class I(int):
            def __float__(self):
                return -55.55
        class F(float):
            def __float__(self):
                return -66.66
        assert float(I(10)) == -55.55
        assert float(F(10.5)) == -66.66
        assert module.nb_float(int, I(10)) == 10.0
        assert module.nb_float(float, F(10.5)) == 10.5
        # XXX but the subtype's tp_as_number->nb_float(x) should really invoke
        # the user-defined __float__(); it doesn't so far
        #assert module.nb_float(I, I(10)) == -55.55
        #assert module.nb_float(F, F(10.5)) == -66.66

    def test_tp_call(self):
        module = self.import_extension('foo', [
            ("tp_call", "METH_VARARGS",
             '''
                 PyTypeObject *type = (PyTypeObject *)PyTuple_GET_ITEM(args, 0);
                 PyObject *obj = PyTuple_GET_ITEM(args, 1);
                 PyObject *c_args = PyTuple_GET_ITEM(args, 2);
                 if (!type->tp_call)
                 {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 return type->tp_call(obj, c_args, NULL);
             '''
             )
            ])
        class C:
            def __call__(self, *args):
                return args
        ret = module.tp_call(C, C(), ('x', 2))
        assert ret == ('x', 2)
        class D(type):
            def __call__(self, *args):
                return "foo! %r" % (args,)
        typ1 = D('d', (), {})
        #assert module.tp_call(D, typ1, ()) == "foo! ()" XXX not working so far
        assert isinstance(module.tp_call(type, typ1, ()), typ1)

    def test_tp_init(self):
        module = self.import_extension('foo', [
            ("tp_init", "METH_VARARGS",
             '''
                 PyTypeObject *type = (PyTypeObject *)PyTuple_GET_ITEM(args, 0);
                 PyObject *obj = PyTuple_GET_ITEM(args, 1);
                 PyObject *c_args = PyTuple_GET_ITEM(args, 2);
                 if (!type->tp_init)
                 {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 if (type->tp_init(obj, c_args, NULL) < 0)
                     return NULL;
                 Py_INCREF(Py_None);
                 return Py_None;
             '''
             )
            ])
        x = [42]
        assert module.tp_init(list, x, ("hi",)) is None
        assert x == ["h", "i"]
        class LL(list):
            def __init__(self, *ignored):
                raise Exception
        x = LL.__new__(LL)
        assert module.tp_init(list, x, ("hi",)) is None
        assert x == ["h", "i"]

    def test_mp_subscript(self):
        module = self.import_extension('foo', [
           ("new_obj", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''
            )], prologue='''
            static PyObject*
            mp_subscript(PyObject *self, PyObject *key)
            {
                return Py_BuildValue("i", 42);
            }
            PyMappingMethods tp_as_mapping;
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            ''', more_init = '''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_as_mapping = &tp_as_mapping;
                tp_as_mapping.mp_subscript = (binaryfunc)mp_subscript;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        obj = module.new_obj()
        assert obj[100] == 42
        raises(TypeError, "obj.__getitem__(100, 101)")
        raises(TypeError, "obj.__getitem__(100, a=42)")

    def test_mp_ass_subscript(self):
        module = self.import_extension('foo', [
           ("new_obj", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''
            )], prologue='''
            static int
            #if PY_MAJOR_VERSION > 2
            #define PyString_FromString PyBytes_FromString
            #define PyInt_Check PyLong_Check
            #endif
            mp_ass_subscript(PyObject *self, PyObject *key, PyObject *value)
            {
                if (PyInt_Check(key)) {
                    PyErr_SetNone(PyExc_ZeroDivisionError);
                    return -1;
                }
                return 0;
            }
            PyMappingMethods tp_as_mapping;
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            ''', more_init = '''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_as_mapping = &tp_as_mapping;
                tp_as_mapping.mp_ass_subscript = mp_ass_subscript;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        obj = module.new_obj()
        raises(ZeroDivisionError, obj.__setitem__, 5, None)
        res = obj.__setitem__('foo', None)
        assert res is None

    def test_sq_contains(self):
        module = self.import_extension('foo', [
           ("new_obj", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''
            )], prologue='''
            static int
            sq_contains(PyObject *self, PyObject *value)
            {
                return 42;
            }
            PySequenceMethods tp_as_sequence;
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            ''', more_init='''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_as_sequence = &tp_as_sequence;
                tp_as_sequence.sq_contains = sq_contains;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        obj = module.new_obj()
        res = "foo" in obj
        assert res is True

            #if PY_MAJOR_VERSION > 2
            #define PyInt_Check PyLong_Check
            #define PyInt_AsLong PyLong_AsLong
            #endif
    def test_sq_ass_item(self):
        module = self.import_extension('foo', [
           ("new_obj", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''
            )], prologue='''
            #if PY_MAJOR_VERSION > 2
            #define PyInt_Check PyLong_Check
            #define PyInt_AsLong PyLong_AsLong
            #endif
            static int
            sq_ass_item(PyObject *self, Py_ssize_t i, PyObject *o)
            {
                int expected;
                if (o == NULL)              // delitem
                    expected = (i == 12);
                else                        // setitem
                    expected = (i == 10 && PyInt_Check(o) && PyInt_AsLong(o) == 42);
                if (!expected) {
                    PyErr_SetString(PyExc_ValueError, "test failed");
                    return -1;
                }
                return 0;
            }
            PySequenceMethods tp_as_sequence;
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            ''', more_init='''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_as_sequence = &tp_as_sequence;
                tp_as_sequence.sq_ass_item = sq_ass_item;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        obj = module.new_obj()
        obj[10] = 42
        raises(ValueError, "obj[10] = 43")
        raises(ValueError, "obj[11] = 42")
        del obj[12]
        raises(ValueError, "del obj[13]")

    def test_tp_iter(self):
        module = self.import_extension('foo', [
           ("tp_iter", "METH_VARARGS",
            '''
                 PyTypeObject *type = (PyTypeObject *)PyTuple_GET_ITEM(args, 0);
                 PyObject *obj = PyTuple_GET_ITEM(args, 1);
                 if (!type->tp_iter)
                 {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 return type->tp_iter(obj);
             '''
             ),
           ("tp_iternext", "METH_VARARGS",
            '''
                 #if PY_MAJOR_VERSION > 2
                 #define PyString_FromString PyBytes_FromString
                 #endif
                 PyTypeObject *type = (PyTypeObject *)PyTuple_GET_ITEM(args, 0);
                 PyObject *obj = PyTuple_GET_ITEM(args, 1);
                 PyObject *result;
                 if (!type->tp_iternext)
                 {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 result = type->tp_iternext(obj);
                 /* In py3, returning NULL from tp_iternext means the iterator
                  * is exhausted */
                 if (!result && !PyErr_Occurred())
                     result = PyString_FromString("stop!");
                 return result;
             '''
             )
            ])
        l = [1]
        it = module.tp_iter(list, l)
        assert type(it) is type(iter([]))
        assert module.tp_iternext(type(it), it) == 1
        assert module.tp_iternext(type(it), it) == b"stop!"
        #
        class LL(list):
            def __iter__(self):
                return iter(())
        ll = LL([1])
        it = module.tp_iter(list, ll)
        assert type(it) is type(iter([]))
        x = list(it)
        assert x == [1]

    def test_intlike(self):
        module = self.import_extension('foo', [
            ("newInt", "METH_VARARGS",
             """
                IntLikeObject *intObj;
                long intval;

                if (!PyArg_ParseTuple(args, "i", &intval))
                    return NULL;

                intObj = PyObject_New(IntLikeObject, &IntLike_Type);
                if (!intObj) {
                    return NULL;
                }

                intObj->value = intval;
                return (PyObject *)intObj;
             """),
            ("check", "METH_VARARGS", """
                IntLikeObject *intObj;
                int intval, isint;

                if (!PyArg_ParseTuple(args, "i", &intval))
                    return NULL;
                intObj = PyObject_New(IntLikeObject, &IntLike_Type);
                if (!intObj) {
                    return NULL;
                }
                intObj->value = intval;
                isint = PyNumber_Check((PyObject*)intObj);
                Py_DECREF((PyObject*)intObj);
                return PyLong_FromLong(isint);
            """),
            ], prologue= """
            typedef struct
            {
                PyObject_HEAD
                int value;
            } IntLikeObject;

            static int
            intlike_nb_bool(PyObject *o)
            {
                IntLikeObject *v = (IntLikeObject*)o;
                if (v->value == -42) {
                    PyErr_SetNone(PyExc_ValueError);
                    return -1;
                }
                /* Returning -1 should be for exceptions only! */
                return v->value;
            }

            static PyObject*
            intlike_nb_int(PyObject* o)
            {
                IntLikeObject *v = (IntLikeObject*)o;
                return PyLong_FromLong(v->value);
            }

            PyTypeObject IntLike_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                /*tp_name*/             "IntLike",
                /*tp_basicsize*/        sizeof(IntLikeObject),
            };
            static PyNumberMethods intlike_as_number;
            """, more_init="""
            IntLike_Type.tp_flags |= Py_TPFLAGS_DEFAULT;
            IntLike_Type.tp_as_number = &intlike_as_number;
            intlike_as_number.nb_bool = intlike_nb_bool;
            intlike_as_number.nb_int = intlike_nb_int;
            PyType_Ready(&IntLike_Type);
            """)
        assert not bool(module.newInt(0))
        assert bool(module.newInt(1))
        raises(SystemError, bool, module.newInt(-1))
        raises(ValueError, bool, module.newInt(-42))
        val = module.check(10);
        assert val == 1

    def test_mathfunc(self):
        module = self.import_extension('foo', [
            ("newInt", "METH_VARARGS",
             """
                IntLikeObject *intObj;
                long intval;

                if (!PyArg_ParseTuple(args, "l", &intval))
                    return NULL;

                intObj = PyObject_New(IntLikeObject, &IntLike_Type);
                if (!intObj) {
                    return NULL;
                }

                intObj->ival = intval;
                return (PyObject *)intObj;
             """),
             ("newIntNoOp", "METH_VARARGS",
             """
                IntLikeObjectNoOp *intObjNoOp;
                long intval;

                if (!PyArg_ParseTuple(args, "l", &intval))
                    return NULL;

                intObjNoOp = PyObject_New(IntLikeObjectNoOp, &IntLike_Type_NoOp);
                if (!intObjNoOp) {
                    return NULL;
                }

                intObjNoOp->ival = intval;
                return (PyObject *)intObjNoOp;
             """)], prologue="""
            #include <math.h>
            typedef struct
            {
                PyObject_HEAD
                long ival;
            } IntLikeObject;
            #if PY_MAJOR_VERSION > 2
            #define PyInt_Check PyLong_Check
            #define PyInt_AsLong PyLong_AsLong
            #define PyInt_FromLong PyLong_FromLong
            #endif
            static PyObject *
            intlike_nb_add(PyObject *self, PyObject *other)
            {
                long val2, val1 = ((IntLikeObject *)(self))->ival;
                if (PyInt_Check(other)) {
                  long val2 = PyInt_AsLong(other);
                  return PyInt_FromLong(val1+val2);
                }

                val2 = ((IntLikeObject *)(other))->ival;
                return PyInt_FromLong(val1+val2);
            }

            static PyObject *
            intlike_nb_pow(PyObject *self, PyObject *other, PyObject * z)
            {
                long val2, val1 = ((IntLikeObject *)(self))->ival;
                if (PyInt_Check(other)) {
                  long val2 = PyInt_AsLong(other);
                  return PyInt_FromLong(val1+val2);
                }

                val2 = ((IntLikeObject *)(other))->ival;
                return PyInt_FromLong((int)pow(val1,val2));
             }

            PyTypeObject IntLike_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                /*tp_name*/             "IntLike",
                /*tp_basicsize*/        sizeof(IntLikeObject),
            };
            static PyNumberMethods intlike_as_number;

            typedef struct
            {
                PyObject_HEAD
                long ival;
            } IntLikeObjectNoOp;

            PyTypeObject IntLike_Type_NoOp = {
                PyVarObject_HEAD_INIT(NULL, 0)
                /*tp_name*/             "IntLikeNoOp",
                /*tp_basicsize*/        sizeof(IntLikeObjectNoOp),
            };
            """, more_init="""
                IntLike_Type.tp_as_number = &intlike_as_number;
                IntLike_Type.tp_flags |= Py_TPFLAGS_DEFAULT;
                intlike_as_number.nb_add = intlike_nb_add;
                intlike_as_number.nb_power = intlike_nb_pow;
                if (PyType_Ready(&IntLike_Type) < 0) INITERROR;
                IntLike_Type_NoOp.tp_flags |= Py_TPFLAGS_DEFAULT;
                if (PyType_Ready(&IntLike_Type_NoOp) < 0) INITERROR;
            """)
        a = module.newInt(1)
        b = module.newInt(2)
        c = 3
        d = module.newIntNoOp(4)
        assert (a + b) == 3
        assert (b + c) == 5
        assert (d + a) == 5
        assert pow(d,b) == 16

    def test_tp_new_in_subclass(self):
        import datetime
        module = self.import_module(name='foo3')
        module.footype("X", (object,), {})
        a = module.datetimetype(1, 1, 1)
        assert isinstance(a, module.datetimetype)

    def test_app_subclass_of_c_type(self):
        import sys
        module = self.import_module(name='foo')
        size = module.size_of_instances(module.fooType)
        class f1(object):
            pass
        class f2(module.fooType):
            pass
        class bar(f1, f2):
            pass
        class foo(f2, f1):
            pass

        x = foo()
        assert bar.__base__ is f2
        # On cpython, the size changes.
        if '__pypy__' in sys.builtin_module_names:
            assert module.size_of_instances(bar) == size
        else:
            assert module.size_of_instances(bar) >= size
        assert module.size_of_instances(foo) == module.size_of_instances(bar)

    def test_app_cant_subclass_two_types(self):
        import sys
        if sys.version_info < (2, 7, 9):
            skip("crashes on CPython (2.7.5 crashes, 2.7.9 is ok)")
        module = self.import_module(name='foo')
        try:
            class bar(module.fooType, module.UnicodeSubtype):
                pass
        except TypeError as e:
            import sys
            if '__pypy__' in sys.builtin_module_names:
                print(str(e))
                assert 'instance layout conflicts in multiple inheritance' in str(e)

            else:
                assert 'instance lay-out conflict' in str(e)
        else:
            raise AssertionError("did not get TypeError!")

    def test_call_tp_dealloc(self):
        module = self.import_extension('foo', [
            ("fetchFooType", "METH_NOARGS",
             """
                PyObject *o;
                o = PyObject_New(PyObject, &Foo_Type);
                init_foo(o);
                Py_DECREF(o);   /* calls dealloc_foo immediately */

                Py_INCREF(&Foo_Type);
                return (PyObject *)&Foo_Type;
             """),
            ("newInstance", "METH_O",
             """
                PyTypeObject *tp = (PyTypeObject *)args;
                PyObject *e = PyTuple_New(0);
                PyObject *o = tp->tp_new(tp, e, NULL);
                Py_DECREF(e);
                return o;
             """),
            ("getCounter", "METH_NOARGS",
             """
                return PyLong_FromLong(foo_counter);
             """)], prologue="""
            typedef struct {
                PyObject_HEAD
                int someval[99];
            } FooObject;
            static int foo_counter = 1000;
            static void dealloc_foo(PyObject *foo) {
                int i;
                foo_counter += 10;
                for (i = 0; i < 99; i++)
                    if (((FooObject *)foo)->someval[i] != 1000 + i)
                        foo_counter += 100000;   /* error! */
                Py_TYPE(foo)->tp_free(foo);
            }
            static void init_foo(PyObject *o)
            {
                int i;
                if (o->ob_type->tp_basicsize < sizeof(FooObject))
                    abort();
                for (i = 0; i < 99; i++)
                    ((FooObject *)o)->someval[i] = 1000 + i;
            }
            static PyObject *new_foo(PyTypeObject *t, PyObject *a, PyObject *k)
            {
                PyObject *o;
                foo_counter += 1000;
                o = t->tp_alloc(t, 0);
                init_foo(o);
                return o;
            }
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            """, more_init="""
                Foo_Type.tp_basicsize = sizeof(FooObject);
                Foo_Type.tp_dealloc = &dealloc_foo;
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE;
                Foo_Type.tp_new = &new_foo;
                Foo_Type.tp_free = &PyObject_Del;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            """)
        Foo = module.fetchFooType()
        assert module.getCounter() == 1010
        Foo(); Foo()
        for i in range(10):
            if module.getCounter() >= 3030:
                break
            # NB. use self.debug_collect() instead of gc.collect(),
            # otherwise rawrefcount's dealloc callback doesn't trigger
            self.debug_collect()
        assert module.getCounter() == 3030
        #
        class Bar(Foo):
            pass
        assert Foo.__new__ is Bar.__new__
        Bar(); Bar()
        for i in range(10):
            if module.getCounter() >= 5050:
                break
            self.debug_collect()
        assert module.getCounter() == 5050
        #
        module.newInstance(Foo)
        for i in range(10):
            if module.getCounter() >= 6060:
                break
            self.debug_collect()
        assert module.getCounter() == 6060
        #
        module.newInstance(Bar)
        for i in range(10):
            if module.getCounter() >= 7070:
                break
            self.debug_collect()
        assert module.getCounter() == 7070

    def test_tp_call_reverse(self):
        module = self.import_extension('foo', [
           ("new_obj", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''
            )], prologue='''
            static PyObject *
            my_tp_call(PyObject *self, PyObject *args, PyObject *kwds)
            {
                return PyLong_FromLong(42);
            }
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            ''', more_init='''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_call = &my_tp_call;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        x = module.new_obj()
        assert x() == 42
        assert x(4, bar=5) == 42

    def test_custom_metaclass(self):
        module = self.import_extension('foo', [
           ("getMetaClass", "METH_NOARGS",
            '''
                Py_INCREF(&FooType_Type);
                return (PyObject *)&FooType_Type;
            '''
            )], prologue='''
            static PyTypeObject FooType_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.Type",
            };
            ''', more_init='''
                FooType_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                FooType_Type.tp_base = &PyType_Type;
                if (PyType_Ready(&FooType_Type) < 0) INITERROR;
            ''')
        FooType = module.getMetaClass()
        if not self.runappdirect:
            self._check_type_object(FooType)

        # 2 vs 3 shenanigans to declare
        # class X(object, metaclass=FooType): pass
        X = FooType('X', (object,), {})

        X()

    def test_multiple_inheritance3(self):
        module = self.import_extension('foo', [
           ("new_obj", "METH_NOARGS",
            '''
                PyObject *obj;
                PyTypeObject *Base1, *Base2, *Base12;
                Base1 =  (PyTypeObject*)PyType_Type.tp_alloc(&PyType_Type, 0);
                Base2 =  (PyTypeObject*)PyType_Type.tp_alloc(&PyType_Type, 0);
                Base12 =  (PyTypeObject*)PyType_Type.tp_alloc(&PyType_Type, 0);
                Base1->tp_name = "Base1";
                Base2->tp_name = "Base2";
                Base12->tp_name = "Base12";
                Base1->tp_basicsize = sizeof(PyHeapTypeObject);
                Base2->tp_basicsize = sizeof(PyHeapTypeObject);
                Base12->tp_basicsize = sizeof(PyHeapTypeObject);
                PyObject * dummyname = PyUnicode_FromString("dummy name");
                ((PyHeapTypeObject*)Base1)->ht_qualname = dummyname;
                ((PyHeapTypeObject*)Base2)->ht_qualname = dummyname;
                ((PyHeapTypeObject*)Base12)->ht_qualname = dummyname;
                ((PyHeapTypeObject*)Base1)->ht_name = PyUnicode_FromString("Base1");
                ((PyHeapTypeObject*)Base2)->ht_name = PyUnicode_FromString("Base2");
                ((PyHeapTypeObject*)Base12)->ht_name = PyUnicode_FromString("Base12");
                Base1->tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HEAPTYPE;
                Base2->tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HEAPTYPE;
                Base12->tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HEAPTYPE;
                Base12->tp_base = Base1;
                Base12->tp_bases = PyTuple_Pack(2, Base1, Base2);
                Base12->tp_doc = "The Base12 type or object";
                if (PyType_Ready(Base1) < 0) return NULL;
                if (PyType_Ready(Base2) < 0) return NULL;
                if (PyType_Ready(Base12) < 0) return NULL;
                obj = PyObject_New(PyObject, Base12);
                return obj;
            '''
            ),
            ("test_getslot", "METH_O",
            '''
                PyTypeObject *typ = (PyTypeObject *)PyObject_Type(args);
                if (! PyType_HasFeature(typ, Py_TPFLAGS_HEAPTYPE) ) {
                    return PyLong_FromLong(-1);
                }
                void * tp_bases = PyType_GetSlot(typ, Py_tp_bases);
                long eq = (tp_bases == (void*)typ->tp_bases);
                return PyLong_FromLong(eq);
            ''')])
        obj = module.new_obj()
        assert 'Base12' in str(obj)
        assert type(obj).__doc__ == "The Base12 type or object"
        assert obj.__doc__ == "The Base12 type or object"
        assert module.test_getslot(obj) == 1

    def test_multiple_inheritance_fetch_tp_bases(self):
        module = self.import_extension('foo', [
           ("foo", "METH_O",
            '''
                PyTypeObject *tp;
                tp = (PyTypeObject*)args;
                Py_INCREF(tp->tp_bases);
                return tp->tp_bases;
            '''
            )])
        class A(object):
            pass
        class B(object):
            pass
        class C(A, B):
            pass
        bases = module.foo(C)
        assert bases == (A, B)

    def test_getattr_getattro(self):
        module = self.import_module(name='foo')
        assert module.gettype2.dcba == b'getattro:dcba'
        assert (type(module.gettype2).__getattribute__(module.gettype2, 'dcBA')
            == b'getattro:dcBA')
        assert module.gettype1.abcd == b'getattr:abcd'
        # GetType1 objects have a __getattribute__ method, but this
        # doesn't call tp_getattr at all, also on CPython
        raises(AttributeError, type(module.gettype1).__getattribute__,
                               module.gettype1, 'dcBA')

    def test_multiple_inheritance_tp_basicsize(self):
        module = self.import_module(name='issue2482')

        class PyBase(object):
            pass

        basesize = module.get_basicsize(PyBase)

        CBase = module.issue2482_object
        class A(CBase, PyBase):
            def __init__(self, i):
                CBase.__init__(self)
                PyBase.__init__(self)

        class B(PyBase, CBase):
            def __init__(self, i):
                PyBase.__init__(self)
                CBase.__init__(self)

        Asize = module.get_basicsize(A)
        Bsize = module.get_basicsize(B)
        assert Asize == Bsize
        assert Asize > basesize

    def test_multiple_inheritance_bug1(self):
        module = self.import_extension('foo', [
           ("get_type", "METH_NOARGS",
            '''
                Py_INCREF(&Foo_Type);
                return (PyObject *)&Foo_Type;
            '''
            ), ("forty_two", "METH_O",
            '''
                return PyInt_FromLong(42);
            '''
            )], prologue='''
            #if PY_MAJOR_VERSION > 2
            #define PyInt_FromLong PyLong_FromLong
            #endif
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            static PyObject *dummy_new(PyTypeObject *t, PyObject *a,
                                       PyObject *k)
            {
                abort();   /* never actually called in CPython */
            }
            ''', more_init = '''
                Foo_Type.tp_base = (PyTypeObject *)PyExc_Exception;
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE;
                Foo_Type.tp_new = dummy_new;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        Foo = module.get_type()
        class A(Foo, SyntaxError):
            pass
        assert A.__base__ is SyntaxError
        A(42)    # assert is not aborting

        class Bar(Exception):
            __new__ = module.forty_two

        class B(Bar, SyntaxError):
            pass

        assert B() == 42

        # aaaaa even more hackiness
        class C(A):
            pass
        C(42)   # assert is not aborting

    def test_getset(self):
        module = self.import_extension('foo', [
           ("get_instance", "METH_NOARGS",
            '''
                return PyObject_New(PyObject, &Foo_Type);
            '''
            ), ("get_number", "METH_NOARGS",
            '''
                return PyInt_FromLong(my_global_number);
            '''
            )], prologue='''
            #if PY_MAJOR_VERSION > 2
            #define PyInt_FromLong PyLong_FromLong
            #define PyInt_AsLong PyLong_AsLong
            #endif
            static long my_global_number;
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            static PyObject *bar_get(PyObject *foo, void *closure)
            {
                return PyInt_FromLong(1000 + (long)closure);
            }
            static PyObject *baz_get(PyObject *foo, void *closure)
            {
                return PyInt_FromLong(2000 + (long)closure);
            }
            static int baz_set(PyObject *foo, PyObject *x, void *closure)
            {
                if (x != NULL)
                    my_global_number = 3000 + (long)closure + PyInt_AsLong(x);
                else
                    my_global_number = 4000 + (long)closure;
                return 0;
            }
            static PyGetSetDef foo_getset[] = {
                { "bar", bar_get, NULL, "mybardoc", (void *)42 },
                { "baz", baz_get, baz_set, "mybazdoc", (void *)43 },
                { NULL }
            };
            ''', more_init = '''
                Foo_Type.tp_getset = foo_getset;
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        foo = module.get_instance()
        assert foo.bar == 1042
        assert foo.bar == 1042
        assert foo.baz == 2043
        foo.baz = 50000
        assert module.get_number() == 53043
        e = raises(AttributeError, "foo.bar = 0")
        assert str(e.value).startswith("attribute 'bar' of '")
        assert str(e.value).endswith("foo' objects is not writable")
        del foo.baz
        assert module.get_number() == 4043
        raises(AttributeError, "del foo.bar")

    def test_tp_doc_issue3055(self):
        module = self.import_extension('foo', [
           ("new_obj", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''
            )], prologue='''
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
                sizeof(PyObject),
            };
            ''', more_init = '''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_doc = "";
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        obj = module.new_obj()
        assert type(obj).__doc__ is None

    def test_vectorcall(self):
        module = self.import_extension('foo', [
            ("pyobject_vectorcall", "METH_VARARGS",
             '''
                PyObject *func, *func_args, *kwnames = NULL;
                PyObject **stack;
                Py_ssize_t nargs;

                if (!PyArg_ParseTuple(args, "OOO", &func, &func_args, &kwnames)) {
                    return NULL;
                }
                if (args == Py_None) {
                    stack = NULL;
                    nargs = 0;
                }
                else if (PyTuple_Check(args)) {
                    stack = ((PyTupleObject *)func_args)->ob_item;
                    nargs = PyTuple_GET_SIZE(func_args);
                }
                if (kwnames == Py_None) {
                    kwnames = NULL;
                }
                else if (PyTuple_Check(kwnames)) {
                    Py_ssize_t nkw = PyTuple_GET_SIZE(kwnames);
                    if (nargs < nkw) {
                        PyErr_SetString(PyExc_ValueError, "kwnames longer than args");
                        return NULL;
                    }
                    nargs -= nkw;
                }
                else {
                    PyErr_SetString(PyExc_TypeError, "kwnames must be None or a tuple");
                    return NULL;
                }
                return PyObject_Vectorcall(func, stack, nargs, kwnames);
            '''),
            ("pyvectorcall_call", "METH_VARARGS",
             # taken from _testcapimodule.c
             '''
                PyObject *func;
                PyObject *argstuple;
                PyObject *kwargs = NULL;

                if (!PyArg_ParseTuple(args, "OO|O", &func, &argstuple, &kwargs)) {
                    return NULL;
                }

                if (!PyTuple_Check(argstuple)) {
                    PyErr_SetString(PyExc_TypeError, "args must be a tuple");
                    return NULL;
                }
                if (kwargs != NULL && !PyDict_Check(kwargs)) {
                    PyErr_SetString(PyExc_TypeError, "kwargs must be a dict");
                    return NULL;
                }

                return PyVectorcall_Call(func, argstuple, kwargs);
             '''),
            ],
            prologue="""
                #include <stddef.h>
                typedef struct {
                    PyObject_HEAD
                    vectorcallfunc vectorcall;
                } MethodDescriptorObject;

                static PyObject *
                MethodDescriptor_vectorcall(PyObject *callable, PyObject *const *args,
                                            size_t nargsf, PyObject *kwnames)
                {
                    /* True if using the vectorcall function in MethodDescriptorObject
                     * but False for MethodDescriptor2Object */
                    MethodDescriptorObject *md = (MethodDescriptorObject *)callable;
                    return PyBool_FromLong(md->vectorcall != NULL);
                }

                static PyObject *
                MethodDescriptor_new(PyTypeObject* type, PyObject* args, PyObject *kw)
                {
                    MethodDescriptorObject *op = (MethodDescriptorObject *)type->tp_alloc(type, 0);
                    op->vectorcall = MethodDescriptor_vectorcall;
                    return (PyObject *)op;
                }

                static PyObject *
                func_descr_get(PyObject *func, PyObject *obj, PyObject *type)
                {
                    if (obj == Py_None || obj == NULL) {
                        Py_INCREF(func);
                        return func;
                    }
                    return PyMethod_New(func, obj);
                }

                static PyTypeObject MethodDescriptorBase_Type = {
                    PyVarObject_HEAD_INIT(NULL, 0)
                    "MethodDescriptorBase",
                    sizeof(MethodDescriptorObject),
                    .tp_new = MethodDescriptor_new,
                    .tp_call = PyVectorcall_Call,
                    .tp_vectorcall_offset = offsetof(MethodDescriptorObject, vectorcall),
                    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE |
                                Py_TPFLAGS_METHOD_DESCRIPTOR | Py_TPFLAGS_HAVE_VECTORCALL,
                    .tp_descr_get = func_descr_get,
                };

                static PyTypeObject MethodDescriptorDerived_Type = {
                    PyVarObject_HEAD_INIT(NULL, 0)
                    "MethodDescriptorDerived",
                    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
                };

                typedef struct {
                    MethodDescriptorObject base;
                    vectorcallfunc vectorcall;
                } MethodDescriptor2Object;

                static PyObject *
                MethodDescriptor2_new(PyTypeObject* type, PyObject* args, PyObject *kw)
                {
                    MethodDescriptor2Object *op = PyObject_New(MethodDescriptor2Object, type);
                    op->base.vectorcall = NULL;
                    op->vectorcall = MethodDescriptor_vectorcall;
                    return (PyObject *)op;
                }

                static PyTypeObject MethodDescriptor2_Type = {
                    PyVarObject_HEAD_INIT(NULL, 0)
                    "MethodDescriptor2",
                    sizeof(MethodDescriptor2Object),
                    .tp_new = MethodDescriptor2_new,
                    .tp_call = PyVectorcall_Call,
                    .tp_vectorcall_offset = offsetof(MethodDescriptor2Object, vectorcall),
                    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_VECTORCALL,
                };


            """,
            more_init="""
                if (PyType_Ready(&MethodDescriptorBase_Type) < 0)
                    INITERROR;
                Py_INCREF(&MethodDescriptorBase_Type);
                PyModule_AddObject(mod, "MethodDescriptorBase",
                                   (PyObject *)&MethodDescriptorBase_Type);
                MethodDescriptorDerived_Type.tp_base = &MethodDescriptorBase_Type;
                if (PyType_Ready(&MethodDescriptorDerived_Type) < 0)
                    INITERROR;
                Py_INCREF(&MethodDescriptorDerived_Type);
                PyModule_AddObject(mod, "MethodDescriptorDerived",
                                   (PyObject *)&MethodDescriptorDerived_Type);

                MethodDescriptor2_Type.tp_base = &MethodDescriptorBase_Type;
                if (PyType_Ready(&MethodDescriptor2_Type) < 0)
                    return NULL;
                Py_INCREF(&MethodDescriptor2_Type);
                PyModule_AddObject(mod, "MethodDescriptor2", (PyObject *)&MethodDescriptor2_Type);
            """)
        def pyfunc(arg1, arg2):
            return [arg1, arg2]

        def testfunction(self):
            """some doc"""
            return self

        def testfunction_kw(self, **kw):
            """some doc"""
            return self

        res = module.pyobject_vectorcall(pyfunc, (1, 2), None)
        assert res == [1, 2]
        res = module.pyobject_vectorcall(pyfunc, (1, 2), ("arg2", ))
        assert res == [1, 2]
        method = module.MethodDescriptorBase()
        res = module.pyobject_vectorcall(method, (0, ), None)
        assert res == True

        calls = [(len, (range(42),), {}, 42),
                 (list.append, ([], 0), {}, None),
                 ([].append, (0,), {}, None),
                 (sum, ([36],), {"start":6}, 42),
                 (testfunction, (42,), {}, 42),
                 (testfunction_kw, (42,), {"kw":None}, 42),
                 (module.MethodDescriptorBase(), (0,), {}, True),
                 (module.MethodDescriptorDerived(), (0,), {}, True),
                 (module.MethodDescriptor2(), (0,), {}, False)]

        from types import MethodType
        from functools import partial

        def vectorcall(func, *args, **kwargs):
            if kwargs:
                args = args + tuple(kwargs.values())
            kwnames = tuple(kwargs.keys())
            return module.pyobject_vectorcall(func, args, kwnames)

        for (func, args, kwargs, expected) in calls:
            print(func, args, kwargs, expected)
            if not kwargs:
                assert expected == module.pyvectorcall_call(func, args)
            assert expected == module.pyvectorcall_call(func, args, kwargs)

        # Add derived classes (which do not support vectorcall directly,
        # but do support all other ways of calling).

        class MethodDescriptorHeap(module.MethodDescriptorBase):
            pass

        class MethodDescriptorOverridden(module.MethodDescriptorBase):
            def __call__(self, n):
                return 'new'

        class SuperBase:
            def __call__(self, *args):
                return super().__call__(*args)

        class MethodDescriptorSuper(SuperBase, module.MethodDescriptorBase):
            def __call__(self, *args):
                return super().__call__(*args)

        calls += [
            (dict.update, ({},), {"key":True}, None),
            ({}.update, ({},), {"key":True}, None),
            (MethodDescriptorHeap(), (0,), {}, True),
            (MethodDescriptorOverridden(), (0,), {}, 'new'),
            (MethodDescriptorSuper(), (0,), {}, True),
        ]

        for (func, args, kwargs, expected) in calls:
            args1 = args[1:]
            meth = MethodType(func, args[0])
            wrapped = partial(func)
            if not kwargs:
                assert expected == func(*args)
                assert expected == module.pyobject_vectorcall(func, args, None)
                assert expected == meth(*args1)
                assert expected == wrapped(*args)
            assert expected == func(*args, **kwargs)
            assert expected == vectorcall(func, *args, **kwargs)
            assert expected == meth(*args1, **kwargs)
            assert expected == wrapped(*args, **kwargs)

    def test_fastcall(self):
        module = self.import_extension('foo', [
            ("test_fastcall", "METH_VARARGS",
             '''
                PyObject *func, *func_args = NULL;
                PyObject **stack;
                Py_ssize_t nargs;

                if (!PyArg_ParseTuple(args, "OO", &func, &func_args)) {
                    return NULL;
                }
                if (args == Py_None) {
                    stack = NULL;
                    nargs = 0;
                }
                else if (PyTuple_Check(args)) {
                    stack = ((PyTupleObject *)func_args)->ob_item;
                    nargs = PyTuple_GET_SIZE(func_args);
                }
                return _PyObject_FastCall(func, stack, nargs);
            ''')])
        def pyfunc(arg1, arg2):
            return [arg1, arg2]
        res = module.test_fastcall(pyfunc, (1, 2))
        assert res == [1, 2]

    def test_fastcalldict(self):
        module = self.import_extension('foo', [
            ("test_fastcalldict", "METH_VARARGS",
             '''
                PyObject *func, *func_args, *kwargs = NULL;
                PyObject **stack;
                Py_ssize_t nargs;

                if (!PyArg_ParseTuple(args, "OOO", &func, &func_args, &kwargs)) {
                    return NULL;
                }
                if (args == Py_None) {
                    stack = NULL;
                    nargs = 0;
                }
                else if (PyTuple_Check(args)) {
                    stack = ((PyTupleObject *)func_args)->ob_item;
                    nargs = PyTuple_GET_SIZE(func_args);
                }
                if (kwargs == Py_None) {
                    kwargs = NULL;
                }
                else if (!PyDict_Check(kwargs)) {
                    PyErr_SetString(PyExc_TypeError, "kwnames must be None or a dict");
                    return NULL;
                }
                return PyObject_VectorcallDict(func, stack, nargs, kwargs);
            ''')])
        def pyfunc(arg1, arg2):
            return [arg1, arg2]
        res = module.test_fastcalldict(pyfunc, (1, 2), None)
        assert res == [1, 2]
        res = module.test_fastcalldict(pyfunc, (1, 2), {})
        assert res == [1, 2]
        res = module.test_fastcalldict(pyfunc, (1, ), {"arg2": 2})
        assert res == [1, 2]

    def test_call_no_args(self):
        module = self.import_extension('foo', [
            ("test_callnoarg", "METH_VARARGS",
             '''
                PyObject *func = NULL;
                if (!PyArg_ParseTuple(args, "O", &func)) {
                    return NULL;
                }
                return _PyObject_CallNoArg(func);
            ''')])
        assert module.test_callnoarg(lambda : 4) == 4


class AppTestHashable(AppTestCpythonExtensionBase):
    def test_unhashable(self):
        if not self.runappdirect:
            skip('pointer to function equality available'
                 ' only after translation')
        module = self.import_extension('foo', [
           ("new_obj", "METH_NOARGS",
            '''
                PyObject *obj;
                obj = PyObject_New(PyObject, &Foo_Type);
                return obj;
            '''
            )], prologue='''
            static PyTypeObject Foo_Type = {
                PyVarObject_HEAD_INIT(NULL, 0)
                "foo.foo",
            };
            ''', more_init = '''
                Foo_Type.tp_flags = Py_TPFLAGS_DEFAULT;
                Foo_Type.tp_hash = PyObject_HashNotImplemented;
                if (PyType_Ready(&Foo_Type) < 0) INITERROR;
            ''')
        obj = module.new_obj()
        raises(TypeError, hash, obj)
        assert type(obj).__dict__['__hash__'] is None
        # this is equivalent to
        from collections import Hashable
        assert not isinstance(obj, Hashable)


class AppTestFlags(AppTestCpythonExtensionBase):
    def test_has_subclass_flag(self):
        module = self.import_extension('foo', [
           ("test_flags", "METH_VARARGS",
            '''
                long long in_flag, my_flag;
                PyObject * obj;
                if (!PyArg_ParseTuple(args, "OL", &obj, &in_flag))
                    return NULL;
                if (!PyType_Check(obj))
                {
                    PyErr_SetString(PyExc_ValueError, "input must be type");
                    return NULL;
                }
                my_flag = ((PyTypeObject*)obj)->tp_flags;
                if ((my_flag & in_flag) != in_flag)
                    return PyLong_FromLong(-1);
                if (!PyType_CheckExact(obj)) {
                    if ((my_flag & Py_TPFLAGS_TYPE_SUBCLASS) == Py_TPFLAGS_TYPE_SUBCLASS)
                        return PyLong_FromLong(-2);
                }
                return PyLong_FromLong(0);
            '''),])
        # copied from object.h
        Py_TPFLAGS_LONG_SUBCLASS = (1<<24)
        Py_TPFLAGS_LIST_SUBCLASS = (1<<25)
        Py_TPFLAGS_TUPLE_SUBCLASS = (1<<26)
        Py_TPFLAGS_BYTES_SUBCLASS = (1<<27)
        Py_TPFLAGS_UNICODE_SUBCLASS = (1<<28)
        Py_TPFLAGS_DICT_SUBCLASS = (1<<29)
        Py_TPFLAGS_BASE_EXC_SUBCLASS = (1<<30)
        Py_TPFLAGS_TYPE_SUBCLASS = (1<<31)
        for t,f in ((int, Py_TPFLAGS_LONG_SUBCLASS),
                    (list, Py_TPFLAGS_LIST_SUBCLASS),
                    (tuple, Py_TPFLAGS_TUPLE_SUBCLASS),
                    (bytes, Py_TPFLAGS_BYTES_SUBCLASS),
                    (str, Py_TPFLAGS_UNICODE_SUBCLASS),
                    (dict, Py_TPFLAGS_DICT_SUBCLASS),
                    (Exception, Py_TPFLAGS_BASE_EXC_SUBCLASS),
                    (type, Py_TPFLAGS_TYPE_SUBCLASS),
                   ):
            assert module.test_flags(t, f) == 0
        class MyList(list):
            pass
        assert module.test_flags(MyList, Py_TPFLAGS_LIST_SUBCLASS) == 0

    def test_has_pypy_subclass_flag(self):
        module = self.import_extension('foo', [
           ("test_pypy_flags", "METH_VARARGS",
            '''
                long long in_flag, my_flag;
                PyObject * obj;
                if (!PyArg_ParseTuple(args, "OL", &obj, &in_flag))
                    return NULL;
                if (!PyType_Check(obj))
                {
                    PyErr_SetString(PyExc_ValueError, "input must be type");
                    return NULL;
                }
                my_flag = ((PyTypeObject*)obj)->tp_pypy_flags;
                if ((my_flag & in_flag) != in_flag)
                    return PyLong_FromLong(-1);
                return PyLong_FromLong(0);
            '''),])
        # copied from object.h
        Py_TPPYPYFLAGS_FLOAT_SUBCLASS = (1<<0)

        class MyFloat(float):
            pass
        assert module.test_pypy_flags(float, Py_TPPYPYFLAGS_FLOAT_SUBCLASS) == 0
        assert module.test_pypy_flags(MyFloat, Py_TPPYPYFLAGS_FLOAT_SUBCLASS) == 0

    def test_newgetset(self):
        # Taken from the yara-python project
        module = self.import_extension('foo', [
            ('newexc', 'METH_NOARGS',
             """
                PyObject *YaraWarningError = PyErr_NewException("foo.YaraWarningError", PyExc_Exception, NULL);

                PyTypeObject *YaraWarningError_type = (PyTypeObject *) YaraWarningError;
                PyObject* descr = PyDescr_NewGetSet(YaraWarningError_type,
                                                    YaraWarningError_getsetters);
                if (PyDict_SetItem(YaraWarningError_type->tp_dict,
                                   PyDescr_NAME(descr), descr) < 0) {
                    Py_DECREF(descr);
                    return NULL;
                }
                return YaraWarningError;
            """),
            ], prologue="""
                static PyObject* YaraWarningError_getwarnings(PyObject *self, void* closure)
                {
                  PyObject *args = PyObject_GetAttrString(self, "args");
                  if (!args) {
                    return NULL;
                  }

                  PyObject* ret = PyTuple_GetItem(args, 0);
                  Py_XINCREF(ret);
                  Py_XDECREF(args);
                  return ret;
                }

                static PyGetSetDef YaraWarningError_getsetters[] = {
                  {"warnings", YaraWarningError_getwarnings, NULL, NULL, NULL},
                  {NULL}
                };
             """)
        errtype = module.newexc()
        err = errtype("abc")
        assert err.warnings == "abc"
