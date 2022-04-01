import py
from rpython.jit.metainterp.heapcache import HeapCache
from rpython.jit.metainterp.resoperation import rop, InputArgInt
from rpython.jit.metainterp.history import ConstInt, ConstPtr, BasicFailDescr
from rpython.jit.metainterp.history import IntFrontendOp, RefFrontendOp
from rpython.rtyper.lltypesystem import  llmemory, rffi

descr1 = object()
descr2 = object()
descr3 = object()

index1 = ConstInt(0)
index2 = ConstInt(1)


class FakeEffectinfo(object):
    EF_ELIDABLE_CANNOT_RAISE           = 0 #elidable function (and cannot raise)
    EF_LOOPINVARIANT                   = 1 #special: call it only once per loop
    EF_CANNOT_RAISE                    = 2 #a function which cannot raise
    EF_ELIDABLE_OR_MEMORYERROR         = 3
    EF_ELIDABLE_CAN_RAISE              = 4 #elidable function (but can raise)
    EF_CAN_RAISE                       = 5 #normal function (can raise)
    EF_FORCES_VIRTUAL_OR_VIRTUALIZABLE = 6 #can raise and force virtualizables
    EF_RANDOM_EFFECTS                  = 7 #can do whatever

    OS_ARRAYCOPY = 0
    OS_ARRAYMOVE = 9

    def __init__(self, extraeffect, oopspecindex, write_descrs_fields, write_descrs_arrays):
        self.extraeffect = extraeffect
        self.oopspecindex = oopspecindex
        self._write_descrs_fields = write_descrs_fields
        self._write_descrs_arrays = write_descrs_arrays
        if len(write_descrs_arrays) == 1:
            [self.single_write_descr_array] = write_descrs_arrays
        else:
            self.single_write_descr_array = None

    def has_random_effects(self):
        return self.extraeffect == self.EF_RANDOM_EFFECTS

class FakeCallDescr(object):
    def __init__(self, extraeffect, oopspecindex=None, write_descrs_fields=[], write_descrs_arrays=[]):
        self.extraeffect = extraeffect
        self.oopspecindex = oopspecindex
        self.__write_descrs_fields = write_descrs_fields
        self.__write_descrs_arrays = write_descrs_arrays

    def get_extra_info(self):
        return FakeEffectinfo(
            self.extraeffect, self.oopspecindex,
            write_descrs_fields=self.__write_descrs_fields,
            write_descrs_arrays=self.__write_descrs_arrays,
        )

arraycopydescr1 = FakeCallDescr(FakeEffectinfo.EF_CANNOT_RAISE, FakeEffectinfo.OS_ARRAYCOPY, write_descrs_arrays=[descr1])


class TestHeapCache(object):
    def test_known_class_box(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        assert not h.is_class_known(box1)
        assert not h.is_class_known(box2)
        h.class_now_known(box1)
        assert h.is_class_known(box1)
        assert not h.is_class_known(box2)

        h.reset()
        assert not h.is_class_known(box1)
        assert not h.is_class_known(box2)

    def test_known_nullity(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        assert not h.is_nullity_known(box1)
        assert not h.is_nullity_known(box2)
        h.nullity_now_known(box1)
        assert h.is_nullity_known(box1)
        assert not h.is_nullity_known(box2)

        h.reset()
        assert not h.is_nullity_known(box1)
        assert not h.is_nullity_known(box2)

    def test_known_nullity_more_cases(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        h.class_now_known(box1)
        assert h.is_nullity_known(box1)

        h.new(box2)
        assert h.is_nullity_known(box2)

        h.reset()
        assert not h.is_nullity_known(box1)
        assert not h.is_nullity_known(box2)

    def test_nonstandard_virtualizable(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        assert not h.is_known_nonstandard_virtualizable(box1)
        assert not h.is_known_nonstandard_virtualizable(box2)
        h.nonstandard_virtualizables_now_known(box1)
        assert h.is_known_nonstandard_virtualizable(box1)
        assert not h.is_known_nonstandard_virtualizable(box2)

        h.reset()
        assert not h.is_known_nonstandard_virtualizable(box1)
        assert not h.is_known_nonstandard_virtualizable(box2)

    def test_nonstandard_virtualizable_const(self):
        h = HeapCache()
        # rare but not impossible situation for some interpreters: we have a
        # *constant* nonstandard virtualizable
        c_box = ConstPtr(ConstPtr.value)
        h.nonstandard_virtualizables_now_known(c_box) # should not crash
        assert not h.is_known_nonstandard_virtualizable(c_box)

    def test_nonstandard_virtualizable_allocation(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        h.new(box1)
        # we've seen the allocation, so it's not the virtualizable
        assert h.is_known_nonstandard_virtualizable(box1)

        h.reset()
        assert not h.is_known_nonstandard_virtualizable(box1)

    def test_heapcache_fields(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        assert h.getfield(box1, descr1) is None
        assert h.getfield(box1, descr2) is None
        h.setfield(box1, box2, descr1)
        assert h.getfield(box1, descr1) is box2
        assert h.getfield(box1, descr2) is None
        h.setfield(box1, box3, descr2)
        assert h.getfield(box1, descr1) is box2
        assert h.getfield(box1, descr2) is box3
        h.setfield(box1, box3, descr1)
        assert h.getfield(box1, descr1) is box3
        assert h.getfield(box1, descr2) is box3
        h.setfield(box3, box1, descr1)
        assert h.getfield(box3, descr1) is box1
        assert h.getfield(box1, descr1) is None
        assert h.getfield(box1, descr2) is box3

        h.reset()
        assert h.getfield(box1, descr1) is None
        assert h.getfield(box1, descr2) is None
        assert h.getfield(box3, descr1) is None

    def test_heapcache_read_fields_multiple(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.getfield_now_known(box1, descr1, box2)
        h.getfield_now_known(box3, descr1, box4)
        assert h.getfield(box1, descr1) is box2
        assert h.getfield(box1, descr2) is None
        assert h.getfield(box3, descr1) is box4
        assert h.getfield(box3, descr2) is None

        h.reset()
        assert h.getfield(box1, descr1) is None
        assert h.getfield(box1, descr2) is None
        assert h.getfield(box3, descr1) is None
        assert h.getfield(box3, descr2) is None

    def test_heapcache_write_fields_multiple(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.setfield(box1, box2, descr1)
        assert h.getfield(box1, descr1) is box2
        h.setfield(box3, box4, descr1)
        assert h.getfield(box3, descr1) is box4
        assert h.getfield(box1, descr1) is None # box1 and box3 can alias

        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.new(box1)
        h.setfield(box1, box2, descr1)
        assert h.getfield(box1, descr1) is box2
        h.setfield(box3, box4, descr1)
        assert h.getfield(box3, descr1) is box4
        assert h.getfield(box1, descr1) is None # box1 and box3 can alias

        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.new(box1)
        h.new(box3)
        h.setfield(box1, box2, descr1)
        assert h.getfield(box1, descr1) is box2
        h.setfield(box3, box4, descr1)
        assert h.getfield(box3, descr1) is box4
        assert h.getfield(box1, descr1) is box2 # box1 and box3 cannot alias
        h.setfield(box1, box3, descr1)
        assert h.getfield(box1, descr1) is box3


    def test_heapcache_arrays(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        assert h.getarrayitem(box1, index1, descr1) is None
        assert h.getarrayitem(box1, index1, descr2) is None
        assert h.getarrayitem(box1, index2, descr1) is None
        assert h.getarrayitem(box1, index2, descr2) is None

        h.setarrayitem(box1, index1, box2, descr1)
        assert h.getarrayitem(box1, index1, descr1) is box2
        assert h.getarrayitem(box1, index1, descr2) is None
        assert h.getarrayitem(box1, index2, descr1) is None
        assert h.getarrayitem(box1, index2, descr2) is None
        h.setarrayitem(box1, index2, box4, descr1)
        assert h.getarrayitem(box1, index1, descr1) is box2
        assert h.getarrayitem(box1, index1, descr2) is None
        assert h.getarrayitem(box1, index2, descr1) is box4
        assert h.getarrayitem(box1, index2, descr2) is None

        h.setarrayitem(box1, index1, box3, descr2)
        assert h.getarrayitem(box1, index1, descr1) is box2
        assert h.getarrayitem(box1, index1, descr2) is box3
        assert h.getarrayitem(box1, index2, descr1) is box4
        assert h.getarrayitem(box1, index2, descr2) is None

        h.setarrayitem(box1, index1, box3, descr1)
        assert h.getarrayitem(box1, index1, descr1) is box3
        assert h.getarrayitem(box1, index1, descr2) is box3
        assert h.getarrayitem(box1, index2, descr1) is box4
        assert h.getarrayitem(box1, index2, descr2) is None

        h.setarrayitem(box3, index1, box1, descr1)
        assert h.getarrayitem(box3, index1, descr1) is box1
        assert h.getarrayitem(box1, index1, descr1) is None
        assert h.getarrayitem(box1, index1, descr2) is box3
        assert h.getarrayitem(box1, index2, descr1) is box4
        assert h.getarrayitem(box1, index2, descr2) is None

        h.reset()
        assert h.getarrayitem(box1, index1, descr1) is None
        assert h.getarrayitem(box1, index1, descr2) is None
        assert h.getarrayitem(box3, index1, descr1) is None

    def test_heapcache_array_nonconst_index(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.setarrayitem(box1, index1, box2, descr1)
        h.setarrayitem(box1, index2, box4, descr1)
        assert h.getarrayitem(box1, index1, descr1) is box2
        assert h.getarrayitem(box1, index2, descr1) is box4
        h.setarrayitem(box1, box2, box3, descr1)
        assert h.getarrayitem(box1, index1, descr1) is None
        assert h.getarrayitem(box1, index2, descr1) is None

    def test_heapcache_read_fields_multiple_array(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.getarrayitem_now_known(box1, index1, box2, descr1)
        h.getarrayitem_now_known(box3, index1, box4, descr1)
        assert h.getarrayitem(box1, index1, descr1) is box2
        assert h.getarrayitem(box1, index1, descr2) is None
        assert h.getarrayitem(box3, index1, descr1) is box4
        assert h.getarrayitem(box3, index1, descr2) is None

        h.reset()
        assert h.getarrayitem(box1, index1, descr1) is None
        assert h.getarrayitem(box1, index1, descr2) is None
        assert h.getarrayitem(box3, index1, descr1) is None
        assert h.getarrayitem(box3, index1, descr2) is None

    def test_heapcache_write_fields_multiple_array(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.setarrayitem(box1, index1, box2, descr1)
        assert h.getarrayitem(box1, index1, descr1) is box2
        h.setarrayitem(box3, index1, box4, descr1)
        assert h.getarrayitem(box3, index1, descr1) is box4
        assert h.getarrayitem(box1, index1, descr1) is None # box1 and box3 can alias

        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.new(box1)
        h.setarrayitem(box1, index1, box2, descr1)
        assert h.getarrayitem(box1, index1, descr1) is box2
        h.setarrayitem(box3, index1, box4, descr1)
        assert h.getarrayitem(box3, index1, descr1) is box4
        assert h.getarrayitem(box1, index1, descr1) is None # box1 and box3 can alias

        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.new(box1)
        h.new(box3)
        h.setarrayitem(box1, index1, box2, descr1)
        assert h.getarrayitem(box1, index1, descr1) is box2
        h.setarrayitem(box3, index1, box4, descr1)
        assert h.getarrayitem(box3, index1, descr1) is box4
        assert h.getarrayitem(box1, index1, descr1) is box2 # box1 and box3 cannot alias
        h.setarrayitem(box1, index1, box3, descr1)
        assert h.getarrayitem(box3, index1, descr1) is box4
        assert h.getarrayitem(box1, index1, descr1) is box3 # box1 and box3 cannot alias

    def test_length_cache(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        lengthbox1 = IntFrontendOp(11)
        lengthbox2 = IntFrontendOp(12)
        h.new_array(box1, lengthbox1)
        assert h.arraylen(box1) is lengthbox1

        assert h.arraylen(box2) is None
        h.arraylen_now_known(box2, lengthbox2)
        assert h.arraylen(box2) is lengthbox2


    def test_invalidate_cache(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box4 = RefFrontendOp(4)
        h.setfield(box1, box2, descr1)
        h.setarrayitem(box1, index1, box2, descr1)
        h.setarrayitem(box1, index2, box4, descr1)
        h.invalidate_caches(rop.INT_ADD, None, [])
        h.invalidate_caches(rop.INT_ADD_OVF, None, [])
        h.invalidate_caches(rop.SETFIELD_RAW, None, [])
        h.invalidate_caches(rop.SETARRAYITEM_RAW, None, [])
        assert h.getfield(box1, descr1) is box2
        assert h.getarrayitem(box1, index1, descr1) is box2
        assert h.getarrayitem(box1, index2, descr1) is box4

        h.invalidate_caches(
            rop.CALL_N, FakeCallDescr(FakeEffectinfo.EF_ELIDABLE_CANNOT_RAISE), [])
        assert h.getfield(box1, descr1) is box2
        assert h.getarrayitem(box1, index1, descr1) is box2
        assert h.getarrayitem(box1, index2, descr1) is box4

        h.invalidate_caches(rop.GUARD_TRUE, None, [])
        assert h.getfield(box1, descr1) is box2
        assert h.getarrayitem(box1, index1, descr1) is box2
        assert h.getarrayitem(box1, index2, descr1) is box4

        h.invalidate_caches(
            rop.CALL_LOOPINVARIANT_N, FakeCallDescr(FakeEffectinfo.EF_LOOPINVARIANT), [])

        h.invalidate_caches(
            rop.CALL_N, FakeCallDescr(FakeEffectinfo.EF_RANDOM_EFFECTS), [])
        assert h.getfield(box1, descr1) is None
        assert h.getarrayitem(box1, index1, descr1) is None
        assert h.getarrayitem(box1, index2, descr1) is None

    def test_replace_box_with_box(self):
        py.test.skip("replacing a box with another box: not supported any more")
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        h.setfield(box1, box2, descr1)
        h.setfield(box1, box3, descr2)
        h.setfield(box2, box3, descr3)
        h.replace_box(box1, box4)
        assert h.getfield(box4, descr1) is box2
        assert h.getfield(box4, descr2) is box3
        assert h.getfield(box2, descr3) is box3
        h.setfield(box4, box3, descr1)
        assert h.getfield(box4, descr1) is box3

    def test_replace_box_with_const(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        c_box3 = ConstPtr(ConstPtr.value)
        h.setfield(box1, box2, descr1)
        h.setfield(box1, box3, descr2)
        h.setfield(box2, box3, descr3)
        h.replace_box(box3, c_box3)
        assert h.getfield(box1, descr1) is box2
        assert c_box3.same_constant(h.getfield(box1, descr2))
        assert c_box3.same_constant(h.getfield(box2, descr3))

    def test_replace_box_twice(self):
        py.test.skip("replacing a box with another box: not supported any more")
        h = HeapCache()
        h.setfield(box1, box2, descr1)
        h.setfield(box1, box3, descr2)
        h.setfield(box2, box3, descr3)
        h.replace_box(box1, box4)
        h.replace_box(box4, box5)
        assert h.getfield(box5, descr1) is box2
        assert h.getfield(box5, descr2) is box3
        assert h.getfield(box2, descr3) is box3
        h.setfield(box5, box3, descr1)
        assert h.getfield(box4, descr1) is box3

        h = HeapCache()
        h.setfield(box1, box2, descr1)
        h.setfield(box1, box3, descr2)
        h.setfield(box2, box3, descr3)
        h.replace_box(box3, box4)
        h.replace_box(box4, box5)
        assert h.getfield(box1, descr1) is box2
        assert h.getfield(box1, descr2) is box5
        assert h.getfield(box2, descr3) is box5

    def test_replace_box_array(self):
        py.test.skip("replacing a box with another box: not supported any more")
        h = HeapCache()
        h.setarrayitem(box1, index1, box2, descr1)
        h.setarrayitem(box1, index1, box3, descr2)
        h.arraylen_now_known(box1, lengthbox1)
        h.setarrayitem(box2, index2, box1, descr1)
        h.setarrayitem(box3, index2, box1, descr2)
        h.setarrayitem(box2, index2, box3, descr3)
        h.replace_box(box1, box4)
        assert h.arraylen(box4) is lengthbox1
        assert h.getarrayitem(box4, index1, descr1) is box2
        assert h.getarrayitem(box4, index1, descr2) is box3
        assert h.getarrayitem(box2, index2, descr1) is box4
        assert h.getarrayitem(box3, index2, descr2) is box4
        assert h.getarrayitem(box2, index2, descr3) is box3

        h.replace_box(lengthbox1, lengthbox2)
        assert h.arraylen(box4) is lengthbox2

    def test_replace_box_array_twice(self):
        py.test.skip("replacing a box with another box: not supported any more")
        h = HeapCache()
        h.setarrayitem(box1, index1, box2, descr1)
        h.setarrayitem(box1, index1, box3, descr2)
        h.arraylen_now_known(box1, lengthbox1)
        h.setarrayitem(box2, index2, box1, descr1)
        h.setarrayitem(box3, index2, box1, descr2)
        h.setarrayitem(box2, index2, box3, descr3)
        h.replace_box(box1, box4)
        h.replace_box(box4, box5)
        assert h.arraylen(box4) is lengthbox1
        assert h.getarrayitem(box5, index1, descr1) is box2
        assert h.getarrayitem(box5, index1, descr2) is box3
        assert h.getarrayitem(box2, index2, descr1) is box5
        assert h.getarrayitem(box3, index2, descr2) is box5
        assert h.getarrayitem(box2, index2, descr3) is box3

        h.replace_box(lengthbox1, lengthbox2)
        h.replace_box(lengthbox2, lengthbox3)
        assert h.arraylen(box4) is lengthbox3

    def test_replace_box_with_const_in_array(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        lengthbox2 = IntFrontendOp(2)
        lengthbox2.setint(10)
        h.arraylen_now_known(box1, lengthbox2)
        assert h.arraylen(box1) is lengthbox2
        c10 = ConstInt(10)
        h.replace_box(lengthbox2, c10)
        assert c10.same_constant(h.arraylen(box1))

        box2 = IntFrontendOp(2)
        box2.setint(12)
        h.setarrayitem(box1, index2, box2, descr1)
        assert h.getarrayitem(box1, index2, descr1) is box2
        c12 = ConstInt(12)
        h.replace_box(box2, c12)
        assert c12.same_constant(h.getarrayitem(box1, index2, descr1))

    def test_ll_arraycopy(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        box5 = RefFrontendOp(5)
        lengthbox1 = IntFrontendOp(11)
        lengthbox2 = IntFrontendOp(12)
        h.new_array(box1, lengthbox1)
        h.setarrayitem(box1, index1, box2, descr1)
        h.new_array(box2, lengthbox1)
        # Just need the destination box for this call
        h.invalidate_caches(
            rop.CALL_N,
            arraycopydescr1,
            [None, box5, box2, index1, index1, index1]
        )
        assert h.getarrayitem(box1, index1, descr1) is box2
        h.invalidate_caches(
            rop.CALL_N,
            arraycopydescr1,
            [None, box5, box3, index1, index1, index1]
        )
        assert h.getarrayitem(box1, index1, descr1) is box2

        h.setarrayitem(box4, index1, box2, descr1)
        assert h.getarrayitem(box4, index1, descr1) is box2
        h.invalidate_caches(
            rop.CALL_N,
            arraycopydescr1,
            [None, box3, box5, index1, index1, index2]
        )
        assert h.getarrayitem(box4, index1, descr1) is None

    def test_ll_arraycopy_differing_descrs(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        lengthbox2 = IntFrontendOp(12)
        h.setarrayitem(box1, index1, box2, descr2)
        assert h.getarrayitem(box1, index1, descr2) is box2
        h.new_array(box2, lengthbox2)
        h.invalidate_caches(
            rop.CALL_N,
            arraycopydescr1,
            [None, box3, box2, index1, index1, index2]
        )
        assert h.getarrayitem(box1, index1, descr2) is box2

    def test_ll_arraycopy_differing_descrs_nonconst_index(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        h.setarrayitem(box1, index1, box2, descr2)
        assert h.getarrayitem(box1, index1, descr2) is box2
        h.invalidate_caches(
            rop.CALL_N,
            arraycopydescr1,
            [None, box3, box2, index1, index1, InputArgInt()]
        )
        assert h.getarrayitem(box1, index1, descr2) is box2

    def test_ll_arraycopy_result_propogated(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        h.setarrayitem(box1, index1, box2, descr1)
        h.invalidate_caches(
            rop.CALL_N,
            arraycopydescr1,
            [None, box1, box3, index1, index1, index2]
        )
        assert h.getarrayitem(box3, index1, descr1) is box2

    def test_ll_arraycopy_dest_new(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        lengthbox1 = IntFrontendOp(11)
        h.new_array(box1, lengthbox1)
        h.setarrayitem(box3, index1, box4, descr1)
        h.invalidate_caches(
            rop.CALL_N,
            arraycopydescr1,
            [None, box2, box1, index1, index1, index2]
        )

    def test_ll_arraycopy_doesnt_escape_arrays(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        lengthbox1 = IntFrontendOp(11)
        lengthbox2 = IntFrontendOp(12)
        h.new_array(box1, lengthbox1)
        h.new_array(box2, lengthbox2)
        h.invalidate_caches(
            rop.CALL_N,
            arraycopydescr1,
            [None, box2, box1, index1, index1, index2]
        )
        assert h.is_unescaped(box1)
        assert h.is_unescaped(box2)
        h.invalidate_caches(
            rop.CALL_N,
            arraycopydescr1,
            [None, box2, box1, index1, index1, InputArgInt()]
        )
        assert not h.is_unescaped(box1)
        assert not h.is_unescaped(box2)

    def test_unescaped(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        assert not h.is_unescaped(box1)
        h.new(box2)
        assert h.is_unescaped(box2)
        h.invalidate_caches(rop.SETFIELD_GC, None, [box2, box1])
        assert h.is_unescaped(box2)
        h.invalidate_caches(rop.SETFIELD_GC, None, [box1, box2])
        assert not h.is_unescaped(box2)

    def test_unescaped_testing(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        h.new(box1)
        h.new(box2)
        assert h.is_unescaped(box1)
        assert h.is_unescaped(box2)
        # Putting a virtual inside of another virtual doesn't escape it.
        h.invalidate_caches(rop.SETFIELD_GC, None, [box1, box2])
        assert h.is_unescaped(box2)
        # Reading a field from a virtual doesn't escape it.
        h.invalidate_caches(rop.GETFIELD_GC_I, None, [box1])
        assert h.is_unescaped(box1)
        # Escaping a virtual transitively escapes anything inside of it.
        assert not h.is_unescaped(box3)
        h.invalidate_caches(rop.SETFIELD_GC, None, [box3, box1])
        assert not h.is_unescaped(box1)
        assert not h.is_unescaped(box2)

    def test_ops_dont_escape(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        h.new(box1)
        h.new(box2)
        assert h.is_unescaped(box1)
        assert h.is_unescaped(box2)
        h.invalidate_caches(rop.INSTANCE_PTR_EQ, None, [box1, box2])
        assert h.is_unescaped(box1)
        assert h.is_unescaped(box2)
        h.invalidate_caches(rop.INSTANCE_PTR_NE, None, [box1, box2])
        assert h.is_unescaped(box1)
        assert h.is_unescaped(box2)

    def test_circular_virtuals(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        h.new(box1)
        h.new(box2)
        h.invalidate_caches(rop.SETFIELD_GC, None, [box1, box2])
        h.invalidate_caches(rop.SETFIELD_GC, None, [box2, box1])
        h.invalidate_caches(rop.SETFIELD_GC, None, [box3, box1]) # does not crash

    def test_unescaped_array(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        lengthbox1 = IntFrontendOp(11)
        lengthbox2 = IntFrontendOp(12)
        h.new_array(box1, lengthbox1)
        assert h.is_unescaped(box1)
        h.invalidate_caches(rop.SETARRAYITEM_GC, None, [box1, index1, box2])
        assert h.is_unescaped(box1)
        h.invalidate_caches(rop.SETARRAYITEM_GC, None, [box2, index1, box1])
        assert not h.is_unescaped(box1)

        h = HeapCache()
        h.new_array(box1, lengthbox1)
        h.new(box2)
        assert h.is_unescaped(box1)
        assert h.is_unescaped(box2)
        h.invalidate_caches(rop.SETARRAYITEM_GC, None, [box1, lengthbox2, box2])
        assert h.is_unescaped(box1)
        assert h.is_unescaped(box2)
        h.invalidate_caches(
            rop.CALL_N, FakeCallDescr(FakeEffectinfo.EF_RANDOM_EFFECTS), [box1]
        )
        assert not h.is_unescaped(box1)
        assert not h.is_unescaped(box2)

    def test_call_doesnt_invalidate_unescaped_boxes(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        h.new(box1)
        assert h.is_unescaped(box1)
        h.setfield(box1, box2, descr1)
        h.invalidate_caches(rop.CALL_N,
            FakeCallDescr(FakeEffectinfo.EF_CAN_RAISE),
            []
        )
        assert h.getfield(box1, descr1) is box2

    def test_call_doesnt_invalidate_unescaped_array_boxes(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box3 = RefFrontendOp(3)
        lengthbox1 = IntFrontendOp(11)
        h.new_array(box1, lengthbox1)
        assert h.is_unescaped(box1)
        h.setarrayitem(box1, index1, box3, descr1)
        h.invalidate_caches(rop.CALL_N,
            FakeCallDescr(FakeEffectinfo.EF_CAN_RAISE),
            []
        )
        assert h.getarrayitem(box1, index1, descr1) is box3

    def test_bug_missing_ignored_operations(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        h.new(box1)
        h.new(box2)
        h.setfield(box1, box2, descr1)
        assert h.getfield(box1, descr1) is box2
        h.invalidate_caches(rop.STRSETITEM, None, [])
        h.invalidate_caches(rop.UNICODESETITEM, None, [])
        h.invalidate_caches(rop.SETFIELD_RAW, None, [])
        h.invalidate_caches(rop.SETARRAYITEM_RAW, None, [])
        h.invalidate_caches(rop.SETINTERIORFIELD_RAW, None, [])
        h.invalidate_caches(rop.RAW_STORE, None, [])
        assert h.is_unescaped(box1)
        assert h.is_unescaped(box2)
        assert h.getfield(box1, descr1) is box2

    def test_bug_heap_cache_is_cleared_but_not_is_unescaped_1(self):
        # bug if only the getfield() link is cleared (heap_cache) but not
        # the is_unescaped() flags: we can do later a GETFIELD(box1) which
        # will give us a fresh box3, which is actually equal to box2.  This
        # box3 is escaped, but box2 is still unescaped.  Bug shown e.g. by
        # calling some residual code that changes the values on box3: then
        # the content of box2 is still cached at the old value.
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        h.new(box1)
        h.new(box2)
        h.setfield(box1, box2, descr1)
        h.invalidate_caches(rop.SETFIELD_GC, None, [box1, box2])
        assert h.getfield(box1, descr1) is box2
        h.invalidate_caches(rop.CALL_MAY_FORCE_N, FakeCallDescr(FakeEffectinfo.EF_RANDOM_EFFECTS), [])
        assert not h.is_unescaped(box1)
        assert not h.is_unescaped(box2)
        assert h.getfield(box1, descr1) is None

    def test_bug_heap_cache_is_cleared_but_not_is_unescaped_2(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        h.new(box1)
        h.new(box2)
        h.setfield(box1, box2, descr1)
        h.invalidate_caches(rop.SETFIELD_GC, None, [box1, box2])
        assert h.getfield(box1, descr1) is box2
        descr = BasicFailDescr()
        class XTra:
            oopspecindex = 0
            OS_ARRAYCOPY = 42
            OS_ARRAYMOVE = 49
            extraeffect = 5
            EF_LOOPINVARIANT = 1
            EF_ELIDABLE_CANNOT_RAISE = 2
            EF_ELIDABLE_OR_MEMORYERROR = 3
            EF_ELIDABLE_CAN_RAISE = 4
        descr.get_extra_info = XTra
        h.invalidate_caches(rop.CALL_N, descr, [])
        assert h.is_unescaped(box1)
        assert h.is_unescaped(box2)
        assert h.getfield(box1, descr1) is box2

    def test_is_likely_virtual(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        h.new(box1)
        assert h.is_unescaped(box1)
        assert h.is_likely_virtual(box1)
        h.reset_keep_likely_virtuals()
        assert not h.is_unescaped(box1)
        assert h.is_likely_virtual(box1)
        h._escape_box(box1)
        assert not h.is_unescaped(box1)
        assert not h.is_likely_virtual(box1)

    def test_is_likely_virtual_2(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        h.new(box1)
        assert h.is_unescaped(box1)
        assert h.is_likely_virtual(box1)
        h.reset_keep_likely_virtuals()
        assert not h.is_unescaped(box1)
        assert h.is_likely_virtual(box1)
        h.reset()     # reset everything
        assert not h.is_unescaped(box1)
        assert not h.is_likely_virtual(box1)

    def test_is_likely_virtual_3(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        h.new(box1)
        assert h.is_unescaped(box1)
        assert h.is_likely_virtual(box1)
        h.reset_keep_likely_virtuals()
        assert not h.is_unescaped(box1)
        assert h.is_likely_virtual(box1)
        h.class_now_known(box1)     # interaction of the two families of flags
        assert not h.is_unescaped(box1)
        assert h.is_likely_virtual(box1)

    def test_quasiimmut_seen(self):
        h = HeapCache()
        box1 = RefFrontendOp(1)
        box2 = RefFrontendOp(2)
        box3 = RefFrontendOp(3)
        box4 = RefFrontendOp(4)
        assert not h.is_quasi_immut_known(descr1, box1)
        assert not h.is_quasi_immut_known(descr1, box2)
        assert not h.is_quasi_immut_known(descr2, box3)
        assert not h.is_quasi_immut_known(descr2, box4)
        h.quasi_immut_now_known(descr1, box1)
        assert h.is_quasi_immut_known(descr1, box1)
        assert not h.is_quasi_immut_known(descr1, box2)
        assert not h.is_quasi_immut_known(descr2, box3)
        assert not h.is_quasi_immut_known(descr2, box4)
        h.quasi_immut_now_known(descr1, box2)
        assert h.is_quasi_immut_known(descr1, box1)
        assert h.is_quasi_immut_known(descr1, box2)
        assert not h.is_quasi_immut_known(descr2, box3)
        assert not h.is_quasi_immut_known(descr2, box4)
        h.quasi_immut_now_known(descr2, box3)
        assert h.is_quasi_immut_known(descr1, box1)
        assert h.is_quasi_immut_known(descr1, box2)
        assert h.is_quasi_immut_known(descr2, box3)
        assert not h.is_quasi_immut_known(descr2, box4)
        h.quasi_immut_now_known(descr2, box4)
        assert h.is_quasi_immut_known(descr1, box1)
        assert h.is_quasi_immut_known(descr1, box2)
        assert h.is_quasi_immut_known(descr2, box3)
        assert h.is_quasi_immut_known(descr2, box4)

        # invalidate the descr1 cache

        h.setfield(box1, box3, descr1)
        assert not h.is_quasi_immut_known(descr1, box1)
        assert not h.is_quasi_immut_known(descr1, box2)

        # a call invalidates everything
        h.invalidate_caches(
            rop.CALL_N, FakeCallDescr(FakeEffectinfo.EF_CAN_RAISE), [])
        assert not h.is_quasi_immut_known(descr2, box3)
        assert not h.is_quasi_immut_known(descr2, box4)


    def test_quasiimmut_seen_consts(self):
        h = HeapCache()
        box1 = ConstPtr(rffi.cast(llmemory.GCREF, 1))
        box2 = ConstPtr(rffi.cast(llmemory.GCREF, 1))
        box3 = ConstPtr(rffi.cast(llmemory.GCREF, 1))
        box4 = ConstPtr(rffi.cast(llmemory.GCREF, 1))
        assert not h.is_quasi_immut_known(descr1, box1)
        assert not h.is_quasi_immut_known(descr1, box2)
        assert not h.is_quasi_immut_known(descr2, box3)
        assert not h.is_quasi_immut_known(descr2, box4)
        h.quasi_immut_now_known(descr1, box1)
        assert h.is_quasi_immut_known(descr1, box1)
        assert h.is_quasi_immut_known(descr1, box2)
        assert not h.is_quasi_immut_known(descr2, box3)
        assert not h.is_quasi_immut_known(descr2, box4)
        h.quasi_immut_now_known(descr2, box3)
        assert h.is_quasi_immut_known(descr1, box1)
        assert h.is_quasi_immut_known(descr1, box2)
        assert h.is_quasi_immut_known(descr2, box3)
        assert h.is_quasi_immut_known(descr2, box4)

        # invalidate the descr1 cache

        vbox1 = RefFrontendOp(1)
        vbox2 = RefFrontendOp(2)
        h.setfield(vbox1, vbox2, descr1)
        assert not h.is_quasi_immut_known(descr1, box1)
        assert not h.is_quasi_immut_known(descr1, box2)

        # a call invalidates everything
        h.invalidate_caches(
            rop.CALL_N, FakeCallDescr(FakeEffectinfo.EF_CAN_RAISE), [])
        assert not h.is_quasi_immut_known(descr2, box3)
        assert not h.is_quasi_immut_known(descr2, box4)
