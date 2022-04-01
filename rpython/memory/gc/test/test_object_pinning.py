import py
from rpython.rtyper.lltypesystem import lltype, llmemory, llarena
from rpython.memory.gc.incminimark import IncrementalMiniMarkGC, WORD
from rpython.memory.gc.incminimark import GCFLAG_VISITED
from test_direct import BaseDirectGCTest

T = lltype.GcForwardReference()
T.become(lltype.GcStruct('pinning_test_struct2',
                         ('someInt', lltype.Signed)))

S = lltype.GcForwardReference()
S.become(lltype.GcStruct('pinning_test_struct1',
                         ('someInt', lltype.Signed),
                         ('next', lltype.Ptr(T)),
                         ('data', lltype.Ptr(T))))

class PinningGCTest(BaseDirectGCTest):

    def setup_method(self, meth):
        BaseDirectGCTest.setup_method(self, meth)
        max = getattr(meth, 'max_number_of_pinned_objects', 20)
        self.gc.max_number_of_pinned_objects = max
        if not hasattr(self.gc, 'minor_collection'):
            self.gc.minor_collection = self.gc._minor_collection

    def test_pin_can_move(self):
        # even a pinned object is considered to be movable. Only the caller
        # of pin() knows if it is currently movable or not.
        ptr = self.malloc(T)
        adr = llmemory.cast_ptr_to_adr(ptr)
        assert self.gc.can_move(adr)
        assert self.gc.pin(adr)
        assert self.gc.can_move(adr)

    def test_pin_twice(self):
        ptr = self.malloc(T)
        adr = llmemory.cast_ptr_to_adr(ptr)
        assert self.gc.pin(adr)
        assert not self.gc.pin(adr)

    def test_unpin_not_pinned(self):
        # this test checks a requirement of the unpin() interface
        ptr = self.malloc(S)
        py.test.raises(Exception,
            self.gc.unpin, llmemory.cast_ptr_to_adr(ptr))

    def test__is_pinned(self):
        ptr = self.malloc(T)
        adr = llmemory.cast_ptr_to_adr(ptr)
        assert not self.gc._is_pinned(adr)
        assert self.gc.pin(adr)
        assert self.gc._is_pinned(adr)
        self.gc.unpin(adr)
        assert not self.gc._is_pinned(adr)

    def test_prebuilt_not_pinnable(self):
        ptr = lltype.malloc(T, immortal=True)
        self.consider_constant(ptr)
        assert not self.gc.pin(llmemory.cast_ptr_to_adr(ptr))
        self.gc.collect()
        assert not self.gc.pin(llmemory.cast_ptr_to_adr(ptr))

    # XXX test with multiple mallocs, and only part of them is pinned

    def test_random(self):
        # scenario: create bunch of objects. randomly pin, unpin, add to
        # stackroots and remove from stackroots.
        import random

        for i in xrange(10**3):
            obj = self.malloc(T)
            obj.someInt = 100
            #
            if random.random() < 0.5:
                self.stackroots.append(obj)
                print("+stack")
            if random.random() < 0.5:
                self.gc.pin(llmemory.cast_ptr_to_adr(obj))
                print("+pin")
            self.gc.debug_gc_step(random.randint(1, 4))
            for o in self.stackroots[:]:
                assert o.someInt == 100
                o_adr = llmemory.cast_ptr_to_adr(o)
                if random.random() < 0.1 and self.gc._is_pinned(o_adr):
                    print("-pin")
                    self.gc.unpin(o_adr)
                if random.random() < 0.1:
                    print("-stack")
                    self.stackroots.remove(o)


class TestIncminimark(PinningGCTest):
    from rpython.memory.gc.incminimark import IncrementalMiniMarkGC as GCClass
    from rpython.memory.gc.incminimark import STATE_SCANNING, STATE_MARKING

    def test_try_pin_gcref_containing_type(self):
        # scenario: incminimark's object pinning can't pin objects that may
        # contain GC pointers
        obj = self.malloc(S)
        assert not self.gc.pin(llmemory.cast_ptr_to_adr(obj))


    def test_pin_old(self):
        # scenario: try pinning an old object. This should be not possible and
        # we want to make sure everything stays as it is.
        old_ptr = self.malloc(S)
        old_ptr.someInt = 900
        self.stackroots.append(old_ptr)
        assert self.stackroots[0] == old_ptr # test assumption
        self.gc.collect()
        old_ptr = self.stackroots[0]
        # now we try to pin it
        old_adr = llmemory.cast_ptr_to_adr(old_ptr)
        assert not self.gc.is_in_nursery(old_adr)
        assert not self.gc.pin(old_adr)
        assert self.gc.pinned_objects_in_nursery == 0

    
    def pin_pin_pinned_object_count(self, collect_func):
        # scenario: pin two objects that are referenced from stackroots. Check
        # if the pinned objects count is correct, even after an other collection
        pinned1_ptr = self.malloc(T)
        pinned1_ptr.someInt = 100
        self.stackroots.append(pinned1_ptr)
        #
        pinned2_ptr = self.malloc(T)
        pinned2_ptr.someInt = 200
        self.stackroots.append(pinned2_ptr)
        #
        assert self.gc.pin(llmemory.cast_ptr_to_adr(pinned1_ptr))
        assert self.gc.pinned_objects_in_nursery == 1
        assert self.gc.pin(llmemory.cast_ptr_to_adr(pinned2_ptr))
        assert self.gc.pinned_objects_in_nursery == 2
        #
        collect_func()
        #
        assert self.gc.pinned_objects_in_nursery == 2

    def test_pin_pin_pinned_object_count_minor_collection(self):
        self.pin_pin_pinned_object_count(self.gc.minor_collection)

    def test_pin_pin_pinned_object_count_major_collection(self):
        self.pin_pin_pinned_object_count(self.gc.collect)


    def pin_unpin_pinned_object_count(self, collect_func):
        # scenario: pin an object and check the pinned object count. Unpin it
        # and check the count again.
        pinned_ptr = self.malloc(T)
        pinned_ptr.someInt = 100
        self.stackroots.append(pinned_ptr)
        pinned_adr = llmemory.cast_ptr_to_adr(pinned_ptr)
        #
        assert self.gc.pinned_objects_in_nursery == 0
        assert self.gc.pin(pinned_adr)
        assert self.gc.pinned_objects_in_nursery == 1
        collect_func()
        assert self.gc.pinned_objects_in_nursery == 1
        self.gc.unpin(pinned_adr)
        assert self.gc.pinned_objects_in_nursery == 0
        collect_func()
        assert self.gc.pinned_objects_in_nursery == 0

    def test_pin_unpin_pinned_object_count_minor_collection(self):
        self.pin_unpin_pinned_object_count(self.gc.minor_collection)

    def test_pin_unpin_pinned_object_count_major_collection(self):
        self.pin_unpin_pinned_object_count(self.gc.collect)


    def pinned_obj_in_stackroot(self, collect_func):
        # scenario: a pinned object that is part of the stack roots. Check if
        # it is not moved
        #
        ptr = self.malloc(T)
        ptr.someInt = 100
        self.stackroots.append(ptr)
        assert self.stackroots[0] == ptr # validate our assumption
        
        adr = llmemory.cast_ptr_to_adr(ptr)
        assert self.gc.is_in_nursery(adr) # to be sure
        assert self.gc.pin(adr)
        #
        # the object shouldn't move from now on
        collect_func()
        #
        # check if it is still at the same location as expected
        adr_after_collect = llmemory.cast_ptr_to_adr(self.stackroots[0])
        assert self.gc.is_in_nursery(adr_after_collect)
        assert adr == adr_after_collect
        assert self.gc._is_pinned(adr)
        assert ptr.someInt == 100
        assert self.gc.pinned_objects_in_nursery == 1

    def test_pinned_obj_in_stackroot_minor_collection(self):
        self.pinned_obj_in_stackroot(self.gc.minor_collection)

    def test_pinned_obj_in_stackroot_full_major_collection(self):
        self.pinned_obj_in_stackroot(self.gc.collect)

    def test_pinned_obj_in_stackroots_stepwise_major_collection(self):
        # scenario: same as for 'pinned_obj_in_stackroot' with minor change
        # that we do stepwise major collection and check in each step for
        # a correct state
        #
        ptr = self.malloc(T)
        ptr.someInt = 100
        self.stackroots.append(ptr)
        assert self.stackroots[0] == ptr # validate our assumption

        adr = llmemory.cast_ptr_to_adr(ptr)
        assert self.gc.is_in_nursery(adr)
        assert self.gc.pin(adr)
        #
        # the object shouldn't move from now on. Do a full round of major
        # steps and check each time for correct state
        #
        # check that we start at the expected point
        assert self.gc.gc_state == self.STATE_SCANNING
        done = False
        while not done:
            self.gc.debug_gc_step()
            # check that the pinned object didn't move
            ptr_after_collection = self.stackroots[0]
            adr_after_collection = llmemory.cast_ptr_to_adr(ptr_after_collection)
            assert self.gc.is_in_nursery(adr_after_collection)
            assert adr == adr_after_collection
            assert self.gc._is_pinned(adr)
            assert ptr.someInt == 100
            assert self.gc.pinned_objects_in_nursery == 1
            # as the object is referenced from the stackroots, the gc internal
            # 'old_objects_pointing_to_pinned' should be empty
            assert not self.gc.old_objects_pointing_to_pinned.non_empty()
            #
            # break condition
            done = self.gc.gc_state == self.STATE_SCANNING

    
    def pin_unpin_moved_stackroot(self, collect_func):
        # scenario: test if the pinned object is moved after being unpinned.
        # the second part of the scenario is the tested one. The first part
        # is already tests by other tests.
        ptr = self.malloc(T)
        ptr.someInt = 100
        self.stackroots.append(ptr)
        assert self.stackroots[0] == ptr # validate our assumption

        adr = llmemory.cast_ptr_to_adr(ptr)
        assert self.gc.pin(adr)

        collect_func()
        #
        # from here on the test really starts. previouse logic is already tested
        #
        self.gc.unpin(adr)
        assert not self.gc._is_pinned(adr)
        assert self.gc.is_in_nursery(adr)
        #
        # now we do another collection and the object should be moved out of
        # the nursery.
        collect_func()
        new_adr = llmemory.cast_ptr_to_adr(self.stackroots[0])
        assert not self.gc.is_in_nursery(new_adr)
        assert self.stackroots[0].someInt == 100
        with py.test.raises(RuntimeError) as exinfo:
            ptr.someInt = 200
        assert "freed" in str(exinfo.value)

    def test_pin_unpin_moved_stackroot_minor_collection(self):
        self.pin_unpin_moved_stackroot(self.gc.minor_collection)

    def test_pin_unpin_moved_stackroot_major_collection(self):
        self.pin_unpin_moved_stackroot(self.gc.collect)

    
    def pin_referenced_from_old(self, collect_func):
        # scenario: an old object points to a pinned one. Check if the pinned
        # object is correctly kept in the nursery and not moved.
        #
        # create old object
        old_ptr = self.malloc(S)
        old_ptr.someInt = 900
        self.stackroots.append(old_ptr)
        assert self.stackroots[0] == old_ptr # validate our assumption
        collect_func() # make it old: move it out of the nursery
        old_ptr = self.stackroots[0]
        assert not self.gc.is_in_nursery(llmemory.cast_ptr_to_adr(old_ptr))
        #
        # create young pinned one and let the old one reference the young one
        pinned_ptr = self.malloc(T)
        pinned_ptr.someInt = 100
        self.write(old_ptr, 'next', pinned_ptr)
        pinned_adr = llmemory.cast_ptr_to_adr(pinned_ptr)
        assert self.gc.pin(pinned_adr)
        assert self.gc.is_in_nursery(pinned_adr)
        assert old_ptr.next.someInt == 100
        assert self.gc.pinned_objects_in_nursery == 1
        #
        # do a collection run and make sure the pinned one didn't move
        collect_func()
        assert old_ptr.next.someInt == pinned_ptr.someInt == 100
        assert llmemory.cast_ptr_to_adr(old_ptr.next) == pinned_adr
        assert self.gc.is_in_nursery(pinned_adr)
        
    def test_pin_referenced_from_old_minor_collection(self):
        self.pin_referenced_from_old(self.gc.minor_collection)

    def test_pin_referenced_from_old_major_collection(self):
        self.pin_referenced_from_old(self.gc.collect)

    def test_pin_referenced_from_old_stepwise_major_collection(self):
        # scenario: same as in 'pin_referenced_from_old'. However,
        # this time we do a major collection step by step and check
        # between steps that the states are as expected.
        #
        # create old object
        old_ptr = self.malloc(S)
        old_ptr.someInt = 900
        self.stackroots.append(old_ptr)
        assert self.stackroots[0] == old_ptr # validate our assumption
        self.gc.minor_collection() # make it old: move it out of the nursery
        old_ptr = self.stackroots[0]
        old_adr = llmemory.cast_ptr_to_adr(old_ptr)
        assert not self.gc.is_in_nursery(old_adr)
        #
        # create young pinned one and let the old one reference the young one
        pinned_ptr = self.malloc(T)
        pinned_ptr.someInt = 100
        self.write(old_ptr, 'next', pinned_ptr)
        pinned_adr = llmemory.cast_ptr_to_adr(pinned_ptr)
        assert self.gc.pin(pinned_adr)
        assert self.gc.is_in_nursery(pinned_adr)
        assert old_ptr.next.someInt == 100
        assert self.gc.pinned_objects_in_nursery == 1
        #
        # stepwise major collection with validation between steps
        # check that we start at the expected point
        assert self.gc.gc_state == self.STATE_SCANNING
        done = False
        while not done:
            self.gc.debug_gc_step()
            #
            # make sure pinned object didn't move
            assert old_ptr.next.someInt == pinned_ptr.someInt == 100
            assert llmemory.cast_ptr_to_adr(old_ptr.next) == pinned_adr
            assert self.gc.is_in_nursery(pinned_adr)
            assert self.gc.pinned_objects_in_nursery == 1
            #
            # validate that the old object is part of the internal list
            # 'old_objects_pointing_to_pinned' as expected.
            should_be_old_adr = self.gc.old_objects_pointing_to_pinned.pop()
            assert should_be_old_adr == old_adr
            self.gc.old_objects_pointing_to_pinned.append(should_be_old_adr)
            #
            # break condition
            done = self.gc.gc_state == self.STATE_SCANNING

    
    def pin_referenced_from_old_remove_ref(self, collect_func):
        # scenario: an old object points to a pinned one. We remove the
        # reference from the old one. So nothing points to the pinned object.
        # After this the pinned object should be collected (it's dead).
        #
        # Create the objects and get them to our initial state (this is not
        # tested here, should be already tested by other tests)
        old_ptr = self.malloc(S)
        old_ptr.someInt = 900
        self.stackroots.append(old_ptr)
        assert self.stackroots[0] == old_ptr # check assumption
        collect_func() # make it old
        old_ptr = self.stackroots[0]
        #
        pinned_ptr = self.malloc(T)
        pinned_ptr.someInt = 100
        self.write(old_ptr, 'next', pinned_ptr)
        pinned_adr = llmemory.cast_ptr_to_adr(pinned_ptr)
        assert self.gc.pin(pinned_adr)
        #
        collect_func()
        # from here on we have our initial state for this test.
        #
        # first check some basic assumptions.
        assert self.gc.is_in_nursery(pinned_adr)
        assert self.gc._is_pinned(pinned_adr)
        # remove the reference
        self.write(old_ptr, 'next', lltype.nullptr(T))
        # from now on the pinned object is dead. Do a collection and make sure
        # old object still there and the pinned one is gone.
        collect_func()
        assert self.stackroots[0].someInt == 900
        assert not self.gc.old_objects_pointing_to_pinned.non_empty()
        with py.test.raises(RuntimeError) as exinfo:
            pinned_ptr.someInt = 200
        assert "freed" in str(exinfo.value)

    def test_pin_referenced_from_old_remove_ref_minor_collection(self):
        self.pin_referenced_from_old_remove_ref(self.gc.minor_collection)

    def test_pin_referenced_from_old_remove_ref_major_collection(self):
        self.pin_referenced_from_old_remove_ref(self.gc.collect)


    def pin_referenced_from_old_remove_old(self, collect_func):
        # scenario: an old object referenced a pinned object. After removing
        # the stackroot reference to the old object, bot objects (old and pinned)
        # must be collected.
        # This test is important as we expect not reachable pinned objects to
        # be collected. At the same time we have an internal list of objects
        # pointing to pinned ones and we must make sure that because of it the
        # old/pinned object survive.
        #
        # create the objects and get them to the initial state for this test.
        # Everything on the way to the initial state should be covered by
        # other tests.
        old_ptr = self.malloc(S)
        old_ptr.someInt = 900
        self.stackroots.append(old_ptr)
        collect_func()
        old_ptr = self.stackroots[0]
        #
        pinned_ptr = self.malloc(T)
        pinned_ptr.someInt = 100
        self.write(old_ptr, 'next', pinned_ptr)
        assert self.gc.pin(llmemory.cast_ptr_to_adr(pinned_ptr))
        #
        collect_func()
        #
        # now we have our initial state: old object referenced from stackroots.
        # Old object referencing a young pinned one. Next step is to make some
        # basic checks that we got the expected state.
        assert not self.gc.is_in_nursery(llmemory.cast_ptr_to_adr(old_ptr))
        assert self.gc.is_in_nursery(llmemory.cast_ptr_to_adr(pinned_ptr))
        assert pinned_ptr == old_ptr.next
        #
        # now we remove the old object from the stackroots...
        self.stackroots.remove(old_ptr)
        # ... and do a major collection (otherwise the old object wouldn't be
        # gone).
        self.gc.collect()
        # check that both objects are gone
        assert not self.gc.old_objects_pointing_to_pinned.non_empty()
        with py.test.raises(RuntimeError) as exinfo_old:
            old_ptr.someInt = 800
        assert "freed" in str(exinfo_old.value)
        #
        with py.test.raises(RuntimeError) as exinfo_pinned:
            pinned_ptr.someInt = 200
        assert "freed" in str(exinfo_pinned.value)

    def test_pin_referenced_from_old_remove_old_minor_collection(self):
        self.pin_referenced_from_old_remove_old(self.gc.minor_collection)

    def test_pin_referenced_from_old_remove_old_major_collection(self):
        self.pin_referenced_from_old_remove_old(self.gc.collect)


    def pin_referenced_from_young_in_stackroots(self, collect_func):
        # scenario: a young object is referenced from the stackroots. This
        # young object points to a young pinned object. We check if everything
        # behaves as expected after a collection: the young object is moved out
        # of the nursery while the pinned one stays where it is.
        #
        root_ptr = self.malloc(S)
        root_ptr.someInt = 900
        self.stackroots.append(root_ptr)
        assert self.stackroots[0] == root_ptr # validate assumption
        #
        pinned_ptr = self.malloc(T)
        pinned_ptr.someInt = 100
        self.write(root_ptr, 'next', pinned_ptr)
        pinned_adr = llmemory.cast_ptr_to_adr(pinned_ptr)
        assert self.gc.pin(pinned_adr)
        # check both are in nursery
        assert self.gc.is_in_nursery(llmemory.cast_ptr_to_adr(root_ptr))
        assert self.gc.is_in_nursery(pinned_adr)
        #
        # no old object yet pointing to a pinned one
        assert not self.gc.old_objects_pointing_to_pinned.non_empty()
        #
        # now we do a collection and check if the result is as expected
        collect_func()
        #
        # check if objects are where we expect them
        root_ptr = self.stackroots[0]
        assert not self.gc.is_in_nursery(llmemory.cast_ptr_to_adr(root_ptr))
        assert self.gc.is_in_nursery(pinned_adr)
        # and as 'root_ptr' object is now old, it should be tracked specially
        should_be_root_adr = self.gc.old_objects_pointing_to_pinned.pop()
        assert should_be_root_adr == llmemory.cast_ptr_to_adr(root_ptr)
        self.gc.old_objects_pointing_to_pinned.append(should_be_root_adr)
        # check that old object still points to the pinned one as expected
        assert root_ptr.next == pinned_ptr

    def test_pin_referenced_from_young_in_stackroots_minor_collection(self):
        self.pin_referenced_from_young_in_stackroots(self.gc.minor_collection)

    def test_pin_referenced_from_young_in_stackroots_major_collection(self):
        self.pin_referenced_from_young_in_stackroots(self.gc.collect)


    def pin_referenced_from_prebuilt(self, collect_func):
        # scenario: a prebuilt object points to a pinned object. Check if the
        # pinned object doesn't move and is still accessible.
        #
        prebuilt_ptr = lltype.malloc(S, immortal=True)
        prebuilt_ptr.someInt = 900
        self.consider_constant(prebuilt_ptr)
        prebuilt_adr = llmemory.cast_ptr_to_adr(prebuilt_ptr)
        collect_func()
        #        
        pinned_ptr = self.malloc(T)
        pinned_ptr.someInt = 100
        self.write(prebuilt_ptr, 'next', pinned_ptr)
        pinned_adr = llmemory.cast_ptr_to_adr(pinned_ptr)
        assert self.gc.pin(pinned_adr)
        #
        # check if everything is as expected
        assert not self.gc.is_in_nursery(prebuilt_adr)
        assert self.gc.is_in_nursery(pinned_adr)
        assert pinned_ptr == prebuilt_ptr.next
        assert pinned_ptr.someInt == 100
        #
        # do a collection and check again
        collect_func()
        assert self.gc.is_in_nursery(pinned_adr)
        assert pinned_ptr == prebuilt_ptr.next
        assert pinned_ptr.someInt == 100

    def test_pin_referenced_from_prebuilt_minor_collection(self):
        self.pin_referenced_from_prebuilt(self.gc.minor_collection)

    def test_pin_referenced_from_prebuilt_major_collection(self):
        self.pin_referenced_from_prebuilt(self.gc.collect)


    def test_old_objects_pointing_to_pinned_not_exploading(self):
        # scenario: two old object, each pointing twice to a pinned object.
        # The internal 'old_objects_pointing_to_pinned' should contain
        # always two objects.
        # In previous implementation the list exploded (grew with every minor
        # collection), hence this test.
        old1_ptr = self.malloc(S)
        old1_ptr.someInt = 900
        self.stackroots.append(old1_ptr)
        
        old2_ptr = self.malloc(S)
        old2_ptr.someInt = 800
        self.stackroots.append(old2_ptr)
        
        pinned_ptr = self.malloc(T)
        pinned_ptr.someInt = 100
        assert self.gc.pin(llmemory.cast_ptr_to_adr(pinned_ptr))
        
        self.write(old1_ptr, 'next', pinned_ptr)
        self.write(old1_ptr, 'data', pinned_ptr)
        self.write(old2_ptr, 'next', pinned_ptr)
        self.write(old2_ptr, 'data', pinned_ptr)

        self.gc.collect()
        old1_ptr = self.stackroots[0]
        old2_ptr = self.stackroots[1]
        assert not self.gc.is_in_nursery(llmemory.cast_ptr_to_adr(old1_ptr))
        assert not self.gc.is_in_nursery(llmemory.cast_ptr_to_adr(old2_ptr))

        # do multiple rounds to make sure
        for _ in range(10):
            assert self.gc.old_objects_pointing_to_pinned.length() == 2
            self.gc.debug_gc_step()


    def pin_shadow_1(self, collect_func):
        ptr = self.malloc(T)
        adr = llmemory.cast_ptr_to_adr(ptr)
        self.stackroots.append(ptr)
        ptr.someInt = 100
        assert self.gc.pin(adr)
        self.gc.id(ptr) # allocate shadow
        collect_func()
        assert self.gc.is_in_nursery(adr)
        assert ptr.someInt == 100
        self.gc.unpin(adr)
        collect_func() # move to shadow
        adr = llmemory.cast_ptr_to_adr(self.stackroots[0])
        assert not self.gc.is_in_nursery(adr)

    def test_pin_shadow_1_minor_collection(self):
        self.pin_shadow_1(self.gc.minor_collection)

    def test_pin_shadow_1_major_collection(self):
        self.pin_shadow_1(self.gc.collect)


    def test_malloc_different_types(self):
        # scenario: malloc two objects of different type and pin them. Do a
        # minor and major collection in between. This test showed a bug that was
        # present in a previous implementation of pinning.
        obj1 = self.malloc(T)
        self.stackroots.append(obj1)
        assert self.gc.pin(llmemory.cast_ptr_to_adr(obj1))
        #
        self.gc.collect()
        #
        obj2 = self.malloc(T)
        self.stackroots.append(obj2)
        assert self.gc.pin(llmemory.cast_ptr_to_adr(obj2))


    def test_objects_to_trace_bug(self):
        # scenario: In a previous implementation there was a bug because of a
        # dead pointer inside 'objects_to_trace'. This was caused by the first
        # major collection step that added the pointer to the list and right
        # after the collection step the object is unpinned and freed by the minor
        # collection, leaving a dead pointer in the list.
        pinned_ptr = self.malloc(T)
        pinned_ptr.someInt = 101
        self.stackroots.append(pinned_ptr)
        pinned_adr = llmemory.cast_ptr_to_adr(pinned_ptr)
        assert self.gc.pin(pinned_adr)
        self.gc.debug_gc_step()
        self.gc.unpin(pinned_adr)
        self.gc.debug_gc_step()


    def pin_shadow_2(self, collect_func):
        ptr = self.malloc(T)
        adr = llmemory.cast_ptr_to_adr(ptr)
        self.stackroots.append(ptr)
        ptr.someInt = 100
        assert self.gc.pin(adr)
        self.gc.identityhash(ptr) # allocate shadow
        collect_func()
        assert self.gc.is_in_nursery(adr)
        assert ptr.someInt == 100
        self.gc.unpin(adr)
        collect_func() # move to shadow
        adr = llmemory.cast_ptr_to_adr(self.stackroots[0])
        assert not self.gc.is_in_nursery(adr)

    def test_pin_shadow_2_minor_collection(self):
        self.pin_shadow_2(self.gc.minor_collection)

    def test_pin_shadow_2_major_collection(self):
        self.pin_shadow_2(self.gc.collect)


    def test_pin_nursery_top_scenario1(self):
        ptr1 = self.malloc(T)
        adr1 = llmemory.cast_ptr_to_adr(ptr1)
        ptr1.someInt = 101
        self.stackroots.append(ptr1)
        assert self.gc.pin(adr1)
        
        ptr2 = self.malloc(T)
        adr2 = llmemory.cast_ptr_to_adr(ptr2)
        ptr2.someInt = 102
        self.stackroots.append(ptr2)
        assert self.gc.pin(adr2)

        ptr3 = self.malloc(T)
        adr3 = llmemory.cast_ptr_to_adr(ptr3)
        ptr3.someInt = 103
        self.stackroots.append(ptr3)
        assert self.gc.pin(adr3)

        # scenario: no minor collection happened, only three mallocs
        # and pins
        #
        # +- nursery
        # |
        # v
        # +--------+--------+--------+---------------------...---+
        # | pinned | pinned | pinned | empty                     |
        # +--------+--------+--------+---------------------...---+
        #                            ^                           ^
        #                            |                           |
        #              nursery_free -+                           |
        #                                           nursery_top -+
        #
        assert adr3 < self.gc.nursery_free
        assert self.gc.nursery_free < self.gc.nursery_top


    def test_pin_nursery_top_scenario2(self):
        ptr1 = self.malloc(T)
        adr1 = llmemory.cast_ptr_to_adr(ptr1)
        ptr1.someInt = 101
        self.stackroots.append(ptr1)
        assert self.gc.pin(adr1)
        
        ptr2 = self.malloc(T)
        adr2 = llmemory.cast_ptr_to_adr(ptr2)
        ptr2.someInt = 102
        self.stackroots.append(ptr2)
        assert self.gc.pin(adr2)

        ptr3 = self.malloc(T)
        adr3 = llmemory.cast_ptr_to_adr(ptr3)
        ptr3.someInt = 103
        self.stackroots.append(ptr3)
        assert self.gc.pin(adr3)

        # scenario: after first GC minor collection
        #
        # +- nursery
        # |
        # v
        # +--------+--------+--------+---------------------...---+
        # | pinned | pinned | pinned | empty                     |
        # +--------+--------+--------+---------------------...---+
        # ^
        # |
        # +- nursery_free
        # +- nursery_top
        #
        self.gc.collect()

        assert self.gc.nursery_free == self.gc.nursery_top
        assert self.gc.nursery_top == self.gc.nursery
        assert self.gc.nursery_top < adr3


    def test_pin_nursery_top_scenario3(self):
        ptr1 = self.malloc(T)
        adr1 = llmemory.cast_ptr_to_adr(ptr1)
        ptr1.someInt = 101
        self.stackroots.append(ptr1)
        assert self.gc.pin(adr1)
        
        ptr2 = self.malloc(T)
        adr2 = llmemory.cast_ptr_to_adr(ptr2)
        ptr2.someInt = 102
        self.stackroots.append(ptr2)
        assert self.gc.pin(adr2)

        ptr3 = self.malloc(T)
        adr3 = llmemory.cast_ptr_to_adr(ptr3)
        ptr3.someInt = 103
        self.stackroots.append(ptr3)
        assert self.gc.pin(adr3)

        # scenario: after unpinning first object and a minor
        # collection
        #
        # +- nursery
        # |
        # v
        # +--------+--------+--------+---------------------...---+
        # | empty  | pinned | pinned | empty                     |
        # +--------+--------+--------+---------------------...---+
        # ^        ^
        # |        |
        # |        +- nursery_top
        # +- nursery_free
        #
        self.gc.unpin(adr1)
        self.gc.collect()

        assert self.gc.nursery_free == self.gc.nursery
        assert self.gc.nursery_top > self.gc.nursery_free
        assert self.gc.nursery_top < adr2


    def test_pin_nursery_top_scenario4(self):
        ptr1 = self.malloc(T)
        adr1 = llmemory.cast_ptr_to_adr(ptr1)
        ptr1.someInt = 101
        self.stackroots.append(ptr1)
        assert self.gc.pin(adr1)
        
        ptr2 = self.malloc(T)
        adr2 = llmemory.cast_ptr_to_adr(ptr2)
        ptr2.someInt = 102
        self.stackroots.append(ptr2)
        assert self.gc.pin(adr2)

        ptr3 = self.malloc(T)
        adr3 = llmemory.cast_ptr_to_adr(ptr3)
        ptr3.someInt = 103
        self.stackroots.append(ptr3)
        assert self.gc.pin(adr3)

        # scenario: after unpinning first & second object and a minor
        # collection
        #
        # +- nursery
        # |
        # v
        # +-----------------+--------+---------------------...---+
        # | empty           | pinned | empty                     |
        # +-----------------+--------+---------------------...---+
        # ^                 ^
        # |                 |
        # |                 +- nursery_top
        # +- nursery_free
        #
        self.gc.unpin(adr1)
        self.gc.unpin(adr2)
        self.gc.collect()

        assert self.gc.nursery_free == self.gc.nursery
        assert self.gc.nursery_free < self.gc.nursery_top
        assert self.gc.nursery_top < adr3
        

    def test_pin_nursery_top_scenario5(self):
        ptr1 = self.malloc(T)
        adr1 = llmemory.cast_ptr_to_adr(ptr1)
        ptr1.someInt = 101
        self.stackroots.append(ptr1)
        assert self.gc.pin(adr1)
        
        ptr2 = self.malloc(T)
        adr2 = llmemory.cast_ptr_to_adr(ptr2)
        ptr2.someInt = 102
        self.stackroots.append(ptr2)
        assert self.gc.pin(adr2)

        ptr3 = self.malloc(T)
        adr3 = llmemory.cast_ptr_to_adr(ptr3)
        ptr3.someInt = 103
        self.stackroots.append(ptr3)
        assert self.gc.pin(adr3)

        # scenario: no minor collection happened, only three mallocs
        # and pins
        #
        # +- nursery
        # |
        # v
        # +--------+--------+--------+---------------------...---+
        # | pinned | pinned | pinned | empty                     |
        # +--------+--------+--------+---------------------...---+
        #                            ^                           ^
        #                            |                           |
        #              nursery_free -+                           |
        #                                           nursery_top -+
        #
        assert adr3 < self.gc.nursery_free
        assert self.gc.nursery_free < self.gc.nursery_top

        # scenario: unpin everything and minor collection
        #
        # +- nursery
        # |
        # v
        # +----------------------------------+-------------...---+
        # | reset arena                      | empty (not reset) |
        # +----------------------------------+-------------...---+
        # ^                                  ^
        # |                                  |
        # +- nursery_free                    |
        #                       nursery_top -+
        #
        self.gc.unpin(adr1)
        self.gc.unpin(adr2)
        self.gc.unpin(adr3)
        self.gc.collect()

        assert self.gc.nursery_free == self.gc.nursery
        assert self.gc.nursery_top > self.gc.nursery_free


    def fill_nursery_with_pinned_objects(self):
        typeid = self.get_type_id(T)
        size = self.gc.fixed_size(typeid) + self.gc.gcheaderbuilder.size_gc_header
        raw_size = llmemory.raw_malloc_usage(size)
        object_mallocs = self.gc.nursery_size // raw_size
        for instance_nr in xrange(object_mallocs):
            ptr = self.malloc(T)
            adr = llmemory.cast_ptr_to_adr(ptr)
            ptr.someInt = 100 + instance_nr
            self.stackroots.append(ptr)
            self.gc.pin(adr)

    def test_full_pinned_nursery_pin_fail(self):
        self.fill_nursery_with_pinned_objects()
        # nursery should be full now, at least no space for another `T`.
        # Next malloc should fail.
        py.test.raises(Exception, self.malloc, T)

    def test_full_pinned_nursery_arena_reset(self):
        # there were some bugs regarding the 'arena_reset()' calls at
        # the end of the minor collection.  This test brought them to light.
        self.fill_nursery_with_pinned_objects()
        self.gc.collect()

    def test_pinning_limit(self):
        assert self.gc.max_number_of_pinned_objects == 5
        for instance_nr in xrange(self.gc.max_number_of_pinned_objects):
            ptr = self.malloc(T)
            adr = llmemory.cast_ptr_to_adr(ptr)
            ptr.someInt = 100 + instance_nr
            self.stackroots.append(ptr)
            assert self.gc.pin(adr)
        #
        # now we reached the maximum amount of pinned objects
        ptr = self.malloc(T)
        adr = llmemory.cast_ptr_to_adr(ptr)
        self.stackroots.append(ptr)
        assert not self.gc.pin(adr)
    test_pinning_limit.max_number_of_pinned_objects = 5

    def test_full_pinned_nursery_pin_fail(self):
        typeid = self.get_type_id(T)
        size = self.gc.fixed_size(typeid) + self.gc.gcheaderbuilder.size_gc_header
        raw_size = llmemory.raw_malloc_usage(size)
        object_mallocs = self.gc.nursery_size // raw_size
        # just to be sure we do not run into the limit as we test not the limiter
        # but rather the case of a nursery full with pinned objects.
        assert object_mallocs < self.gc.max_number_of_pinned_objects
        for instance_nr in xrange(object_mallocs):
            ptr = self.malloc(T)
            adr = llmemory.cast_ptr_to_adr(ptr)
            ptr.someInt = 100 + instance_nr
            self.stackroots.append(ptr)
            self.gc.pin(adr)
        #
        # nursery should be full now, at least no space for another `T`.
        # Next malloc should fail.
        py.test.raises(Exception, self.malloc, T)
    test_full_pinned_nursery_pin_fail.max_number_of_pinned_objects = 50


    def test_pin_bug1(self):
        #
        # * the nursery contains a pinned object 'ptr1'
        #
        # * outside the nursery is another object 'ptr2' pointing to 'ptr1'
        #
        # * during one incremental tracing step, we see 'ptr2' but don't
        #   trace 'ptr1' right now: it is left behind on the trace-me-later
        #   list
        #
        # * then we run the program, unpin 'ptr1', and remove it from 'ptr2'
        #
        # * at the next minor collection, we free 'ptr1' because we don't
        #   find anything pointing to it (it is removed from 'ptr2'),
        #   but 'ptr1' is still in the trace-me-later list
        #
        # * the trace-me-later list is deep enough that 'ptr1' is not
        #   seen right now!  it is only seen at some later minor collection
        #
        # * at that later point, crash, because 'ptr1' in the nursery was
        #   overwritten
        #
        ptr2 = self.malloc(S)
        ptr2.someInt = 102
        self.stackroots.append(ptr2)

        self.gc.collect()
        ptr2 = self.stackroots[-1]    # now outside the nursery
        adr2 = llmemory.cast_ptr_to_adr(ptr2)

        ptr1 = self.malloc(T)
        adr1 = llmemory.cast_ptr_to_adr(ptr1)
        ptr1.someInt = 101
        self.write(ptr2, 'data', ptr1)
        res = self.gc.pin(adr1)
        assert res

        self.gc.minor_collection()
        assert self.gc.gc_state == self.STATE_SCANNING
        self.gc.major_collection_step()
        assert self.gc.objects_to_trace.tolist() == [adr2]
        assert self.gc.more_objects_to_trace.tolist() == []

        self.gc.TEST_VISIT_SINGLE_STEP = True

        self.gc.minor_collection()
        assert self.gc.gc_state == self.STATE_MARKING
        self.gc.major_collection_step()
        assert self.gc.objects_to_trace.tolist() == []
        assert self.gc.more_objects_to_trace.tolist() == [adr2]

        self.write(ptr2, 'data', lltype.nullptr(T))
        self.gc.unpin(adr1)

        assert ptr1.someInt == 101
        self.gc.minor_collection()        # should free 'ptr1'
        py.test.raises(RuntimeError, "ptr1.someInt")
        assert self.gc.gc_state == self.STATE_MARKING
        self.gc.major_collection_step()   # should not crash reading 'ptr1'!

        del self.gc.TEST_VISIT_SINGLE_STEP


    def test_pin_bug2(self):
        #
        # * we have an old object A that points to a pinned object B
        #
        # * we unpin B
        #
        # * the next minor_collection() is done in STATE_MARKING==1
        #   when the object A is already black
        #
        # * _minor_collection() => _visit_old_objects_pointing_to_pinned()
        #   which will move the now-unpinned B out of the nursery, to B'
        #
        # At that point we need to take care of colors, otherwise we
        # get a black object (A) pointing to a white object (B'),
        # which must never occur.
        #
        ptrA = self.malloc(T)
        ptrA.someInt = 42
        adrA = llmemory.cast_ptr_to_adr(ptrA)
        res = self.gc.pin(adrA)
        assert res

        ptrC = self.malloc(S)
        self.stackroots.append(ptrC)

        ptrB = self.malloc(S)
        ptrB.data = ptrA
        self.stackroots.append(ptrB)

        self.gc.collect()
        ptrB = self.stackroots[-1]    # now old and outside the nursery
        ptrC = self.stackroots[-2]    # another random old object, traced later
        adrB = llmemory.cast_ptr_to_adr(ptrB)

        self.gc.minor_collection()
        assert self.gc.gc_state == self.STATE_SCANNING
        self.gc.major_collection_step()
        assert self.gc.gc_state == self.STATE_MARKING
        assert not (self.gc.header(adrB).tid & GCFLAG_VISITED)  # not black yet

        self.gc.TEST_VISIT_SINGLE_STEP = True
        self.gc.major_collection_step()
        assert self.gc.gc_state == self.STATE_MARKING
        assert self.gc.header(adrB).tid & GCFLAG_VISITED    # now black
        # but ptrC is not traced yet, which is why we're still in STATE_MARKING
        assert self.gc.old_objects_pointing_to_pinned.tolist() == [adrB]

        self.gc.unpin(adrA)

        self.gc.DEBUG = 2
        self.gc.minor_collection()
