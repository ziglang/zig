
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase

class AppTestGetargs(AppTestCpythonExtensionBase):
    def w_import_parser(self, implementation, argstyle='METH_VARARGS',
                        PY_SSIZE_T_CLEAN=False):
        mod = self.import_extension(
            'modname', [('funcname', argstyle, implementation)],
            PY_SSIZE_T_CLEAN=PY_SSIZE_T_CLEAN)
        return mod.funcname

    def test_pyarg_parse_int(self):
        """
        The `i` format specifier can be used to parse an integer.
        """
        oneargint = self.import_parser(
            '''
            int l;
            if (!PyArg_ParseTuple(args, "i", &l)) {
                return NULL;
            }
            return PyLong_FromLong(l);
            ''')
        assert oneargint(1) == 1
        raises(TypeError, oneargint, None)
        raises(TypeError, oneargint)


    def test_pyarg_parse_fromname(self):
        """
        The name of the function parsing the arguments can be given after a `:`
        in the argument format string.
        """
        oneargandform = self.import_parser(
            '''
            int l;
            if (!PyArg_ParseTuple(args, "i:oneargandstuff", &l)) {
                return NULL;
            }
            return PyLong_FromLong(l);
            ''')
        assert oneargandform(1) == 1


    def test_pyarg_parse_object(self):
        """
        The `O` format specifier can be used to parse an arbitrary object.
        """
        oneargobject = self.import_parser(
            '''
            PyObject *obj;
            if (!PyArg_ParseTuple(args, "O", &obj)) {
                return NULL;
            }
            Py_INCREF(obj);
            return obj;
            ''')
        sentinel = object()
        res = oneargobject(sentinel)
        assert res is sentinel

    def test_pyarg_parse_restricted_object_type(self):
        """
        The `O!` format specifier can be used to parse an object of a particular
        type.
        """
        oneargobjectandlisttype = self.import_parser(
            '''
            PyObject *obj;
            if (!PyArg_ParseTuple(args, "O!", &PyList_Type, &obj)) {
                return NULL;
            }
            Py_INCREF(obj);
            return obj;
            ''')
        sentinel = object()
        raises(TypeError, "oneargobjectandlisttype(sentinel)")
        sentinel = []
        res = oneargobjectandlisttype(sentinel)
        assert res is sentinel


    def test_pyarg_parse_one_optional(self):
        """
        An object corresponding to a format specifier after a `|` in the
        argument format string is optional and may be passed or not.
        """
        twoopt = self.import_parser(
            '''
            PyObject *a;
            PyObject *b = NULL;
            if (!PyArg_ParseTuple(args, "O|O", &a, &b)) {
                return NULL;
            }
            if (b)
                Py_INCREF(b);
            else
                b = PyLong_FromLong(42);
            /* return an owned reference */
            return b;
            ''')
        assert twoopt(1) == 42
        assert twoopt(1, 2) == 2
        raises(TypeError, twoopt, 1, 2, 3)


    def test_pyarg_parse_string_py_buffer(self):
        """
        The `s*` format specifier can be used to parse a str into a Py_buffer
        structure containing a pointer to the string data and the length of the
        string data.
        """
        pybuffer = self.import_parser(
            '''
            Py_buffer buf;
            PyObject *result;
            if (!PyArg_ParseTuple(args, "s*", &buf)) {
                return NULL;
            }
            result = PyBytes_FromStringAndSize(buf.buf, buf.len);
            PyBuffer_Release(&buf);
            return result;
            ''')
        assert b'foo\0bar\0baz' == pybuffer(b'foo\0bar\0baz')
        #return  # XXX?
        assert b'foo\0bar\0baz' == pybuffer(bytearray(b'foo\0bar\0baz'))


    def test_pyarg_parse_string_fails(self):
        """
        Test the failing case of PyArg_ParseTuple(): it must not keep
        a reference on the PyObject passed in.
        """
        pybuffer = self.import_parser(
            '''
            Py_buffer buf1, buf2, buf3;
            if (!PyArg_ParseTuple(args, "s*s*s*", &buf1, &buf2, &buf3)) {
                return NULL;
            }
            Py_FatalError("should not get there");
            return NULL;
            ''')
        freed = []
        class freestring(bytes):
            def __del__(self):
                freed.append('x')
        raises(TypeError, pybuffer,
               freestring(b"string"), freestring(b"other string"), 42)
        self.debug_collect()    # gc.collect() is not enough in this test:
                                # we need to check and free the PyObject
                                # linked to the freestring object as well
        assert freed == ['x', 'x']


    def test_pyarg_parse_charbuf_and_length(self):
        """
        The `s#` format specifier can be used to parse a read-only 8-bit
        character buffer into a char* and int giving its length in bytes.
        """
        charbuf = self.import_parser(
            '''
            char *buf;
            int len;
            if (!PyArg_ParseTuple(args, "s#", &buf, &len)) {
                return NULL;
            }
            return PyBytes_FromStringAndSize(buf, len);
            ''')
        raises(TypeError, "charbuf(10)")
        assert b'foo\0bar\0baz' == charbuf(b'foo\0bar\0baz')

    def test_pyarg_parse_without_py_ssize_t(self):
        import sys
        charbuf = self.import_parser(
            '''
            char *buf;
            Py_ssize_t y = -1;
            if (!PyArg_ParseTuple(args, "s#", &buf, &y)) {
                return NULL;
            }
            return PyLong_FromSsize_t(y);
            ''')
        if sys.maxsize < 2**32:
            expected = 5
        elif sys.byteorder == 'little':
            expected = -0xfffffffb
        else:
            expected = 0x5ffffffff
        assert charbuf(b'12345') == expected

    def test_pyarg_parse_with_py_ssize_t(self):
        charbuf = self.import_parser(
            '''
            char *buf;
            Py_ssize_t y = -1;
            if (!PyArg_ParseTuple(args, "s#", &buf, &y)) {
                return NULL;
            }
            return PyLong_FromSsize_t(y);
            ''', PY_SSIZE_T_CLEAN=True)
        assert charbuf(b'12345') == 5

    def test_pyarg_parse_with_py_ssize_t_bytes(self):
        charbuf = self.import_parser(
            '''
            char *buf;
            Py_ssize_t len = -1;
            if (!PyArg_ParseTuple(args, "y#", &buf, &len)) {
                return NULL;
            }
            return PyBytes_FromStringAndSize(buf, len);
            ''', PY_SSIZE_T_CLEAN=True)
        assert type(charbuf(b'12345')) is bytes
        assert charbuf(b'12345') == b'12345'

    def test_getargs_keywords(self):
        # taken from lib-python/3/test_getargs2.py
        module = self.import_extension('foo', [
            ("getargs_keywords", "METH_KEYWORDS | METH_VARARGS",
            '''
            static char *keywords[] = {"arg1","arg2","arg3","arg4","arg5", NULL};
            static char *fmt="(ii)i|(i(ii))(iii)i";
            int int_args[10]={-1, -1, -1, -1, -1, -1, -1, -1, -1, -1};

            if (!PyArg_ParseTupleAndKeywords(args, kwargs, fmt, keywords,
                &int_args[0], &int_args[1], &int_args[2], &int_args[3],
                &int_args[4], &int_args[5], &int_args[6], &int_args[7],
                &int_args[8], &int_args[9]))
                return NULL;
            return Py_BuildValue("iiiiiiiiii",
                int_args[0], int_args[1], int_args[2], int_args[3], int_args[4],
                int_args[5], int_args[6], int_args[7], int_args[8], int_args[9]
                );
            ''')])
        raises(TypeError, module.getargs_keywords, (1,2), 3, (4,(5,6)), (7,8,9), **{'\uDC80': 10})

