import pytest
import sys
from rpython.jit.metainterp.resoperation import ResOperation, rop
from rpython.jit.metainterp.history import ConstInt
from rpython.rlib.rjitlog import rjitlog as jl
from rpython.jit.metainterp.history import AbstractDescr
from rpython.rlib.objectmodel import compute_unique_id
from rpython.rlib.rfile import create_file
from rpython.rlib.rposix import SuppressIPH

class FakeCallAssemblerLoopToken(AbstractDescr):
    def __init__(self, target):
        self._ll_function_addr = target

    def repr_of_descr(self):
        return 'looptoken'

class FakeLog(object):
    def __init__(self):
        self.values = []

    def _write_marked(self, id, text):
        self.values.append(id + text)

def _get_location(greenkey_list):
    assert len(greenkey_list) == 0
    return '/home/pypy/jit.py', 0, 'enclosed', 99, 'DEL'

class FakeJitDriver(object):
    class warmstate(object):
        get_location_types = [jl.MP_FILENAME,jl.MP_INT,jl.MP_SCOPE, jl.MP_INT, jl.MP_OPCODE]
        @staticmethod
        def get_location(greenkey_list):
            return [jl.wrap(jl.MP_FILENAME[0],'s','/home/pypy/jit.py'),
                    jl.wrap(jl.MP_INT[0], 'i', 0),
                    jl.wrap(jl.MP_SCOPE[0], 's', 'enclosed'),
                    jl.wrap(jl.MP_INT[0], 'i', 99),
                    jl.wrap(jl.MP_OPCODE[0], 's', 'DEL')
                    ]


class FakeMetaInterpSd:
    jitdrivers_sd = [FakeJitDriver()]
    def get_name_from_address(self, addr):
        return 'Name'

@pytest.fixture
def metainterp_sd():
    return FakeMetaInterpSd()

class TestLogger(object):
    def test_debug_merge_point(self, tmpdir, metainterp_sd):
        logger = jl.JitLogger()
        file = tmpdir.join('binary_file')
        file.ensure()
        # use rfile instead of file.open since the host python and compiled
        # code may use different runtime libraries (win32 visual2008 vs.
        # visual2019 for instance
        rfile = create_file(str(file), 'wb')
        with SuppressIPH():
            jl.jitlog_init(rfile.fileno())
            logger.start_new_trace(metainterp_sd, jd_name='jdname')
            log_trace = logger.log_trace(jl.MARK_TRACE, None, None)
            op = ResOperation(rop.DEBUG_MERGE_POINT, [ConstInt(0), ConstInt(0), ConstInt(0)])
            log_trace.write([], [op])
            #the next line will close the 'fd', instead of logger.finish()
            rfile.close()
        binary = file.read()
        is_32bit = chr(sys.maxint == 2**31-1)
        assert binary == (jl.MARK_START_TRACE) + jl.encode_le_addr(1) + \
                         jl.encode_str('loop') + jl.encode_le_addr(0) + \
                         jl.encode_str('jdname') + \
                         (jl.MARK_TRACE) + jl.encode_le_addr(1) + \
                         (jl.MARK_INPUT_ARGS) + jl.encode_str('') + \
                         (jl.MARK_INIT_MERGE_POINT) + b'\x05\x00\x01s\x00i\x08s\x00i\x10s' + \
                         (jl.MARK_MERGE_POINT) + \
                         b'\xff' + jl.encode_str('/home/pypy/jit.py') + \
                         b'\x00' + jl.encode_le_64bit(0) + \
                         b'\xff' + jl.encode_str('enclosed') + \
                         b'\x00' + jl.encode_le_64bit(99) + \
                         b'\xff' + jl.encode_str('DEL')

    def test_common_prefix(self):
        fakelog = FakeLog()
        compressor = jl.PrefixCompressor(1)
        # nothing to compress yet!
        result = jl.encode_merge_point(fakelog, compressor, [jl.StringValue(0x0,'s','hello')])
        assert result == b"\xff\x05\x00\x00\x00hello"
        assert fakelog.values == []
        #
        result = jl.encode_merge_point(fakelog, compressor, [jl.StringValue(0x0,'s','hello')])
        assert result == b"\xef"
        assert fakelog.values == [(jl.MARK_COMMON_PREFIX) + "\x00\x05\x00\x00\x00hello"]
        #
        fakelog.values = []
        result = jl.encode_merge_point(fakelog, compressor, [jl.StringValue(0x0,'s','heiter')])
        assert result == b"\x00\x04\x00\x00\x00iter"
        assert fakelog.values == [(jl.MARK_COMMON_PREFIX) + "\x00\x02\x00\x00\x00he"]
        #
        fakelog.values = []
        result = jl.encode_merge_point(fakelog, compressor, [jl.StringValue(0x0,'s','heute')])
        assert result == b"\x00\x03\x00\x00\x00ute"
        assert fakelog.values == []
        #
        fakelog.values = []
        result = jl.encode_merge_point(fakelog, compressor, [jl.StringValue(0x0,'s','welt')])
        assert result == b"\xff\x04\x00\x00\x00welt"
        assert fakelog.values == []
        #
        fakelog.values = []
        result = jl.encode_merge_point(fakelog, compressor, [jl.StringValue(0x0,'s','welle')])
        assert result == b"\x00\x02\x00\x00\x00le"
        assert fakelog.values == [(jl.MARK_COMMON_PREFIX) + "\x00\x03\x00\x00\x00wel"]

    def test_common_prefix_func(self):
        assert jl.commonprefix("","") == ""
        assert jl.commonprefix("/hello/world","/path/to") == "/"
        assert jl.commonprefix("pyramid","python") == "py"
        assert jl.commonprefix("0"*100,"0"*100) == "0"*100
        with pytest.raises(AssertionError):
            jl.commonprefix(None,None)

    def test_redirect_assembler(self, tmpdir, metainterp_sd):
        looptoken = FakeCallAssemblerLoopToken(0x0)
        newlooptoken = FakeCallAssemblerLoopToken(0x1234)
        #
        logger = jl.JitLogger()
        file = tmpdir.join('binary_file')
        file.ensure()
        # use rfile instead of file.open since the host python and compiled
        # code may use different runtime libraries (win32 visual2008 vs.
        # visual2019 for instance
        rfile = create_file(str(file), 'wb')
        with SuppressIPH():
            jl.jitlog_init(rfile.fileno())
            logger.start_new_trace(metainterp_sd, jd_name='jdname')
            log_trace = logger.log_trace(jl.MARK_TRACE, None, None)
            op = ResOperation(rop.CALL_ASSEMBLER_I, [], descr=looptoken)
            log_trace.write([], [op])
            jl.redirect_assembler(looptoken, newlooptoken, 0x1234)
            #the next line will close the 'fd', instead of logger.finish()
            rfile.close()
        binary = file.read()
        opnum = jl.encode_le_16bit(rop.CALL_ASSEMBLER_I)
        id_looptoken = compute_unique_id(looptoken)
        new_id_looptoken = compute_unique_id(newlooptoken)
        end = jl.MARK_RESOP_DESCR + opnum + jl.encode_str('i0,looptoken') + \
              jl.encode_le_addr(id_looptoken) + jl.encode_str('') + \
              jl.MARK_REDIRECT_ASSEMBLER + \
              jl.encode_le_addr(id_looptoken) + \
              jl.encode_le_addr(new_id_looptoken) + \
              jl.encode_le_addr(newlooptoken._ll_function_addr)
        assert binary.endswith(end)
