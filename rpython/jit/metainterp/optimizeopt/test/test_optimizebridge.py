from rpython.jit.metainterp.optimizeopt.test.test_util import (
    BaseTest, convert_old_style_to_targets)
from rpython.jit.metainterp import compile
from rpython.jit.tool import oparser
from rpython.jit.metainterp.resoperation import ResOperation, rop
from rpython.jit.metainterp.history import TargetToken

class TestOptimizeBridge(BaseTest):
    enable_opts = "intbounds:rewrite:virtualize:string:earlyforce:pure:heap:unroll"

    def optimize(self, ops, bridge_ops, expected, expected_loop=None,
                 inline_short_preamble=True, jump_values=None,
                 bridge_values=None):
        loop = self.parse(ops)
        info = self.unroll_and_optimize(loop, None, jump_values=jump_values)
        jitcell_token = compile.make_jitcell_token(None)
        mid_label_descr = TargetToken(jitcell_token)
        mid_label_descr.short_preamble = info.short_preamble
        mid_label_descr.virtual_state = info.virtual_state
        start_label_descr = TargetToken(jitcell_token)
        jitcell_token.target_tokens = [mid_label_descr, start_label_descr]
        loop.operations[0].setdescr(mid_label_descr)
        loop.operations[-1].setdescr(mid_label_descr)
        info.preamble.operations[0].setdescr(start_label_descr)
        guards = [op for op in loop.operations if op.is_guard()]
        assert len(guards) == 1, "more than one guard in the loop"
        bridge = self.parse(bridge_ops)
        bridge.operations[-1].setdescr(jitcell_token)
        self.add_guard_future_condition(bridge)
        trace = oparser.convert_loop_to_trace(bridge, self.metainterp_sd)
        data = compile.BridgeCompileData(
            trace,
            self.convert_values(bridge.operations[-1].getarglist(), bridge_values),
            None, enable_opts=self.enable_opts,
            inline_short_preamble=inline_short_preamble)
        bridge_info, ops = data.optimize_trace(self.metainterp_sd, None, {})
        loop.check_consistency(check_descr=False)
        info.preamble.check_consistency(check_descr=False)
        bridge.operations = ([ResOperation(rop.LABEL, bridge_info.inputargs)] +
                             ops)
        bridge.inputargs = bridge_info.inputargs
        bridge.check_consistency(check_descr=False)
        expected = self.parse(expected)
        self.assert_equal(bridge, convert_old_style_to_targets(expected,
                                                               jump=True))
        jump_bridge = bridge.operations[-1]
        jump_d = jump_bridge.getdescr()
        jump_args = jump_bridge.getarglist()
        if loop.operations[0].getdescr() is jump_d:
            # jump to loop
            label_args = loop.operations[0].getarglist()
        else:
            assert info.preamble.operations[0].getdescr() is jump_d
            label_args = info.preamble.operations[0].getarglist()
        assert len(jump_args) == len(label_args)
        for a, b in zip(jump_args, label_args):
            assert a.type == b.type

    def test_simple(self):
        loop = """
        [i0]
        i1 = int_add(i0, 1)
        i2 = int_is_true(i1)
        guard_true(i2) [i1, i2]
        jump(i1)
        """
        bridge = """
        [i0, i1]
        jump(i1)
        """
        expected = """
        [i0, i1]
        jump(i1)
        """
        self.optimize(loop, bridge, expected)

    def test_minimal_short_preamble(self):
        loop = """
        [i0, i1, i3]
        i2 = int_add(i0, 1)
        i4 = int_add(i3, i2)
        i5 = int_is_true(i4)
        guard_true(i5) [i2, i4, i5]
        jump(i0, i1, i4)
        """
        bridge = """
        [i0, i1, i2]
        jump(i0, i1, i2)
        """
        expected = """
        [i0, i1, i2]
        i3 = int_add(i0, 1)
        jump(i0, i1, i2, i3)
        """
        self.optimize(loop, bridge, expected)

    def test_virtual_state_in_bridge(self):
        loop = """
        [i0, p1]
        p0 = new_with_vtable(descr=simpledescr)
        setfield_gc(p0, i0, descr=simplevalue)
        i3 = int_is_true(i0)
        guard_true(i3) [p0]
        i1 = int_add(i0, 1)
        jump(i1, p0)
        """
        bridge = """
        [p0]
        p1 = new_with_vtable(descr=simpledescr)
        setfield_gc(p1, 3, descr=simplevalue)
        jump(1, p1)
        """
        expected = """
        [p0]
        jump(1, 3)
        """
        self.optimize(loop, bridge, expected,
                      jump_values=[None, self.simpleaddr],
                      bridge_values=[None, self.simpleaddr])
