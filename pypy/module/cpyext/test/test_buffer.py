from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase

class AppTestBuffer(AppTestCpythonExtensionBase):
    def test_AsWriteBuffer(self):
        import array
        module = self.import_extension('buffer', [
            ('write_buffer_len', 'METH_O',
             """
             void* buf;
             Py_ssize_t buf_len;
             if (PyObject_AsWriteBuffer(args, &buf, &buf_len) < 0) {
                //PyErr_SetString(PyExc_ValueError, "bad value");
                return NULL;
             }
             return PyLong_FromLong(buf_len);
             """)])
        assert module.write_buffer_len(bytearray(b'123')) == 3
        assert module.write_buffer_len(array.array('i', [1, 2, 3])) == 12
        #
        import _cffi_backend
        BChar = _cffi_backend.new_primitive_type("char")
        BCharPtr = _cffi_backend.new_pointer_type(BChar)
        BCharArray = _cffi_backend.new_array_type(BCharPtr, None)
        p = _cffi_backend.newp(BCharArray, b"abcde")
        bb = _cffi_backend.buffer(p)
        assert module.write_buffer_len(bb) == 6


class AppTestMmap(AppTestCpythonExtensionBase):
    def test_mmap_buffer(self):
        module = self.import_extension('mmap_buffer', [
            ('isbuffer', 'METH_O',
             """
             Py_buffer view;

             if (PyObject_GetBuffer(args, &view,
                    PyBUF_ANY_CONTIGUOUS|PyBUF_WRITABLE) != 0) {
                return NULL;
             }
             return PyLong_FromLong(1);
             """)])
        import os, mmap
        tmpname = os.path.join(self.udir, 'test_mmap_buffer')
        print(tmpname)
        with open(tmpname, 'w+b') as f:
            f.write(b'123')
            f.flush()
            m = mmap.mmap(f.fileno(), 3)
            assert module.isbuffer(m) == 1
