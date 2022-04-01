# encoding: utf-8
import pytest
from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.unicodeobject import (
    Py_UNICODE, PyUnicodeObject, new_empty_unicode)
from pypy.module.cpyext.api import (PyObjectP, PyObject, 
                           Py_CLEANUP_SUPPORTED, INTP_real)
from pypy.module.cpyext.pyobject import decref, from_ref
from rpython.rtyper.lltypesystem import rffi, lltype
import sys, py
from pypy.module.cpyext.unicodeobject import *

class AppTestUnicodeObject(AppTestCpythonExtensionBase):
    def test_unicodeobject(self):
        module = self.import_extension('foo', [
            ("get_hello1", "METH_NOARGS",
             """
                 return PyUnicode_FromStringAndSize(
                     "Hello world<should not be included>", 11);
             """),
            ("test_GetSize", "METH_NOARGS",
             """
                 PyObject* s = PyUnicode_FromString("Hello world");
                 int result = 0;

                 if(PyUnicode_GetSize(s) != 11) {
                     result = -PyUnicode_GetSize(s);
                 }
                 if(s->ob_type->tp_basicsize != sizeof(PyUnicodeObject))
                     result = s->ob_type->tp_basicsize;
                 Py_DECREF(s);
                 return PyLong_FromLong(result);
             """),
            ("test_GetLength", "METH_NOARGS",
             """
                 PyObject* s = PyUnicode_FromString("Hello world");
                 int result = 0;

                 if(PyUnicode_GetLength(s) != 11) {
                     result = -PyUnicode_GetLength(s);
                 }
                 Py_DECREF(s);
                 return PyLong_FromLong(result);
             """),
            ("test_GetSize_exception", "METH_NOARGS",
             """
                 PyObject* f = PyFloat_FromDouble(1.0);
                 PyUnicode_GetSize(f);

                 Py_DECREF(f);
                 return NULL;
             """),
             ("test_is_unicode", "METH_VARARGS",
             """
                return PyBool_FromLong(PyUnicode_Check(PyTuple_GetItem(args, 0)));
             """)])
        assert module.get_hello1() == u'Hello world'
        assert module.test_GetSize() == 0
        raises(TypeError, module.test_GetSize_exception)

        # XXX: needs a test where it differs from GetSize
        assert module.test_GetLength() == 0

        assert module.test_is_unicode(u"")
        assert not module.test_is_unicode(())

    def test_strlen(self):
        module = self.import_extension('foo', [
            ('strlen', "METH_O",
             """
                PyObject* s = PyObject_Str(args);
                return PyLong_FromLong(PyUnicode_GetLength(s));
             """)])
        assert module.strlen(True) == 4
        assert module.strlen('a' * 40) == 40

    def test_intern_inplace(self):
        module = self.import_extension('foo', [
            ("test_intern_inplace", "METH_O",
             '''
                 PyObject *s = args;
                 Py_INCREF(s);
                 PyUnicode_InternInPlace(&s);
                 return s;
             '''
             )])
        # This does not test much, but at least the refcounts are checked.
        assert module.test_intern_inplace('s') == 's'


    def test_unicode_buffer_init(self):
        module = self.import_extension('foo', [
            ("getunicode", "METH_NOARGS",
             """
                 PyObject *s, *t;
                 Py_UNICODE* c;

                 s = PyUnicode_FromUnicode(NULL, 4);
                 if (s == NULL)
                    return NULL;
                 t = PyUnicode_FromUnicode(NULL, 3);
                 if (t == NULL)
                    return NULL;
                 Py_DECREF(t);
                 c = PyUnicode_AsUnicode(s);
                 c[0] = 'a';
                 c[1] = 0xe9;
                 c[2] = 0x00;
                 c[3] = 'c';
                 return s;
             """),
            ])
        s = module.getunicode()
        assert len(s) == 4
        assert s == u'a\xe9\x00c'

    def test_default_encoded_string(self):
        import sys
        module = self.import_extension('foo', [
            ("test_default_encoded_string", "METH_O",
             '''
                PyObject* result = PyUnicode_AsEncodedString(args, NULL, "replace");
                Py_INCREF(result);
                return result;
             '''
             ),
            ])
        res = module.test_default_encoded_string(u"xyz")
        assert res == b'xyz'
        res = module.test_default_encoded_string(u"caf\xe9")
        assert res == u"caf\xe9".encode(sys.getdefaultencoding(), 'replace')

    def test_unicode_macros(self):
        """The PyUnicode_* macros cast, and calls expecting that build."""
        module = self.import_extension('foo', [
             ("test_macro_invocations", "METH_NOARGS",
             """
                PyObject* o = PyUnicode_FromString("");
                PyUnicodeObject* u = (PyUnicodeObject*)o;

                PyUnicode_GET_SIZE(u);
                PyUnicode_GET_SIZE(o);

                PyUnicode_GET_DATA_SIZE(u);
                PyUnicode_GET_DATA_SIZE(o);

                PyUnicode_AS_UNICODE(o);
                PyUnicode_AS_UNICODE(u);
                return o;
             """)])
        assert module.test_macro_invocations() == u''


    def test_format_v(self):
        module = self.import_extension('foo', [
            ("test_unicode_format_v", "METH_VARARGS",
             '''
                 return helper("bla %d ble %s\\n",
                        PyLong_AsLong(PyTuple_GetItem(args, 0)),
                        _PyUnicode_AsString(PyTuple_GetItem(args, 1)));
             '''
             )
            ], prologue='''
            PyObject* helper(char* fmt, ...)
            {
              va_list va;
              PyObject* res;
              va_start(va, fmt);
              res = PyUnicode_FromFormatV(fmt, va);
              va_end(va);
              return res;
            }
            ''')
        res = module.test_unicode_format_v(1, "xyz")
        assert res == "bla 1 ble xyz\n"

    def test_format1(self):
        module = self.import_extension('foo', [
            ("test_unicode_format", "METH_VARARGS",
             '''
                 return PyUnicode_FromFormat("bla %d ble %s\\n",
                        PyLong_AsLong(PyTuple_GetItem(args, 0)),
                        _PyUnicode_AsString(PyTuple_GetItem(args, 1)));
             '''
             )
            ])
        res = module.test_unicode_format(1, "xyz")
        assert res == "bla 1 ble xyz\n"

    def test_format_obj(self):
        module = self.import_extension('foo', [
            ("format_obj", "METH_VARARGS",
            """
                char *fmt = PyUnicode_AsUTF8(PyTuple_GetItem(args, 0));
                return PyUnicode_FromFormat(fmt, PyTuple_GetItem(args, 1));
            """),
            ("format_d_str", "METH_VARARGS",
            """
                char *fmt = PyUnicode_AsUTF8(PyTuple_GetItem(args, 0));
                if (PyObject_Size(args) != 3) {
                    PyErr_SetString(PyExc_RuntimeError, "bad args");
                    return NULL;
                }
                long d = PyLong_AsLong(PyTuple_GetItem(args, 1));
                char *s2 = PyUnicode_AsUTF8(PyTuple_GetItem(args, 2));
                return PyUnicode_FromFormat(fmt, d, s2);
            """),
            ("format_str_str", "METH_VARARGS",
            """
                char *fmt = PyUnicode_AsUTF8(PyTuple_GetItem(args, 0));
                if (PyObject_Size(args) != 3) {
                    PyErr_SetString(PyExc_RuntimeError, "bad args");
                    return NULL;
                }
                char *s1 = PyUnicode_AsUTF8(PyTuple_GetItem(args, 1));
                char *s2 = PyUnicode_AsUTF8(PyTuple_GetItem(args, 2));
                return PyUnicode_FromFormat(fmt, s1, s2);
            """),
            ("format_parsing", "METH_NOARGS",
            """
                /* From getargs.c */ 
                char *fmt = "%.150s%s takes %s %d argument%s (%ld given)";
                return PyUnicode_FromFormat(fmt, "add", "()", "exactly", 2, "s", 1);
            """),
            ])
        assert module.format_obj("formatting 100R '%.100R'", 1.0) == "formatting 100R '1.0'"
        assert module.format_d_str("id:%d, name:%s", 12, "abc") == "id:12, name:abc"
        ret = module.format_str_str("%.200s%s takes no arguments", "abc", "def")
        assert ret == "abcdef takes no arguments"
        assert module.format_parsing() == "add() takes exactly 2 arguments (1 given)";

    def test_fromkind(self):
        module = self.import_extension('foo', [
            ('from_ucs1', 'METH_O',
             """
             char* p;
             Py_ssize_t size;
             if (PyBytes_AsStringAndSize(args, &p, &size) < 0)
                return NULL;
             return PyUnicode_FromKindAndData(PyUnicode_1BYTE_KIND, p, size);
             """),
            ('from_ucs2', 'METH_O',
             """
             char* p;
             Py_ssize_t size;
             if (PyBytes_AsStringAndSize(args, &p, &size) < 0)
                return NULL;
             return PyUnicode_FromKindAndData(PyUnicode_2BYTE_KIND, p, size/2);
             """),
            ('from_ucs4', 'METH_O',
             """
             char* p;
             Py_ssize_t size;
             if (PyBytes_AsStringAndSize(args, &p, &size) < 0)
                return NULL;
             return PyUnicode_FromKindAndData(PyUnicode_4BYTE_KIND, p, size/4);
             """)])
        res = module.from_ucs1(b'spam')
        assert res == 'spam'
        s = "späm"
        b = s.encode('utf-16')[2:]  # Skip the BOM
        s2 = module.from_ucs2(b)
        assert module.from_ucs2(b) == s
        s = "x\N{PILE OF POO}x"
        b = s.encode('utf-32')[4:]  # Skip the BOM
        assert module.from_ucs4(b) == s
        # Issue 3165
        b = b'\x00\xd8\x00\x00'
        for func, ret in zip([module.from_ucs4, module.from_ucs2],
                        [['0xd800'], ['0xd800', '0x0']]):
            s = func(b)
            assert isinstance(s, str)
            h = [hex(ord(x)) for x in s]
            assert h == ret, '%s, %s' %(h, ret)

    def test_substring(self):
        module = self.import_extension('foo', [
            ("slice_start", "METH_VARARGS",
             '''
             PyObject* text;
             Py_ssize_t start, length;
             if (!PyArg_ParseTuple(args, "On", &text, &start))
                return NULL;
             if (PyUnicode_READY(text) == -1) return NULL;
             if (!PyUnicode_1BYTE_DATA(text)) {
                // Don't segfault, just fail the test.
                Py_RETURN_NONE;
             }
             length = PyUnicode_GET_LENGTH(text);
             if (start > length) return PyLong_FromSsize_t(start);
             return PyUnicode_FromKindAndData(PyUnicode_KIND(text),
                 PyUnicode_1BYTE_DATA(text) + start*PyUnicode_KIND(text),
                 length-start);
             ''')])
        s = u'aАbБcСdД'
        assert module.slice_start(s, 2) == 'bБcСdД'
        # s = u'xx\N{PILE OF POO}'
        s = u'xx\U0001F4A9'
        assert module.slice_start(s, 2) == u'\U0001F4A9'

    def test_aswidecharstring(self):
        module = self.import_extension('foo', [
            ("aswidecharstring", "METH_O",
             '''
             PyObject *result;
             Py_ssize_t size;
             wchar_t *buffer;

             buffer = PyUnicode_AsWideCharString(args, &size);
             if (buffer == NULL)
                 return NULL;

             result = PyUnicode_FromWideChar(buffer, size + 1);
             PyMem_Free(buffer);
             if (result == NULL)
                 return NULL;
             return Py_BuildValue("(Nn)", result, size);
             ''')])
        res = module.aswidecharstring("Caf\xe9")
        assert res == ("Caf\xe9\0", 4)

    def test_fromwidechar(self):
        module = self.import_extension('foo', [
            ("truncate", "METH_O",
             '''
             wchar_t buffer[5] = { 0 };

             if (PyUnicode_AsWideChar(args, buffer, 4) == -1)
                 return NULL;

             return PyUnicode_FromWideChar(buffer, -1);
             ''')])
        assert module.truncate("Caf\xe9") == "Caf\xe9"
        assert module.truncate("abcde") == "abcd"
        assert module.truncate("ab") == "ab"

    def test_CompareWithASCIIString(self):
        module = self.import_extension('foo', [
            ("compare", "METH_VARARGS",
             '''
             PyObject *uni;
             const char* s;
             int res;

             if (!PyArg_ParseTuple(args, "Uy", &uni, &s))
                 return NULL;

             res = PyUnicode_CompareWithASCIIString(uni, s);
             return PyLong_FromLong(res);
             ''')])
        assert module.compare("abc", b"abc") == 0
        assert module.compare("abd", b"abc") == 1
        assert module.compare("abb", b"abc") == -1
        assert module.compare("caf\xe9", b"caf\xe9") == 0
        assert module.compare("abc", b"ab") == 1
        assert module.compare("ab\0", b"ab") == 1
        assert module.compare("ab", b"abc") == -1
        assert module.compare("", b"abc") == -1
        assert module.compare("abc", b"") == 1

    def test_As_AndSize(self):
        module = self.import_extension('foo', [
             ("utf8", "METH_O",
             """
                Py_ssize_t size;
                char *utf8 = PyUnicode_AsUTF8AndSize(args, &size);
                return PyBytes_FromStringAndSize(utf8, size);
             """),
             ("unicode", "METH_O",
             """
                Py_ssize_t size;
                wchar_t *buf = PyUnicode_AsUnicodeAndSize(args, &size);
                return PyUnicode_FromUnicode(buf, size);
             """),
             ])
        assert module.utf8('xyz') == b'xyz'
        assert module.utf8('café') == 'café'.encode('utf-8')
        assert module.unicode('np') == 'np'
        assert module.unicode('café') == u'café'

    def test_ready(self):
        module = self.import_extension('foo', [
            ("unsafe_len", "METH_O",
             """
                Py_ssize_t size = PyUnicode_GET_LENGTH(args);
                return PyLong_FromSsize_t(size);
             """)])
        assert module.unsafe_len(u"abc") == 3
        assert module.unsafe_len(u"café") == 4
        assert module.unsafe_len(u'aАbБcСdД') == 8
        assert module.unsafe_len(u"café\U0001F4A9") == 5

    def test_FromObject(self):
        module = self.import_extension('foo', [
            ("from_object", "METH_O",
             """
                return PyUnicode_FromObject(args);
             """)])
        class my_str(str): pass
        assert module.from_object('abc') == 'abc'
        res = module.from_object(my_str('abc'))
        assert type(res) is str
        assert res == 'abc'
        raises(TypeError, module.from_object, b'abc')
        raises(TypeError, module.from_object, 42)

    def test_widechar(self):
        module = self.import_extension('foo', [
            ("make_wide", "METH_NOARGS",
             """
            #if defined(SIZEOF_WCHAR_T) && (SIZEOF_WCHAR_T == 4)
                const wchar_t wtext[2] = {(wchar_t)0x10ABCDu};
                size_t wtextlen = 1;
            #else
                const wchar_t wtext[3] = {(wchar_t)0xDBEAu, (wchar_t)0xDFCDu};
                size_t wtextlen = 2;
            #endif
                return PyUnicode_FromWideChar(wtext, wtextlen);
             """),
            ("make_utf8", "METH_NOARGS",
             """
            return PyUnicode_FromString("\\xf4\\x8a\\xaf\\x8d");
             """)])
        wide = module.make_wide()
        utf8 = module.make_utf8()
        print(repr(wide), repr(utf8))
        assert wide == utf8

    def test_invalid(self):
        m = self.import_module('_widechar')
        if m.get_sizeof_wchar() != 4:
            #pytest.skip('only for sizeof(wchar)==4')
            return
        exc = raises(ValueError, m.test_widechar)
        assert (str(exc.value) == 'character U+110000 is not in range '
                '[U+0000; U+10ffff]'), str(exc.value)

    def test_AsUTFNString(self):
        module = self.import_extension('foo', [
            ("asutf8", "METH_O", "return PyUnicode_AsUTF8String(args);"),
            ("asutf16", "METH_O", "return PyUnicode_AsUTF16String(args);"),
            ("asutf32", "METH_O", "return PyUnicode_AsUTF32String(args);"),
            ])
        u = u'sp\x09m\u1234\U00012345'
        s = module.asutf8(u)
        assert s == u.encode('utf-8')
        s = module.asutf16(u)
        assert s == u.encode('utf-16')
        s = module.asutf32(u)
        assert s == u.encode('utf-32')

    def test_lower_cython(self):
        # mimic exactly what cython does, without the extra checks
        import time
        module = self.import_extension('foo', [
            ("lower", "METH_O",
            """
                PyObject *p, *res, *tup;
                p = PyObject_GetAttrString(args, "lower");
                if (p == NULL) {
                    return NULL;
                }
                tup = PyTuple_New(0);
                Py_INCREF(tup);
                res = PyObject_Call(p, tup, NULL);
                Py_DECREF(tup);
                return res;
            """)])
        assert module.lower('ABC') == 'abc'
        try:
            time.tzset()
        except AttributeError:
            # only on posix
            pass
        tz1 = time.tzname[1]
        assert module.lower(tz1) == tz1.lower()

    def test_contains(self):
        import sys
        module = self.import_extension('foo', [
            ("contains", "METH_VARARGS",
            """
                PyObject *arg1 = PyTuple_GetItem(args, 0);
                PyObject *arg2 = PyTuple_GetItem(args, 1);
                int ret = PyUnicode_Contains(arg1, arg2);
                if (ret < 0) {
                    return NULL;
                }
                return PyLong_FromLong(ret);
            """)])
        s = u"abcabcabc"
        assert module.contains(s, u"a") == 1
        assert module.contains(s, u"e") == 0
        try:
            module.contains(s, 1)
        except TypeError:
            pass
        else:
            assert False
        try:
            module.contains(1, u"a")
        except TypeError:
            pass
        else:
            assert False
        if sys.version_info < (3, 0):
            assert module.contains(b'abcdef', b'e') == 1
        else:
            try:
                module.contains(b'abcdef', b'e')
            except TypeError:
                pass
            else:
                assert False


    def test_UnicodeNew(self):
        module = self.import_extension('unicodenew', [
            ("make", "METH_VARARGS",
            """
                long length = PyLong_AsLong(PyTuple_GetItem(args, 0));
                long unichr = PyLong_AsLong(PyTuple_GetItem(args, 1));

                PyObject *retval = PyUnicode_New(length, (Py_UCS4)unichr);
                if (unichr <= 255) {
                    Py_UCS1 *retbuf = PyUnicode_1BYTE_DATA(retval);
                    for (long i = 0; i < length; i++)
                        retbuf[i] = unichr;
                }
                else if (unichr <= 65535) {
                    Py_UCS2 *retbuf = PyUnicode_2BYTE_DATA(retval);
                    for (long i = 0; i < length; i++)
                        retbuf[i] = unichr;
                }
                else {
                    Py_UCS4 *retbuf = PyUnicode_4BYTE_DATA(retval);
                    for (long i = 0; i < length; i++)
                        retbuf[i] = unichr;
                }
                return retval;
            """),
            ])
        assert module.make(0, 32) == u''
        assert module.make(1, 32) == u' '
        assert module.make(5, 255) == u'\xff' * 5
        assert module.make(3, 0x1234) == u'\u1234' * 3
        assert module.make(7, 0x12345) == u'\U00012345' * 7

    def test_char_ops(self):
        module = self.import_extension('char_ops', [
            ("readchar", "METH_VARARGS",
            """
                PyObject *obj = PyTuple_GetItem(args, 0);
                Py_ssize_t indx = PyLong_AsLong(PyTuple_GetItem(args, 1));
                Py_UCS4 chr = PyUnicode_ReadChar(obj, indx);
                if (chr == (Py_UCS4)-1 || chr == (Py_UCS4)-2) {
                    return NULL;
                }
                return PyLong_FromLong(chr);
            """),
            ("writechar", "METH_VARARGS",
            """
                char *str;
                Py_ssize_t indx;
                int ch;
                if (!PyArg_ParseTuple(args, "sni", &str, &indx, &ch)) {
                    return NULL;
                }
                if (ch > (int)0xffff || ch < 0) {
                    PyErr_SetString(PyExc_OverflowError, "ch is out of bounds");
                    return NULL;
                }
                PyObject * newstr = PyUnicode_FromString(str);
                int ret = PyUnicode_WriteChar(newstr, indx, ch);
                if (ret < 0) {
                    Py_DECREF(newstr);
                    return NULL;
                }
                return newstr;
            """),
            ("findchar", "METH_VARARGS",
            """
                PyObject *uni;
                int ch;
                Py_ssize_t start, end, ret;
                int direction;
                if (!PyArg_ParseTuple(args, "Oinni", &uni, &ch, &start, &end, &direction)) {
                    return NULL;
                }
                if (ch > (int)0xffff || ch < 0) {
                    PyErr_SetString(PyExc_OverflowError, "ch is out of bounds");
                    return NULL;
                }
                ret = PyUnicode_FindChar(uni, (Py_UCS4)ch, start, end, direction);
                if (ret == -2) return NULL;
                return PyLong_FromLong(ret);
            """),
            ])
        s = 'abcdef'
        assert module.readchar(s, 3) == ord(s[3])
        try:
            newstr = module.writechar(s, 3, ord('z'))
            assert newstr[3] == 'z'
            assert newstr[0] == 'a'
        except SystemError:
            # raises on PyPy
            pass
        indx = module.findchar(s, ord('z'), 0, -1, 0)
        assert indx == -1
        indx = module.findchar(s, ord('d'), 0, -1, 0)
        assert indx == 3 

    def test_totuple(self):
        module = self.import_extension('foo', [
            ("to_tuple", "METH_O",
            """
                int i, len = PyUnicode_GET_LENGTH(args);
                enum PyUnicode_Kind kind = PyUnicode_KIND(args);
                PyObject *retval = PyTuple_New(len);
                uint8_t * c = NULL;
                uint16_t * k = NULL;
                uint32_t * u = NULL;
                
                switch (kind) {
                    case PyUnicode_1BYTE_KIND:
                        c = PyUnicode_DATA(args);
                        for(i=0; i<len; i++)
                            PyTuple_SetItem(retval, i, PyLong_FromLong(c[i])); 
                        break;
                    case PyUnicode_2BYTE_KIND:
                        k = PyUnicode_DATA(args);
                        for(i=0; i<len; i++)
                            PyTuple_SetItem(retval, i, PyLong_FromLong(k[i])); 
                        break;
                    case PyUnicode_4BYTE_KIND:
                        u = PyUnicode_DATA(args);
                        for(i=0; i<len; i++)
                            PyTuple_SetItem(retval, i, PyLong_FromLong(u[i])); 
                        break;
                    default:
                        Py_DECREF(retval);
                        PyErr_SetString(PyExc_RuntimeError, "unknown kind");
                        return NULL;
                        break;
                }
                return retval;
            """),
            ])
        for s in [u'000\x80', u'abc', u'späm', u'abcdefghij' *5 + 'z']:
            print(module.to_tuple(s), tuple([ord(x) for x in s]))
            assert module.to_tuple(s) == tuple([ord(x) for x in s])

    def test_COMPACT(self):
        module = self.import_extension('foo', [
            ("is_compact_ascii", "METH_O",
            """
                int ret = PyUnicode_IS_COMPACT_ASCII(args);
                return PyLong_FromLong(ret);
            """),
            ("get_compact_data", "METH_O",
            """
                char * val = _PyUnicode_COMPACT_DATA(args);
                int len = PyUnicode_GET_LENGTH(args);
                return PyUnicode_FromStringAndSize(val, len);
            """),
            ])
        assert module.is_compact_ascii('abc')
        assert not module.is_compact_ascii(u'000\x80')
        assert module.get_compact_data('abc') == 'abc'

    def test_subclass(self):
        module = self.import_extension('gcc', [
            ('is_ascii', "METH_O",
             '''
                if (!PyUnicode_Check(args)) {
                    Py_RETURN_FALSE;
                }
                if (PyUnicode_IS_ASCII(args)) {
                    Py_RETURN_TRUE;
                }
                Py_RETURN_FALSE;
             '''),
            ('is_compact', "METH_O",
             '''
                if (!PyUnicode_Check(args)) {
                    Py_RETURN_FALSE;
                }
                if (PyUnicode_IS_COMPACT(args)) {
                    Py_RETURN_TRUE;
                }
                Py_RETURN_FALSE;
             '''),
            ], prologue="""
                #include <Python.h>
                PyTypeObject PyUnicodeSubtype = {
                    PyVarObject_HEAD_INIT(NULL, 0)
                    "foo.unicode_",               /* tp_name*/
                    sizeof(PyUnicodeObject),      /* tp_basicsize*/
                    0                             /* tp_itemsize */
                    };

            """, more_init = '''
                PyUnicodeSubtype.tp_alloc = NULL;
                PyUnicodeSubtype.tp_free = NULL;

                PyUnicodeSubtype.tp_flags = Py_TPFLAGS_DEFAULT|Py_TPFLAGS_BASETYPE;
                PyUnicodeSubtype.tp_itemsize = sizeof(char);
                PyUnicodeSubtype.tp_base = &PyUnicode_Type;
                if (PyType_Ready(&PyUnicodeSubtype) < 0) INITERROR;
                PyModule_AddObject(mod, "subtype",
                                   (PyObject *)&PyUnicodeSubtype); 
            ''')

        a = module.subtype('abc')
        assert module.is_ascii(a) is True
        assert module.is_compact(a) is False

 
class TestUnicode(BaseApiTest):
    def test_unicodeobject(self, space):
        encoding = rffi.charp2str(PyUnicode_GetDefaultEncoding(space, ))
        w_default_encoding = space.call_function(
            space.sys.get('getdefaultencoding')
        )
        assert encoding == space.unwrap(w_default_encoding)

    def test_AS(self, space):
        word = space.wrap(u'spam')
        array = rffi.cast(rffi.CWCHARP, PyUnicode_AsUnicode(space, word))
        array2 = PyUnicode_AsUnicode(space, word)
        for (i, char) in enumerate(space.utf8_w(word)):
            assert array[i] == char
            assert array2[i] == char
        with raises_w(space, TypeError):
            PyUnicode_AsUnicode(space, space.newbytes('spam'))

        utf_8 = rffi.str2charp('utf-8')
        encoded = PyUnicode_AsEncodedString(space, space.wrap(u'späm'),
                                                utf_8, None)
        assert space.unwrap(encoded) == 'sp\xc3\xa4m'
        encoded_obj = PyUnicode_AsEncodedObject(space, space.wrap(u'späm'),
                                                utf_8, None)
        assert space.eq_w(encoded, encoded_obj)
        one = space.newint(1)
        with raises_w(space, TypeError):
            PyUnicode_AsEncodedString(
                space, space.newtuple([one, one, one]), None, None)
        with raises_w(space, TypeError):
            PyUnicode_AsEncodedString(space, space.newbytes(''), None, None)
        ascii = rffi.str2charp('ascii')
        replace = rffi.str2charp('replace')
        encoded = PyUnicode_AsEncodedString(space, space.wrap(u'späm'),
                                                ascii, replace)
        assert space.unwrap(encoded) == 'sp?m'
        rffi.free_charp(utf_8)
        rffi.free_charp(replace)
        rffi.free_charp(ascii)

        buf = rffi.unicode2wcharp(u"12345")
        PyUnicode_AsWideChar(space, space.wrap(u'longword'), buf, 5)
        assert rffi.wcharp2unicode(buf) == 'longw'
        PyUnicode_AsWideChar(space, space.wrap(u'a'), buf, 5)
        assert rffi.wcharp2unicode(buf) == 'a'
        rffi.free_wcharp(buf)

    def test_fromstring(self, space):
        s = rffi.str2charp(u'sp\x09m'.encode("utf-8"))
        w_res = PyUnicode_FromString(space, s)
        assert space.utf8_w(w_res) == u'sp\x09m'.encode("utf-8")

        res = PyUnicode_FromStringAndSize(space, s, 4)
        w_res = from_ref(space, res)
        decref(space, res)
        assert space.utf8_w(w_res) == u'sp\x09m'.encode("utf-8")
        rffi.free_charp(s)

    def test_internfromstring(self, space):
        with rffi.scoped_str2charp('foo') as s:
            w_res = PyUnicode_InternFromString(space, s)
            assert space.unwrap(w_res) == u'foo'
            w_res2 = PyUnicode_InternFromString(space, s)
            assert w_res is w_res2

    def test_unicode_resize(self, space):
        py_uni = new_empty_unicode(space, 10)
        ar = lltype.malloc(PyObjectP.TO, 1, flavor='raw')
        buf = get_wbuffer(py_uni)
        buf[0] = u'a'
        buf[1] = u'b'
        buf[2] = u'c'
        ar[0] = rffi.cast(PyObject, py_uni)
        PyUnicode_Resize(space, ar, 3)
        py_uni = rffi.cast(PyUnicodeObject, ar[0])
        assert get_wsize(py_uni) == 3
        assert get_wbuffer(py_uni)[1] == u'b'
        assert get_wbuffer(py_uni)[3] == u'\x00'
        # the same for growing
        ar[0] = rffi.cast(PyObject, py_uni)
        PyUnicode_Resize(space, ar, 10)
        py_uni = rffi.cast(PyUnicodeObject, ar[0])
        assert get_wsize(py_uni) == 10
        assert get_wbuffer(py_uni)[1] == 'b'
        assert get_wbuffer(py_uni)[10] == '\x00'
        decref(space, ar[0])
        lltype.free(ar, flavor='raw')

    def test_AsUTF8String(self, space):
        w_u = space.wrap(u'sp\x09m\u1234')
        w_res = PyUnicode_AsUTF8String(space, w_u)
        assert space.type(w_res) is space.w_bytes
        assert space.unwrap(w_res) == 'sp\tm\xe1\x88\xb4'

    def test_AsUTF16String(self, space):
        u = u'sp\x09m\u1234\U00012345'
        w_u = space.wrap(u)
        w_res = PyUnicode_AsUTF16String(space, w_u)
        assert space.type(w_res) is space.w_bytes
        assert space.unwrap(w_res) == u.encode('utf-16')

    def test_AsUTF32String(self, space):
        u = u'sp\x09m\u1234\U00012345'
        w_u = space.wrap(u)
        w_res = PyUnicode_AsUTF32String(space, w_u)
        assert space.type(w_res) is space.w_bytes
        assert space.unwrap(w_res) == u.encode('utf-32')

    def test_decode_utf8(self, space):
        u = rffi.str2charp(u'sp\x134m'.encode("utf-8"))
        w_u = PyUnicode_DecodeUTF8(space, u, 5, None)
        assert space.type(w_u) is space.w_unicode
        assert space.utf8_w(w_u) == u'sp\x134m'.encode("utf-8")

        w_u = PyUnicode_DecodeUTF8(space, u, 2, None)
        assert space.type(w_u) is space.w_unicode
        assert space.utf8_w(w_u) == 'sp'
        rffi.free_charp(u)

    def test_encode_utf8(self, space):
        u = rffi.unicode2wcharp(u'sp\x09m')
        w_b = PyUnicode_EncodeUTF8(space, u, 4, None)
        assert space.type(w_b) is space.w_bytes
        assert space.bytes_w(w_b) == u'sp\x09m'.encode('utf-8')
        rffi.free_wcharp(u)

    def test_encode_decimal(self, space):
        with rffi.scoped_unicode2wcharp(u' (12, 35 ABC)') as u:
            with rffi.scoped_alloc_buffer(20) as buf:
                res = PyUnicode_EncodeDecimal(space, u, 13, buf.raw, None)
                s = rffi.charp2str(buf.raw)
        assert res == 0
        assert s == ' (12, 35 ABC)'

        with rffi.scoped_unicode2wcharp(u' (12, \u1234\u1235)') as u:
            with rffi.scoped_alloc_buffer(20) as buf:
                with pytest.raises(OperationError):
                    PyUnicode_EncodeDecimal(space, u, 9, buf.raw, None)

        with rffi.scoped_unicode2wcharp(u' (12, \u1234\u1235)') as u:
            with rffi.scoped_alloc_buffer(20) as buf:
                with rffi.scoped_str2charp("replace") as errors:
                    res = PyUnicode_EncodeDecimal(space, u, 9, buf.raw,
                                                      errors)
                s = rffi.charp2str(buf.raw)
        assert res == 0
        assert s == " (12, ??)"

        with rffi.scoped_unicode2wcharp(u'12\u1234') as u:
            with rffi.scoped_alloc_buffer(20) as buf:
                with rffi.scoped_str2charp("xmlcharrefreplace") as errors:
                    res = PyUnicode_EncodeDecimal(space, u, 3, buf.raw,
                                                      errors)
                s = rffi.charp2str(buf.raw)
        assert res == 0
        assert s == "12&#4660;"

    def test_encode_fsdefault(self, space):
        w_u = space.wrap(u'späm')
        try:
            w_s = PyUnicode_EncodeFSDefault(space, w_u)
        except (OperationError, UnicodeEncodeError):
            py.test.skip("Requires a unicode-aware fsencoding")
        with rffi.scoped_str2charp(space.bytes_w(w_s)) as encoded:
            w_decoded = PyUnicode_DecodeFSDefaultAndSize(space, encoded, space.len_w(w_s))
            assert space.eq_w(w_decoded, w_u)
            w_decoded = PyUnicode_DecodeFSDefault(space, encoded)
            assert space.eq_w(w_decoded, w_u)

    def test_fsconverter(self, space):
        # Input is bytes
        w_input = space.newbytes("test")
        with lltype.scoped_alloc(PyObjectP.TO, 1) as result:
            # Decoder
            ret = PyUnicode_FSDecoder(space, w_input, result)
            assert ret == Py_CLEANUP_SUPPORTED
            assert space.isinstance_w(from_ref(space, result[0]), space.w_unicode)
            assert PyUnicode_FSDecoder(space, None, result) == 1
            # Converter
            ret = PyUnicode_FSConverter(space, w_input, result)
            assert ret == Py_CLEANUP_SUPPORTED
            assert space.eq_w(from_ref(space, result[0]), w_input)
            assert PyUnicode_FSDecoder(space, None, result) == 1
        # Input is unicode
        w_input = space.wrap("test")
        with lltype.scoped_alloc(PyObjectP.TO, 1) as result:
            # Decoder
            ret = PyUnicode_FSDecoder(space, w_input, result)
            assert ret == Py_CLEANUP_SUPPORTED
            assert space.eq_w(from_ref(space, result[0]), w_input)
            assert PyUnicode_FSDecoder(space, None, result) == 1
            # Converter
            ret = PyUnicode_FSConverter(space, w_input, result)
            assert ret == Py_CLEANUP_SUPPORTED
            assert space.isinstance_w(from_ref(space, result[0]), space.w_bytes)
            assert PyUnicode_FSDecoder(space, None, result) == 1
        # Input is invalid
        w_input = space.newint(42)
        with lltype.scoped_alloc(PyObjectP.TO, 1) as result:
            with pytest.raises(OperationError):
                PyUnicode_FSConverter(space, w_input, result)


    def test_locale(self, space):
        # Input is char *
        with rffi.scoped_str2charp('test') as test:
            with rffi.scoped_str2charp('strict') as errors:
                w_ret = PyUnicode_DecodeLocale(space, test, errors)
                assert space.utf8_w(w_ret) == 'test'
            with rffi.scoped_str2charp('surrogateescape') as errors:
                w_ret = PyUnicode_DecodeLocale(space, test, errors)
                assert space.utf8_w(w_ret) == 'test'

        # Input is w_unicode
        w_input = space.newtext("test", 4)
        with rffi.scoped_str2charp('strict') as errors:
            w_ret = PyUnicode_EncodeLocale(space, w_input, errors)
            assert space.utf8_w(w_ret) == 'test'
        with rffi.scoped_str2charp(None) as errors:
            w_ret = PyUnicode_EncodeLocale(space, w_input, errors)
            assert space.utf8_w(w_ret) == 'test'
        with rffi.scoped_str2charp('surrogateescape') as errors:
            w_ret = PyUnicode_EncodeLocale(space, w_input, errors)
            assert space.utf8_w(w_ret) == 'test'
        # 'errors' is invalid
        with rffi.scoped_str2charp('something else') as errors:
            with pytest.raises(OperationError):
                PyUnicode_EncodeLocale(space, w_input, errors)


    def test_IS(self, space):
        for char in [0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x1c, 0x1d, 0x1e, 0x1f,
                     0x20, 0x85, 0xa0, 0x1680, 0x2000, 0x2001, 0x2002,
                     0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008,
                     0x2009, 0x200a,
                     #0x200b is in Other_Default_Ignorable_Code_Point in 4.1.0
                     0x2028, 0x2029, 0x202f, 0x205f, 0x3000]:
            assert Py_UNICODE_ISSPACE(space, unichr(char))
        assert not Py_UNICODE_ISSPACE(space, u'a')

        assert Py_UNICODE_ISALPHA(space, u'a')
        assert not Py_UNICODE_ISALPHA(space, u'0')
        assert Py_UNICODE_ISALNUM(space, u'a')
        assert Py_UNICODE_ISALNUM(space, u'0')
        assert not Py_UNICODE_ISALNUM(space, u'+')

        assert Py_UNICODE_ISDECIMAL(space, u'\u0660')
        assert not Py_UNICODE_ISDECIMAL(space, u'a')
        assert Py_UNICODE_ISDIGIT(space, u'9')
        assert not Py_UNICODE_ISDIGIT(space, u'@')
        assert Py_UNICODE_ISNUMERIC(space, u'9')
        assert not Py_UNICODE_ISNUMERIC(space, u'@')

        for char in [0x0a, 0x0d, 0x1c, 0x1d, 0x1e, 0x85, 0x2028, 0x2029]:
            assert Py_UNICODE_ISLINEBREAK(space, unichr(char))

        assert Py_UNICODE_ISLOWER(space, u'\xdf') # sharp s
        assert Py_UNICODE_ISUPPER(space, u'\xde') # capital thorn
        assert Py_UNICODE_ISLOWER(space, u'a')
        assert not Py_UNICODE_ISUPPER(space, u'a')
        assert not Py_UNICODE_ISTITLE(space, u'\xce')
        assert Py_UNICODE_ISTITLE(space,
            u'\N{LATIN CAPITAL LETTER L WITH SMALL LETTER J}')

    def test_TOLOWER(self, space):
        assert Py_UNICODE_TOLOWER(space, u'�') == u'�'
        assert Py_UNICODE_TOLOWER(space, u'�') == u'�'

    def test_TOUPPER(self, space):
        assert Py_UNICODE_TOUPPER(space, u'�') == u'�'
        assert Py_UNICODE_TOUPPER(space, u'�') == u'�'

    def test_TOTITLE(self, space):
        assert Py_UNICODE_TOTITLE(space, u'/') == u'/'
        assert Py_UNICODE_TOTITLE(space, u'�') == u'�'
        assert Py_UNICODE_TOTITLE(space, u'�') == u'�'

    def test_TODECIMAL(self, space):
        assert Py_UNICODE_TODECIMAL(space, u'6') == 6
        assert Py_UNICODE_TODECIMAL(space, u'A') == -1

    def test_TODIGIT(self, space):
        assert Py_UNICODE_TODIGIT(space, u'6') == 6
        assert Py_UNICODE_TODIGIT(space, u'A') == -1

    def test_TONUMERIC(self, space):
        assert Py_UNICODE_TONUMERIC(space, u'6') == 6.0
        assert Py_UNICODE_TONUMERIC(space, u'A') == -1.0
        assert Py_UNICODE_TONUMERIC(space, u'\N{VULGAR FRACTION ONE HALF}') == .5

    def test_transform_decimal(self, space):
        def transform_decimal(s):
            with rffi.scoped_unicode2wcharp(s) as u:
                return space.unwrap(
                    PyUnicode_TransformDecimalToASCII(space, u, len(s)))
        assert isinstance(transform_decimal(u'123'), unicode)
        assert transform_decimal(u'123') == u'123'
        assert transform_decimal(u'\u0663.\u0661\u0664') == u'3.14'
        assert transform_decimal(u"\N{EM SPACE}3.14\N{EN SPACE}") == (
            u"\N{EM SPACE}3.14\N{EN SPACE}")
        assert transform_decimal(u'123\u20ac') == u'123\u20ac'

    def test_fromobject(self, space):
        w_u = space.wrap(u'a')
        assert PyUnicode_FromObject(space, w_u) is w_u
        with raises_w(space, TypeError):
            PyUnicode_FromObject(space, space.newbytes('test'))
        with raises_w(space, TypeError):
            PyUnicode_FromObject(space, space.newint(42))


    def test_decode(self, space):
        b_text = rffi.str2charp('caf\x82xx')
        b_encoding = rffi.str2charp('cp437')
        b_errors = rffi.str2charp('strict')
        assert space.text_w(PyUnicode_Decode(
            space, b_text, 4, b_encoding, b_errors)).decode('utf8') == u'caf\xe9'
        assert (space.text_w(
            PyUnicode_Decode(space, b_text, 4, b_encoding, None)) ==
            u'caf\xe9'.encode("utf-8"))

        w_text = PyUnicode_FromEncodedObject(space, space.newbytes("test"), b_encoding, None)
        assert space.isinstance_w(w_text, space.w_unicode)
        assert space.utf8_w(w_text) == "test"

        with raises_w(space, TypeError):
            PyUnicode_FromEncodedObject(space, space.wrap(u"test"),
                                        b_encoding, None)
        with raises_w(space, TypeError):
            PyUnicode_FromEncodedObject(space, space.wrap(1), b_encoding, None)

        rffi.free_charp(b_text)
        rffi.free_charp(b_encoding)

    def test_decode_null_encoding(self, space):
        null_charp = lltype.nullptr(rffi.CCHARP.TO)
        u_text = u'abcdefg'
        s_text = space.bytes_w(PyUnicode_AsEncodedString(space, space.wrap(u_text), null_charp, null_charp))
        b_text = rffi.str2charp(s_text)
        assert (space.utf8_w(PyUnicode_Decode(
            space, b_text, len(s_text), null_charp, null_charp)) ==
            u_text.encode("utf-8"))
        with raises_w(space, TypeError):
            PyUnicode_FromEncodedObject(
                space, space.wrap(u_text), null_charp, None)
        assert space.text_w(PyUnicode_FromEncodedObject(
            space, space.newbytes(s_text), null_charp, None)) == u_text
        rffi.free_charp(b_text)

    def test_mbcs(self, space):
        if sys.platform != 'win32':
            py.test.skip("mcbs encoding only exists on Windows")
        # unfortunately, mbcs is locale-dependent.
        # This tests works at least on a Western Windows.
        unichars = u"abc" + unichr(12345)
        wbuf = rffi.unicode2wcharp(unichars)
        w_bytes = PyUnicode_EncodeMBCS(space, wbuf, 4, None)
        rffi.free_wcharp(wbuf)
        assert space.type(w_bytes) is space.w_bytes
        assert space.utf8_w(w_bytes) == "abc?"

    def test_escape(self, space):
        def test(ustr):
            w_ustr = space.wrap(ustr.decode('Unicode-Escape'))
            result = PyUnicode_AsUnicodeEscapeString(space, w_ustr)
            assert space.eq_w(space.newbytes(ustr), result)

        test('\\u674f\\u7f8e')
        test('\\u0105\\u0107\\u017c\\u017a')
        test('El Ni\\xf1o')

    def test_ascii(self, space):
        ustr = "abcdef"
        w_ustr = space.wrap(ustr.decode("ascii"))
        result = PyUnicode_AsASCIIString(space, w_ustr)
        assert space.eq_w(space.newbytes(ustr), result)
        with raises_w(space, UnicodeEncodeError):
            PyUnicode_AsASCIIString(space, space.wrap(u"abcd\xe9f"))

    def test_decode_utf16(self, space):
        def test(encoded, endian, realendian=None):
            encoded_charp = rffi.str2charp(encoded)
            strict_charp = rffi.str2charp("strict")
            if endian is not None:
                if endian < 0:
                    value = -1
                elif endian > 0:
                    value = 1
                else:
                    value = 0
                pendian = lltype.malloc(INTP_real.TO, 1, flavor='raw')
                pendian[0] = rffi.cast(rffi.INT_real, value)
            else:
                pendian = None

            w_ustr = PyUnicode_DecodeUTF16(space, encoded_charp, len(encoded), strict_charp, pendian)
            assert space.eq_w(space.call_method(w_ustr, 'encode', space.wrap('ascii')),
                              space.newbytes("abcd"))

            rffi.free_charp(encoded_charp)
            rffi.free_charp(strict_charp)
            if pendian:
                if realendian is not None:
                    assert rffi.cast(rffi.INT_real, realendian) == pendian[0]
                lltype.free(pendian, flavor='raw')

        test("\x61\x00\x62\x00\x63\x00\x64\x00", -1)
        if sys.byteorder == 'big':
            test("\x00\x61\x00\x62\x00\x63\x00\x64", None)
        else:
            test("\x61\x00\x62\x00\x63\x00\x64\x00", None)
        test("\x00\x61\x00\x62\x00\x63\x00\x64", 1)
        test("\xFE\xFF\x00\x61\x00\x62\x00\x63\x00\x64", 0, 1)
        test("\xFF\xFE\x61\x00\x62\x00\x63\x00\x64\x00", 0, -1)

    def test_decode_utf32(self, space):
        def test(encoded, endian, realendian=None):
            encoded_charp = rffi.str2charp(encoded)
            strict_charp = rffi.str2charp("strict")
            if endian is not None:
                if endian < 0:
                    value = -1
                elif endian > 0:
                    value = 1
                else:
                    value = 0
                pendian = lltype.malloc(INTP_real.TO, 1, flavor='raw')
                pendian[0] = rffi.cast(rffi.INT_real, value)
            else:
                pendian = None

            w_ustr = PyUnicode_DecodeUTF32(space, encoded_charp, len(encoded),
                                           strict_charp, pendian)
            assert space.eq_w(space.call_method(w_ustr, 'encode', space.wrap('ascii')),
                              space.newbytes("ab"))

            rffi.free_charp(encoded_charp)
            rffi.free_charp(strict_charp)
            if pendian:
                if realendian is not None:
                    assert rffi.cast(rffi.INT, realendian) == pendian[0]
                lltype.free(pendian, flavor='raw')

        test("\x61\x00\x00\x00\x62\x00\x00\x00", -1)

        if sys.byteorder == 'big':
            test("\x00\x00\x00\x61\x00\x00\x00\x62", None)
        else:
            test("\x61\x00\x00\x00\x62\x00\x00\x00", None)

        test("\x00\x00\x00\x61\x00\x00\x00\x62", 1)

        test("\x00\x00\xFE\xFF\x00\x00\x00\x61\x00\x00\x00\x62", 0, 1)
        test("\xFF\xFE\x00\x00\x61\x00\x00\x00\x62\x00\x00\x00", 0, -1)

    def test_compare(self, space):
        assert PyUnicode_Compare(space, space.wrap('a'), space.wrap('b')) == -1

    def test_concat(self, space):
        w_res = PyUnicode_Concat(space, space.wrap(u'a'), space.wrap(u'b'))
        assert space.utf8_w(w_res) == 'ab'

    def test_copy(self, space):
        w_x = space.wrap(u"abcd\u0660")
        count1 = space.int_w(space.len(w_x))
        target_chunk = lltype.malloc(rffi.CWCHARP.TO, count1, flavor='raw')

        x_chunk = PyUnicode_AsUnicode(space, w_x)
        Py_UNICODE_COPY(space, target_chunk, x_chunk, 4)
        w_y = space.wrap(rffi.wcharpsize2unicode(target_chunk, 4))

        assert space.eq_w(w_y, space.wrap(u"abcd"))

        size = get_wsize(as_pyobj(space, w_x))
        Py_UNICODE_COPY(space, target_chunk, x_chunk, size)
        w_y = space.wrap(rffi.wcharpsize2unicode(target_chunk, size))

        assert space.eq_w(w_y, w_x)

        lltype.free(target_chunk, flavor='raw')

    def test_ascii_codec(self, space):
        s = 'abcdefg'
        data = rffi.str2charp(s)
        NULL = lltype.nullptr(rffi.CCHARP.TO)
        w_u = PyUnicode_DecodeASCII(space, data, len(s), NULL)
        assert space.eq_w(w_u, space.wrap(u"abcdefg"))
        rffi.free_charp(data)

        s = 'abcd\xFF'
        data = rffi.str2charp(s)
        with raises_w(space, UnicodeDecodeError):
            PyUnicode_DecodeASCII(space, data, len(s), NULL)
        rffi.free_charp(data)

        uni = u'abcdefg'
        data = rffi.unicode2wcharp(uni)
        w_s = PyUnicode_EncodeASCII(space, data, len(uni), NULL)
        assert space.eq_w(space.newbytes("abcdefg"), w_s)
        rffi.free_wcharp(data)

        u = u'�bcd�fg'
        data = rffi.unicode2wcharp(u)
        with raises_w(space, UnicodeEncodeError):
            PyUnicode_EncodeASCII(space, data, len(u), NULL)
        rffi.free_wcharp(data)

    def test_latin1(self, space):
        s = 'abcdefg'
        data = rffi.str2charp(s)
        w_u = PyUnicode_DecodeLatin1(space, data, len(s),
                                     lltype.nullptr(rffi.CCHARP.TO))
        assert space.eq_w(w_u, space.wrap(u"abcdefg"))
        rffi.free_charp(data)

        uni = u'abcdefg'
        data = rffi.unicode2wcharp(uni)
        w_s = PyUnicode_EncodeLatin1(space, data, len(uni),
                                     lltype.nullptr(rffi.CCHARP.TO))
        assert space.eq_w(space.newbytes("abcdefg"), w_s)
        rffi.free_wcharp(data)

        ustr = "abcdef"
        w_ustr = space.wrap(ustr.decode("ascii"))
        result = PyUnicode_AsLatin1String(space, w_ustr)
        assert space.eq_w(space.newbytes(ustr), result)

    def test_format(self, space):
        w_format = space.wrap(u'hi %s')
        w_args = space.wrap((u'test',))
        w_formated = PyUnicode_Format(space, w_format, w_args)
        assert (space.utf8_w(w_formated) ==
                space.utf8_w(space.mod(w_format, w_args)))

    def test_join(self, space):
        w_sep = space.wrap(u'<sep>')
        w_seq = space.wrap([u'a', u'b'])
        w_joined = PyUnicode_Join(space, w_sep, w_seq)
        assert space.utf8_w(w_joined) == u'a<sep>b'.encode("utf-8")

    def test_fromordinal(self, space):
        w_char = PyUnicode_FromOrdinal(space, 65)
        assert space.utf8_w(w_char) == u'A'
        w_char = PyUnicode_FromOrdinal(space, 0)
        assert space.utf8_w(w_char) == u'\0'
        w_char = PyUnicode_FromOrdinal(space, 0xFFFF)
        assert space.utf8_w(w_char) == u'\uFFFF'.encode('utf-8')

    def test_replace(self, space):
        w_str = space.wrap(u"abababab")
        w_substr = space.wrap(u"a")
        w_replstr = space.wrap(u"z")
        assert u"zbzbabab" == space.utf8_w(
            PyUnicode_Replace(space, w_str, w_substr, w_replstr, 2))
        assert u"zbzbzbzb" == space.utf8_w(
            PyUnicode_Replace(space, w_str, w_substr, w_replstr, -1))

    def test_tailmatch(self, space):
        w_str = space.wrap(u"abcdef")
        # prefix match
        assert PyUnicode_Tailmatch(space, w_str, space.wrap("cde"), 2, 9, -1) == 1
        assert PyUnicode_Tailmatch(space, w_str, space.wrap("cde"), 2, 4, -1) == 0 # ends at 'd'
        assert PyUnicode_Tailmatch(space, w_str, space.wrap("cde"), 1, 6, -1) == 0 # starts at 'b'
        assert PyUnicode_Tailmatch(space, w_str, space.wrap("cdf"), 2, 6, -1) == 0
        # suffix match
        assert PyUnicode_Tailmatch(space, w_str, space.wrap("cde"), 1, 5,  1) == 1
        assert PyUnicode_Tailmatch(space, w_str, space.wrap("cde"), 3, 5,  1) == 0 # starts at 'd'
        assert PyUnicode_Tailmatch(space, w_str, space.wrap("cde"), 1, 6,  1) == 0 # ends at 'f'
        assert PyUnicode_Tailmatch(space, w_str, space.wrap("bde"), 1, 5,  1) == 0
        # type checks
        with raises_w(space, TypeError):
            PyUnicode_Tailmatch(space, w_str, space.wrap(3), 2, 10, 1)
        with raises_w(space, TypeError):
            PyUnicode_Tailmatch(
                space, space.wrap(3), space.wrap("abc"), 2, 10, 1)

    def test_count(self, space):
        w_str = space.wrap(u"abcabdab")
        assert PyUnicode_Count(space, w_str, space.wrap(u"ab"), 0, -1) == 2
        assert PyUnicode_Count(space, w_str, space.wrap(u"ab"), 0, 2) == 1
        assert PyUnicode_Count(space, w_str, space.wrap(u"ab"), -5, 30) == 2

    def test_find(self, space):
        w_str = space.wrap(u"abcabcd")
        assert PyUnicode_Find(space, w_str, space.wrap(u"c"), 0, 7, 1) == 2
        assert PyUnicode_Find(space, w_str, space.wrap(u"c"), 3, 7, 1) == 5
        assert PyUnicode_Find(space, w_str, space.wrap(u"c"), 0, 7, -1) == 5
        assert PyUnicode_Find(space, w_str, space.wrap(u"c"), 3, 7, -1) == 5
        assert PyUnicode_Find(space, w_str, space.wrap(u"c"), 0, 4, -1) == 2
        assert PyUnicode_Find(space, w_str, space.wrap(u"z"), 0, 4, -1) == -1

    def test_split(self, space):
        w_str = space.wrap(u"a\nb\nc\nd")
        assert "['a', 'b', 'c', 'd']" == space.unwrap(space.repr(
                PyUnicode_Split(space, w_str, space.wrap('\n'), -1)))
        assert r"['a', 'b', 'c\nd']" == space.unwrap(space.repr(
                PyUnicode_Split(space, w_str, space.wrap('\n'), 2)))
        assert r"['a', 'b', 'c d']" == space.unwrap(space.repr(
                PyUnicode_Split(space, space.wrap(u'a\nb  c d'), None, 2)))
        assert "['a', 'b', 'c', 'd']" == space.unwrap(space.repr(
                PyUnicode_Splitlines(space, w_str, 0)))
        assert r"['a\n', 'b\n', 'c\n', 'd']" == space.unwrap(space.repr(
                PyUnicode_Splitlines(space, w_str, 1)))

    def test_substring_api(self, space):
        w_str = space.wrap(u"abcd")
        assert space.unwrap(PyUnicode_Substring(space, w_str, 1, 3)) == u"bc"
        assert space.unwrap(PyUnicode_Substring(space, w_str, 0, 4)) == u"abcd"
        assert space.unwrap(PyUnicode_Substring(space, w_str, 0, 9)) == u"abcd"
        assert space.unwrap(PyUnicode_Substring(space, w_str, 1, 4)) == u"bcd"
        assert space.unwrap(PyUnicode_Substring(space, w_str, 2, 2)) == u""
        assert space.unwrap(PyUnicode_Substring(space, w_str, 5, 4)) == u""
        assert space.unwrap(PyUnicode_Substring(space, w_str, 5, 3)) == u""
        assert space.unwrap(PyUnicode_Substring(space, w_str, 4, 3)) == u""

    def test_Ready(self, space):
        def as_py_uni(val):
            py_obj = new_empty_unicode(space, len(val))
            w_obj = space.wrap(val)
            # calls _PyUnicode_Ready
            unicode_attach(space, py_obj, w_obj)
            return py_obj

        py_str = as_py_uni(u'abc')  # ASCII
        assert get_kind(py_str) == 1
        assert get_ascii(py_str) == 1

        py_str = as_py_uni(u'café')  # latin1
        assert get_kind(py_str) == 1
        assert get_ascii(py_str) == 0

        py_str = as_py_uni(u'Росси́я')  # UCS2
        assert get_kind(py_str) == 2
        assert get_ascii(py_str) == 0

        py_str = as_py_uni(u'***\U0001f4a9***')  # UCS4
        assert get_kind(py_str) == 4
        assert get_ascii(py_str) == 0

    def test_as_ucs4(self, space):
        w_x = space.wrap(u"ab\u0660")
        count1 = space.int_w(space.len(w_x))
        x_chunk = PyUnicode_AsUCS4Copy(space, w_x)
        assert x_chunk[0] == ord('a')
        assert x_chunk[1] == ord('b')
        assert x_chunk[2] == 0x0660
        assert x_chunk[3] == 0
        Py_UCS4 = lltype.typeOf(x_chunk).TO.OF
        lltype.free(x_chunk, flavor='raw', track_allocation=False)

        target_chunk = lltype.malloc(rffi.CArray(Py_UCS4), 4, flavor='raw')
        target_chunk[3] = rffi.cast(Py_UCS4, 99999)
        x_chunk = PyUnicode_AsUCS4(space, w_x, target_chunk, 3, 0)
        assert x_chunk == target_chunk
        assert x_chunk[0] == ord('a')
        assert x_chunk[1] == ord('b')
        assert x_chunk[2] == 0x0660
        assert x_chunk[3] == 99999

        x_chunk[2] = rffi.cast(Py_UCS4, 77777)
        x_chunk = PyUnicode_AsUCS4(space, w_x, target_chunk, 4, 1)
        assert x_chunk == target_chunk
        assert x_chunk[0] == ord('a')
        assert x_chunk[1] == ord('b')
        assert x_chunk[2] == 0x0660
        assert x_chunk[3] == 0
        lltype.free(target_chunk, flavor='raw')

    def test_wide_as_ucs4(self, space):
        w_x = space.wrap(u'\U00100900')
        x_chunk = PyUnicode_AsUCS4Copy(space, w_x)
        assert x_chunk[0] == 0x00100900
        Py_UCS4 = lltype.typeOf(x_chunk).TO.OF
        lltype.free(x_chunk, flavor='raw', track_allocation=False)

        target_chunk = lltype.malloc(rffi.CArray(Py_UCS4), 1, flavor='raw')
        x_chunk = PyUnicode_AsUCS4(space, w_x, target_chunk, 1, 0)
        assert x_chunk == target_chunk
        assert x_chunk[0] == 0x00100900
        lltype.free(target_chunk, flavor='raw')
