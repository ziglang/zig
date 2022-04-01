import re
from StringIO import StringIO
from rpython.rlib import debug
from rpython.jit.tool.oparser import pure_parse
from rpython.jit.metainterp import logger
from rpython.jit.metainterp.optimizeopt.util import equaloplists
from rpython.jit.metainterp.history import (
    AbstractDescr, JitCellToken, BasicFailDescr, BasicFinalDescr)


class Descr(AbstractDescr):
    final_descr = False

def capturing(func, *args, **kwds):
    log_stream = StringIO()
    class MyDebugLog:
        def debug_print(self, *args):
            for arg in args:
                print >> log_stream, arg,
            print >> log_stream

        def debug_start(self, *args):
            pass

        def debug_stop(self, *args):
            pass
    try:
        debug._log = MyDebugLog()
        func(*args, **kwds)
    finally:
        debug._log = None
    return log_stream.getvalue()

class Logger(logger.Logger):
    def log_loop(self, loop, namespace={}, ops_offset=None, name=''):
        self.namespace = namespace
        return capturing(logger.Logger.log_loop, self,
                         loop.inputargs, loop.operations, ops_offset=ops_offset,
                         name=name)

    def _make_log_operations(self1, memo):
        class LogOperations(logger.LogOperations):
            def repr_of_descr(self, descr):
                for k, v in self1.namespace.items():
                    if v == descr:
                        return k
                return descr.repr_of_descr()
        logops = LogOperations(self1.metainterp_sd, self1.guard_number, memo)
        self1.logops = logops
        return logops

class TestLogger(object):
    def make_metainterp_sd(self):
        class FakeJitDriver(object):
            class warmstate(object):
                get_location_str = staticmethod(lambda args: "dupa")

        class FakeMetaInterpSd:
            jitdrivers_sd = [FakeJitDriver()]
            def get_name_from_address(self, addr):
                return 'Name'
        return FakeMetaInterpSd()

    def reparse(self, inp, namespace=None, check_equal=True):
        """ parse loop once, then log it and parse again.
        Checks that we get the same thing.
        """
        if namespace is None:
            namespace = {}
        loop = pure_parse(inp, namespace=namespace)
        logger = Logger(self.make_metainterp_sd())
        output = logger.log_loop(loop, namespace)
        oloop = pure_parse(output, namespace=namespace)
        if check_equal:
            remap = {}
            for box1, box2 in zip(loop.inputargs, oloop.inputargs):
                assert box1.__class__ == box2.__class__
                remap[box2] = box1
            equaloplists(loop.operations, oloop.operations, remap=remap)
        return logger, loop, oloop

    def test_simple(self):
        inp = '''
        [i0, i1, i2, p3, p4, p5]
        i6 = int_add(i1, i2)
        i8 = int_add(i6, 3)
        jump(i0, i8, i6, p3, p4, p5)
        '''
        self.reparse(inp)

    def test_descr(self):
        inp = '''
        [p0]
        setfield_gc(p0, 3, descr=somedescr)
        '''
        somedescr = Descr()
        self.reparse(inp, namespace=locals())

    def test_guard(self):
        inp = '''
        [i0]
        i1 = int_add(i0, 1)
        guard_true(i0) [i0, i1]
        finish(i1)
        '''
        self.reparse(inp)

    def test_guard_not_invalidated(self):
        inp = '''
        []
        guard_not_invalidated(descr=descr) []
        finish(descr=finaldescr)
        '''
        loop = pure_parse(inp, namespace={'descr': Descr(),
                                          'finaldescr': BasicFinalDescr()})
        logger = Logger(self.make_metainterp_sd())
        output = logger.log_loop(loop, {'descr': Descr()})
        assert 'guard_not_invalidated(descr=' in output

    def test_guard_w_hole(self):
        inp = '''
        [i0]
        i1 = int_add(i0, 1)
        guard_true(i0) [i0, None, i1]
        finish(i1)
        '''
        self.reparse(inp)

    def test_debug_merge_point(self):
        inp = '''
        []
        debug_merge_point(0, 0, 0)
        '''
        _, loop, oloop = self.reparse(inp, check_equal=False)
        assert loop.operations[0].getarg(1).getint() == 0
        assert loop.operations[0].getarg(2).getint() == 0
        assert oloop.operations[0].getarg(2)._get_str() == "dupa"

    def test_jit_debug(self):
        inp = '''
        []
        jit_debug('foobar', -1, 5)
        '''
        _, loop, oloop = self.reparse(inp)
        assert loop.operations[0].getarg(0)._get_str() == "foobar"
        assert loop.operations[0].getarg(1).getint() == -1
        assert oloop.operations[0].getarg(0)._get_str() == "foobar"
        assert oloop.operations[0].getarg(1).getint() == -1

    def test_floats(self):
        inp = '''
        [f0]
        f1 = float_add(3.5, f0)
        '''
        _, loop, oloop = self.reparse(inp)
        remap = {}
        for box1, box2 in zip(loop.inputargs, oloop.inputargs):
            assert box1.__class__ == box2.__class__
            remap[box2] = box1
        equaloplists(loop.operations, oloop.operations, remap=remap)

    def test_jump(self):
        namespace = {'target': JitCellToken()}
        namespace['target'].number = 3
        inp = '''
        [i0]
        jump(i0, descr=target)
        '''
        loop = pure_parse(inp, namespace=namespace)
        logger = Logger(self.make_metainterp_sd())
        output = logger.log_loop(loop)
        assert output.splitlines()[-1] == "jump(i0, descr=<Loop3>)"
        pure_parse(output)

    def test_guard_descr(self):
        namespace = {'fdescr': BasicFailDescr()}
        inp = '''
        [i0]
        guard_true(i0, descr=fdescr) [i0]
        '''
        loop = pure_parse(inp, namespace=namespace)
        logger = Logger(self.make_metainterp_sd(), guard_number=True)
        output = logger.log_loop(loop)
        assert re.match("guard_true\(i0, descr=<Guard0x[\da-f]+>\) \[i0\]", output.splitlines()[-1])
        pure_parse(output)

        logger = Logger(self.make_metainterp_sd(), guard_number=False)
        output = logger.log_loop(loop)
        lastline = output.splitlines()[-1]
        assert lastline.startswith("guard_true(i0, descr=<")
        assert not lastline.startswith("guard_true(i0, descr=<Guard")

    def test_intro_loop(self):
        bare_logger = logger.Logger(self.make_metainterp_sd())
        output = capturing(bare_logger.log_loop, [], [], 1, "foo")
        assert output.splitlines()[0] == "# Loop 1 () : foo with 0 ops"
        pure_parse(output)

    def test_intro_bridge(self):
        bare_logger = logger.Logger(self.make_metainterp_sd())
        output = capturing(bare_logger.log_bridge, [], [], 3)
        assert re.match("# bridge out of Guard 0x[\da-f]+ with 0 ops",
                        output.splitlines()[0])
        pure_parse(output)

    def test_repr_single_op(self):
        inp = '''
        [i0, i1, i2, p3, p4, p5]
        i6 = int_add(i1, i2)
        i8 = int_add(i6, 3)
        jump(i0, i8, i6, p3, p4, p5)
        '''
        logger, loop, _ = self.reparse(inp)
        op = loop.operations[1]
        assert logger.logops.repr_of_resop(op) == "i8 = int_add(i6, 3)"

    def test_ops_offset(self):
        inp = '''
        [i0]
        i1 = int_add(i0, 1)
        i2 = int_mul(i1, 2)
        jump(i2)
        '''
        loop = pure_parse(inp)
        ops = loop.operations
        ops_offset = {
            ops[0]: 10,
            ops[2]: 30,
            None: 40
            }
        logger = Logger(self.make_metainterp_sd())
        output = logger.log_loop(loop, ops_offset=ops_offset, name="foo")
        assert output.strip() == """
# Loop 0 (foo) : noopt with 3 ops
[i0]
+10: i2 = int_add(i0, 1)
i4 = int_mul(i2, 2)
+30: jump(i4)
+40: --end of the loop--
""".strip()

    def test_ops_offset_with_forward(self):
        inp = '''
        [i0]
        i1 = int_add(i0, 4)
        i2 = int_mul(i0, 8)
        jump(i2)
        '''
        loop = pure_parse(inp)
        ops = loop.operations

        # again to get new ops with different identities to existing ones
        loop2 = pure_parse(inp)
        ops2 = loop.operations

        # Suppose a re-write occurs which replaces the operations with these.
        # The add 4 became a sub -4. The others are the same, but have a
        # different address, thus still require forwarding.
        inp2 = '''
        [i0]
        i1 = int_sub(i0, -4)
        i2 = int_mul(i0, 8)
        jump(i2)
        '''
        loop2 = pure_parse(inp2)
        ops2 = loop2.operations

        # Add forwarding
        for i in xrange(3):
            ops[i].set_forwarded(ops2[i])

        # So the offsets are keyed by ops2 instances
        ops_offset = {
            ops2[0]: 10,
            ops2[1]: 20,
            ops2[2]: 30,
            None: 40
        }

        logger = Logger(self.make_metainterp_sd())
        output = logger.log_loop(loop, ops_offset=ops_offset, name="foo")

        # The logger should have followed the forwarding pointers
        lines = output.strip().splitlines()
        assert lines[2].startswith("+10")
        assert lines[3].startswith("+20")
        assert lines[4].startswith("+30")
        assert lines[5].startswith("+40")
