from rpython.rlib.rrawarray import copy_list_to_raw_array, \
                                   populate_list_from_raw_array
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.test.tool import BaseRtypingTest



class TestRArray(BaseRtypingTest):

    def test_copy_list_to_raw_array(self):
        ARRAY = rffi.CArray(lltype.Signed)
        buf = lltype.malloc(ARRAY, 4, flavor='raw')
        lst = [1, 2, 3, 4]
        copy_list_to_raw_array(lst, buf)
        for i in range(4):
            assert buf[i] == i+1
        lltype.free(buf, flavor='raw')
        

    def test_copy_list_to_raw_array_rtyped(self):
        INTARRAY = rffi.CArray(lltype.Signed)
        FLOATARRAY = rffi.CArray(lltype.Float)
        def fn():
            buf = lltype.malloc(INTARRAY, 3, flavor='raw')
            lst = [1, 2, 3]
            copy_list_to_raw_array(lst, buf)
            for i in range(3):
                assert buf[i] == lst[i]
            #
            buf2 = lltype.malloc(FLOATARRAY, 3, flavor='raw')
            lst = [1.1, 2.2, 3.3]
            copy_list_to_raw_array(lst, buf2)
            for i in range(3):
                assert buf2[i] == lst[i]
            #
            lltype.free(buf, flavor='raw')
            lltype.free(buf2, flavor='raw')
        self.interpret(fn, [])

    def test_new_list_from_raw_array(self):
        INTARRAY = rffi.CArray(lltype.Signed)
        buf = lltype.malloc(INTARRAY, 4, flavor='raw')
        buf[0] = 1
        buf[1] = 2
        buf[2] = 3
        buf[3] = 4
        lst = []
        populate_list_from_raw_array(lst, buf, 4)
        assert lst == [1, 2, 3, 4]
        lltype.free(buf, flavor='raw')

    def test_new_list_from_raw_array_rtyped(self):
        INTARRAY = rffi.CArray(lltype.Signed)
        def fn():
            buf = lltype.malloc(INTARRAY, 4, flavor='raw')
            buf[0] = 1
            buf[1] = 2
            buf[2] = 3
            buf[3] = 4
            lst = []
            populate_list_from_raw_array(lst, buf, 4)
            assert lst == [1, 2, 3, 4]
            lltype.free(buf, flavor='raw')
        #
        self.interpret(fn, [])
