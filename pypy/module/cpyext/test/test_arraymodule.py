import pytest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.conftest import option

class AppTestArrayModule(AppTestCpythonExtensionBase):
    enable_leak_checking = True

    def test_basic(self):
        module = self.import_module(name='array')
        arr = module.array('i', [1,2,3])
        assert arr.typecode == 'i'
        assert arr.itemsize == 4
        assert arr[2] == 3
        assert len(arr.buffer_info()) == 2
        exc = raises(TypeError, module.array.append)
        errstr = str(exc.value)
        assert errstr.startswith("descriptor 'append' of")
        arr.append(4)
        assert arr.tolist() == [1, 2, 3, 4]
        assert len(arr) == 4

    def test_iter(self):
        module = self.import_module(name='array')
        arr = module.array('i', [1,2,3])
        sum = 0
        for i in arr:
            sum += i
        assert sum == 6

    def test_index(self):
        module = self.import_module(name='array')
        arr = module.array('i', [1, 2, 3, 4])
        assert arr[3] == 4
        raises(IndexError, arr.__getitem__, 10)
        del arr[2]
        assert arr.tolist() == [1, 2, 4]
        arr[2] = 99
        assert arr.tolist() == [1, 2, 99]

    def test_slice_get(self):
        module = self.import_module(name='array')
        arr = module.array('i', [1, 2, 3, 4])
        assert arr[:].tolist() == [1, 2, 3, 4]
        assert arr[1:].tolist() == [2, 3, 4]
        assert arr[:2].tolist() == [1, 2]
        assert arr[1:3].tolist() == [2, 3]

    def test_slice_object(self):
        module = self.import_module(name='array')
        arr = module.array('i', [1, 2, 3, 4])
        assert arr[slice(1, 3)].tolist() == [2,3]
        arr[slice(1, 3)] = module.array('i', [21, 22, 23])
        assert arr.tolist() == [1, 21, 22, 23, 4]
        del arr[slice(1, 3)]
        assert arr.tolist() == [1, 23, 4]
        raises(TypeError, 'arr[slice(1, 3)] = "abc"')

    def test_buffer(self):
        import sys
        module = self.import_module(name='array')
        arr = module.array('i', [1, 2, 3, 4])
        buf = memoryview(arr)
        exc = raises(TypeError, "buf[1] = 1")
        assert str(exc.value) == "cannot modify read-only memory"
        if sys.byteorder == 'big':
            expected = b'\0\0\0\x01\0\0\0\x02\0\0\0\x03\0\0\0\x04'
        else:
            expected = b'\x01\0\0\0\x02\0\0\0\x03\0\0\0\x04\0\0\0'
        assert bytes(buf) == expected
        # make sure memory_attach is called
        buf2 = module.passthrough(buf)
        assert str(buf2) == str(buf)

    def test_releasebuffer(self):
        module = self.import_module(name='array')
        arr = module.array('i', [1,2,3,4])
        assert module.get_releasebuffer_cnt() == 0
        module.create_and_release_buffer(arr)
        assert module.get_releasebuffer_cnt() == 1

    def test_Py_buffer(self):
        module = self.import_module(name='array')
        arr = module.array('i', [1,2,3,4])
        assert module.get_releasebuffer_cnt() == 0
        m = memoryview(arr)
        assert module.get_releasebuffer_cnt() == 0
        del m
        self.debug_collect()
        assert module.get_releasebuffer_cnt() == 1

    def test_0d_view(self):
        module = self.import_module(name='array')
        arr = module.array('B', b'\0\0\0\x01')
        buf = memoryview(arr).cast('i', shape=())
        assert bytes(buf) == b'\0\0\0\x01'
        assert buf.shape == ()
        assert buf.strides == ()

    def test_binop_mul_impl(self):
        # check that rmul is called
        module = self.import_module(name='array')
        arr = module.array('i', [2])
        res = [1, 2, 3] * arr
        assert res == [1, 2, 3, 1, 2, 3]

    @pytest.mark.xfail
    def test_subclass_dealloc(self):
        module = self.import_module(name='array')
        class Sub(module.array):
            pass

        arr = Sub('i', [2])
        module.readbuffer_as_string(arr)
        class A(object):
            pass
        assert not module.same_dealloc(arr, module.array('i', [2]))
        assert module.same_dealloc(arr, A())

    def test_string_buf(self):
        module = self.import_module(name='array')
        import sys
        arr = module.array('u', '123')
        view = memoryview(arr)
        isize = view.itemsize
        if sys.platform == 'win32':
            assert isize == 2
        else:
            assert isize == 4
        assert module.write_buffer_len(arr) == isize * 3
        assert len(module.readbuffer_as_string(arr)) == isize * 3
        assert len(module.readbuffer_as_string(view)) == isize * 3

    def test_subclass(self):
        import struct
        module = self.import_module(name='array')
        class Sub(module.array):
            pass

        arr = Sub('i', [2])
        res = [1, 2, 3] * arr
        assert res == [1, 2, 3, 1, 2, 3]

        val = module.readbuffer_as_string(arr)
        assert val == struct.pack('i', 2)

    def test_unicode_readbuffer(self):
        # Not really part of array, refactor
        import struct
        module = self.import_module(name='array')
        val = module.readbuffer_as_string(b'abcd')
        assert val == b'abcd'

    def test_readinto(self):
        module = self.import_module(name='array')
        a = module.array('B')
        a.fromstring(b'0123456789')
        filename = self.udir + "/_test_file"
        f = open(filename, 'w+b')
        f.write(b'foobar')
        f.seek(0)
        n = f.readinto(a)
        f.close()
        assert n == 6
        assert len(a) == 10
        assert a.tostring() == b'foobar6789'

    def test_iowrite(self):
        module = self.import_module(name='array')
        from io import BytesIO
        a = module.array('B')
        a.fromstring(b'0123456789')
        fd = BytesIO()
        # only test that it works
        fd.write(a)

    def test_getitem_via_PySequence_GetItem(self):
        module = self.import_module(name='array')
        a = module.array('i', range(10))
        # call via tp_as_mapping.mp_subscript
        assert 5 == a[-5]
        # PySequence_ITEM used to call space.getitem() which
        # prefers tp_as_mapping.mp_subscript over tp_as_sequence.sq_item
        # Now fixed so this test raises (array_item does not add len(a),
        # array_subscr does)
        raises(IndexError, module.getitem, a, -5)

    def test_subclass_with_attribute(self):
        module = self.import_module(name='array')
        class Sub(module.array):
            def addattrib(self):
                print('called addattrib')
                self.attrib = True
        import gc
        module.subclass_with_attribute(Sub, "addattrib", "attrib", gc.collect)
        assert Sub.__module__ == __name__
