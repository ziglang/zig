from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.api import PyObject

class AppTestStructSeq(AppTestCpythonExtensionBase):
    def test_StructSeq(self):
        module = self.import_extension('foo',
        prologue="""
            #include <structseq.h>
            static PyTypeObject PyDatatype;

            static PyStructSequence_Field Data_fields[] = {
                {"value", "value_doc"},
                {"value2", "value_doc"},
                {"text",  "text_doc"},
                {"other", "other_doc"},
                {NULL}  /* Sentinel */
            };
            static PyStructSequence_Desc Data_desc = {
                "cpyext_test.data",           /*name*/
                "data_doc",                   /*doc*/
                Data_fields,                  /*fields*/
                3,                            /*n_in_sequence*/
            };
            """,
        functions=[
            ("new_structdata", "METH_NOARGS",
             """
                 PyObject *seq;
                 PyStructSequence_InitType(&PyDatatype, &Data_desc);
                 if (PyErr_Occurred()) return NULL;
                 seq = PyStructSequence_New(&PyDatatype);
                 if (!seq) return NULL;
                 PyStructSequence_SET_ITEM(seq, 0, PyLong_FromLong(42));
                 PyStructSequence_SET_ITEM(seq, 1, PyLong_FromLong(43));
                 PyStructSequence_SET_ITEM(seq, 2, PyUnicode_FromString("hello"));
                 PyStructSequence_SET_ITEM(seq, 3, PyUnicode_FromString("other"));
                 Py_DECREF(&PyDatatype);
                 return seq;
             """)])
        s = module.new_structdata()
        assert tuple(s) == (42, 43, 'hello')
        assert s.value == 42
        assert s.text == 'hello'
        assert s.other == 'other'
        assert 'hello' in s
        assert 'other' not in s
        del s
