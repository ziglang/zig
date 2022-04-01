from rpython.jit.backend.llsupport.test.test_regalloc_integration import BaseTestRegalloc

class TestRecompilation(BaseTestRegalloc):
    def test_compile_bridge_not_deeper(self):
        ops = '''
        [i0]
        label(i0, descr=targettoken)
        i1 = int_add(i0, 1)
        i2 = int_lt(i1, 20)
        guard_true(i2, descr=fdescr1) [i1]
        jump(i1, descr=targettoken)
        '''
        loop = self.interpret(ops, [0])
        assert self.getint(0) == 20
        ops = '''
        [i1]
        i3 = int_add(i1, 1)
        finish(i3)
        '''
        bridge = self.attach_bridge(ops, loop, -2)
        fail = self.run(loop, 0)
        assert fail == bridge.operations[-1].getdescr()
        assert self.getint(0) == 21
    
    def test_compile_bridge_deeper(self):
        ops = '''
        [i0]
        label(i0, descr=targettoken)
        i1 = int_add(i0, 1)
        i2 = int_lt(i1, 20)
        guard_true(i2, descr=fdescr1) [i1]
        jump(i1, descr=targettoken)
        '''
        loop = self.interpret(ops, [0])
        previous = loop._jitcelltoken.compiled_loop_token.frame_info.jfi_frame_depth
        assert self.getint(0) == 20
        ops = '''
        [i1]
        i3 = int_add(i1, 1)
        i4 = int_add(i3, 1)
        i5 = int_add(i4, 1)
        i6 = int_add(i5, 1)
        i7 = int_add(i5, i4)
        force_spill(i5)
        force_spill(i6)
        force_spill(i7)
        i8 = int_add(i7, 1)
        i9 = int_add(i8, 1)
        guard_false(i3, descr=fdescr2) [i3, i4, i5, i6, i7, i8, i9]
        finish()
        '''
        self.attach_bridge(ops, loop, -2)
        new = loop._jitcelltoken.compiled_loop_token.frame_info.jfi_frame_depth
        # the force_spill() forces the stack to grow
        assert new > previous
        fail = self.run(loop, 0)
        assert fail.identifier == 2
        assert self.getint(0) == 21
        assert self.getint(1) == 22
        assert self.getint(2) == 23
        assert self.getint(3) == 24

    def test_bridge_jump_to_other_loop(self):
        loop = self.interpret('''
        [i0, i10, i11, i12, i13, i14, i15, i16]
        label(i0, i10, i11, i12, i13, i14, i15, i16, descr=targettoken)
        i1 = int_add(i0, 1)
        i2 = int_lt(i1, 20)
        guard_true(i2, descr=fdescr1) [i1]
        jump(i1, i10, i11, i12, i13, i14, i15, i16, descr=targettoken)
        ''', [0, 0, 0, 0, 0, 0, 0, 0])
        other_loop = self.interpret('''
        [i3, i10, i11, i12, i13, i14, i15, i16]
        label(i3, descr=targettoken2)
        guard_false(i3, descr=fdescr2) [i3]
        jump(i3, descr=targettoken2)
        ''', [1, 0, 0, 0, 0, 0, 0, 0])
        ops = '''
        [i3]
        jump(i3, 1, 2, 3, 4, 5, 6, 7, descr=targettoken)
        '''
        bridge = self.attach_bridge(ops, other_loop, 1)
        fail = self.run(other_loop, 1, 0, 0, 0, 0, 0, 0, 0)
        assert fail.identifier == 1

    def test_bridge_jumps_to_self_deeper(self):
        loop = self.interpret('''
        [i0, i1, i2, i31, i32, i33]
        label(i0, i1, i2, i31, i32, i33, descr=targettoken)
        i98 = same_as_i(0)
        i99 = same_as_i(1)
        i30 = int_add(i1, i2)
        i3 = int_add(i0, 1)
        i4 = int_and(i3, 1)
        guard_false(i4) [i98, i3]
        i5 = int_lt(i3, 20)
        guard_true(i5) [i99, i3]
        jump(i3, i30, 1, i30, i30, i30, descr=targettoken)
        ''', [0, 0, 0, 0, 0, 0])
        assert self.getint(0) == 0
        assert self.getint(1) == 1
        ops = '''
        [i97, i3]
        i10 = int_mul(i3, 2)
        i8 = int_add(i3, 1)
        i15 = int_add(i3, 1)
        i16 = int_add(i3, 1)
        i17 = int_add(i3, 1)
        i18 = int_add(i3, 1)
        i6 = int_add(i8, i10)
        i7 = int_add(i3, i6)
        force_spill(i6)
        force_spill(i7)
        force_spill(i8)
        force_spill(i10)
        i12 = int_add(i7, i8)
        i11 = int_add(i12, i6)
        force_spill(i11)
        force_spill(i12)
        force_spill(i15)
        force_spill(i16)
        force_spill(i17)
        force_spill(i18)
        guard_true(i18) [i3, i12, i11, i10, i6, i7, i18, i17, i16]
        jump(i3, i12, i11, i10, i6, i7, descr=targettoken)
        '''
        loop_frame_depth = loop._jitcelltoken.compiled_loop_token.frame_info.jfi_frame_depth
        bridge = self.attach_bridge(ops, loop, 6)
        # the force_spill() forces the stack to grow
        bridge_frame_depth = loop._jitcelltoken.compiled_loop_token.frame_info.jfi_frame_depth
        assert bridge_frame_depth > loop_frame_depth
        self.run(loop, 0, 0, 0, 0, 0, 0)
        assert self.getint(0) == 1
        assert self.getint(1) == 20

    def test_bridge_jumps_to_self_shallower(self):
        loop = self.interpret('''
        [i0, i1, i2]
        label(i0, i1, i2, descr=targettoken)
        i98 = same_as_i(0)
        i99 = same_as_i(1)
        i3 = int_add(i0, 1)
        i4 = int_and(i3, 1)
        guard_false(i4) [i98, i3]
        i5 = int_lt(i3, 20)
        guard_true(i5) [i99, i3]
        jump(i3, i1, i2, descr=targettoken)
        ''', [0, 0, 0])
        assert self.getint(0) == 0
        assert self.getint(1) == 1
        ops = '''
        [i97, i3]
        jump(i3, 0, 1, descr=targettoken)
        '''
        bridge = self.attach_bridge(ops, loop, 5)
        self.run(loop, 0, 0, 0)
        assert self.getint(0) == 1
        assert self.getint(1) == 20
        
