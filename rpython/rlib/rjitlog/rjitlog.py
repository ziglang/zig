import py
import sys
import weakref
import struct
import os
import platform
from rpython.rlib import jit
from rpython.tool.udir import udir
from rpython.tool.version import rpythonroot
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.jit.metainterp import resoperation as resoperations
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.metainterp.history import ConstInt, ConstFloat, ConstPtr
from rpython.rlib.rarithmetic import r_longlong
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rlib.objectmodel import compute_unique_id, always_inline
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.jit_hooks import register_helper
from rpython.annotator import model as annmodel


ROOT = py.path.local(rpythonroot).join('rpython', 'rlib', 'rjitlog')
SRC = ROOT.join('src')
test_jitlog_name = 'JITLOG_FORTESTS'

_libs = []
if sys.platform.startswith('linux'):
    _libs = ['dl']
eci_kwds = dict(
    include_dirs = [SRC],
    includes = ['rjitlog.h'],
    libraries = _libs,
    separate_module_files = [SRC.join('rjitlog.c')],
    # XXX this appears to be no longer used:
    post_include_bits=['#define RPYTHON_JITLOG\n'],
    )
eci = ExternalCompilationInfo(**eci_kwds)

# jit log functions
jitlog_init = rffi.llexternal("jitlog_init", [rffi.INT],
                              rffi.CCHARP, compilation_info=eci)
jitlog_try_init_using_env = rffi.llexternal("jitlog_try_init_using_env",
                              [], lltype.Void, compilation_info=eci)
jitlog_write_marked = rffi.llexternal("jitlog_write_marked",
                              [rffi.CCHARP, rffi.INT],
                              lltype.Void, compilation_info=eci,
                              releasegil=False)
jitlog_enabled = rffi.llexternal("jitlog_enabled", [], rffi.INT,
                                 compilation_info=eci,
                                 releasegil=False)
jitlog_teardown = rffi.llexternal("jitlog_teardown", [], lltype.Void,
                                  compilation_info=eci)

class JitlogError(Exception):
    def __init__(self, msg):
        self.msg = msg
    def __str__(self):
        return self.msg

@register_helper(None)
def stats_flush_trace_counts(warmrunnerdesc):
    if not we_are_translated():
        return # first param is None untranslated
    warmrunnerdesc.metainterp_sd.cpu.assembler.flush_trace_counters()

@jit.dont_look_inside
def enable_jitlog(fileno):
    # initialize the jit log
    p_error = jitlog_init(fileno)
    if p_error:
        raise JitlogError(rffi.charp2str(p_error))
    blob = assemble_header()
    jitlog_write_marked(MARK_JITLOG_HEADER + blob, len(blob) + 1)

def disable_jitlog():
    stats_flush_trace_counts(None)
    jitlog_teardown()


def commonprefix(a,b):
    "Given a list of pathnames, returns the longest common leading component"
    assert a is not None
    assert b is not None
    la = len(a)
    lb = len(b)
    c = min(la,lb)
    if c == 0:
        return ""
    for i in range(c):
        if a[i] != b[i]:
            return a[:i] # partly matching
    return a # full match

@always_inline
def encode_str(string):
    val = len(string)
    return ''.join([chr((val >> 0) & 0xff),
                    chr((val >> 8) & 0xff),
                    chr((val >> 16) & 0xff),
                    chr((val >> 24) & 0xff),
                    string])

@always_inline
def encode_le_16bit(val):
    return chr((val >> 0) & 0xff) + chr((val >> 8) & 0xff)

@always_inline
def encode_le_32bit(val):
    return ''.join([chr((val >> 0) & 0xff),
                    chr((val >> 8) & 0xff),
                    chr((val >> 16) & 0xff),
                    chr((val >> 24) & 0xff)])

@always_inline
def encode_le_64bit(val):
    val = r_longlong(val)     # force 64-bit, even on 32-bit
    return ''.join([chr((val >> 0) & 0xff),
                    chr((val >> 8) & 0xff),
                    chr((val >> 16) & 0xff),
                    chr((val >> 24) & 0xff),
                    chr((val >> 32) & 0xff),
                    chr((val >> 40) & 0xff),
                    chr((val >> 48) & 0xff),
                    chr((val >> 56)& 0xff)])

@always_inline
def encode_le_addr(val):
    if IS_32_BIT:
        return encode_le_32bit(val)
    else:
        return encode_le_64bit(val)

def encode_type(type, value):
    if type == "s":
        return encode_str(value)
    elif type == "q":
        return encode_le_64bit(value)
    elif type == "i":
        return encode_le_32bit(value)
    elif type == "h":
        return encode_le_16bit(value)
    else:
        raise NotImplementedError

# more variable parameters
MP_STR = (0x0, "s")
MP_INT = (0x0, "i")

# concrete parameters
MP_FILENAME = (0x1, "s")
MP_LINENO = (0x2, "i")
MP_INDEX = (0x4, "i")
MP_SCOPE = (0x8, "s")
MP_OPCODE = (0x10, "s")

class WrappedValue(object):
    def encode(self, log, i, compressor):
        raise NotImplementedError

class StringValue(WrappedValue):
    def __init__(self, sem_type, gen_type, value):
        self.value = value

    def encode(self, log, i, compressor):
        str_value = self.value
        last_prefix = compressor.get_last_written(i)
        cp = compressor.compress(i, str_value)
        if cp is None:
            return b'\xff' + encode_str(str_value)

        else:
            cp_len = len(cp)
            if cp == last_prefix:
                # we have the same prefix
                pass
            else:
                compressor.write(log, i, cp)
        if len(str_value) == len(cp):
            return b'\xef'
        return b'\x00' + encode_str(str_value[len(cp):])

class IntValue(WrappedValue):
    def __init__(self, sem_type, gen_type, value):
        self.value = value

    def encode(self, log, i, prefixes):
        return b'\x00' + encode_le_64bit(self.value)

# note that a ...
# "semantic_type" is an integer denoting which meaning does a type at a merge point have
#                 there are very common ones that are predefined. E.g. MP_FILENAME
# "generic_type" is one of the primitive types supported (string,int)

@specialize.argtype(2)
def wrap(sem_type, gen_type, value):
    if isinstance(value, int):
        return IntValue(sem_type, gen_type, value)
    elif isinstance(value, str):
        return StringValue(sem_type, gen_type, value)
    raise NotImplementedError

def returns(*args):
    """ Decorate your get_location function to specify the types.
        Use MP_* constant as parameters. An example impl for get_location
        would return the following:

        @returns(MP_FILENAME, MP_LINENO)
        def get_location(...):
            return ("a.py", 0)
    """
    def decor(method):
        method._loc_types = args
        return method
    return decor

JITLOG_VERSION = 4
JITLOG_VERSION_16BIT_LE = struct.pack("<H", JITLOG_VERSION)

marks = [
    ('INPUT_ARGS',),
    ('RESOP_META',),
    ('RESOP',),
    ('RESOP_DESCR',),
    ('ASM_ADDR',),
    ('ASM',),

    # which type of trace is logged after this
    # the trace as it is recorded by the tracer
    ('TRACE',),
    # the trace that has passed the optimizer
    ('TRACE_OPT',),
    # the trace assembled to machine code (after rewritten)
    ('TRACE_ASM',),

    # the machine code was patched (e.g. guard)
    ('STITCH_BRIDGE',),

    ('START_TRACE',),

    ('JITLOG_COUNTER',),
    ('INIT_MERGE_POINT',),

    ('JITLOG_HEADER',),
    ('MERGE_POINT',),
    ('COMMON_PREFIX',),
    ('ABORT_TRACE',),
    ('SOURCE_CODE',),
    ('REDIRECT_ASSEMBLER',),
    ('TMP_CALLBACK',),
]

start = 0x11
for mark, in marks:
    globals()['MARK_' + mark] = chr(start)
    start += 1

if __name__ == "__main__":
    print("# generated constants from rpython/rlib/jitlog.py")
    print('import struct')
    print('MARK_JITLOG_START = struct.pack("b", %s)' % hex(0x10))
    for mark, in marks:
        nmr = globals()['MARK_' + mark]
        h = hex(ord(nmr))
        print '%s = struct.pack("b", %s)' % ('MARK_' + mark, h)
    print 'MARK_JITLOG_END = struct.pack("b", %s)' % hex(start)
    for key,value in locals().items():
        if key.startswith("MP_"):
            print '%s = (%s,"%s")' % (key, hex(value[0]), value[1])
    print 'SEM_TYPE_NAMES = {'
    for key,value in locals().items():
        if key.startswith("MP_") and value[0] != 0:
            print '    %s: "%s",' % (hex(value[0]), key[3:].lower())
    print '}'

MP_STR = (0x0, "s")
MP_INT = (0x0, "i")

# concrete parameters
MP_FILENAME = (0x1, "s")
MP_LINENO = (0x2, "i")
MP_INDEX = (0x4, "i")
MP_SCOPE = (0x8, "s")
MP_OPCODE = (0x10, "s")

del marks
del start

IS_32_BIT = sys.maxint == 2**31-1

MACHINE_NAME = platform.machine()

def assemble_header():
    version = JITLOG_VERSION_16BIT_LE
    count = len(resoperations.opname)
    is_32bit = chr(0x1)
    if not IS_32_BIT:
        is_32bit = chr(0x0)
    content = [version, is_32bit, encode_str(MACHINE_NAME),
               MARK_RESOP_META, encode_le_16bit(count)]
    for opnum, opname in resoperations.opname.items():
        content.append(encode_le_16bit(opnum))
        content.append(encode_str(opname.lower()))
    return ''.join(content)

def _log_jit_counter(struct):
    if not jitlog_enabled():
        return
    # addr is either a number (trace_id), or the address
    # of the descriptor. for entries it is a the trace_id,
    # for any label/bridge entry the addr is the address
    list = [MARK_JITLOG_COUNTER, encode_le_addr(struct.number),
            struct.type, encode_le_64bit(struct.i)]
    content = ''.join(list)
    jitlog_write_marked(content, len(content))

def redirect_assembler(oldtoken, newtoken, asm_adr):
    if not jitlog_enabled():
        return
    descr_nmr = compute_unique_id(oldtoken)
    new_descr_nmr = compute_unique_id(newtoken)
    list = [MARK_REDIRECT_ASSEMBLER, encode_le_addr(descr_nmr),
            encode_le_addr(new_descr_nmr), encode_le_addr(asm_adr)]
    content = ''.join(list)
    jitlog_write_marked(content, len(content))

def tmp_callback(looptoken):
    mark_tmp_callback = ''.join([
        MARK_TMP_CALLBACK,
        encode_le_addr(compute_unique_id(looptoken)),
        encode_le_64bit(looptoken.number)])
    jitlog_write_marked(mark_tmp_callback, len(mark_tmp_callback))

class JitLogger(object):
    def __init__(self, cpu=None):
        self.cpu = cpu
        self.memo = {}
        self.trace_id = 0
        self.metainterp_sd = None
        # legacy
        self.logger_ops = None
        self.logger_noopt = None

    def setup_once(self):
        if jitlog_enabled():
            return
        jitlog_try_init_using_env()
        if not jitlog_enabled():
            return
        blob = assemble_header()
        jitlog_write_marked(MARK_JITLOG_HEADER + blob, len(blob) + 1)

    def finish(self):
        jitlog_teardown()

    def next_id(self):
        self.trace_id += 1
        return self.trace_id

    def start_new_trace(self, metainterp_sd, faildescr=None, entry_bridge=False, jd_name=""):
        # even if the logger is not enabled, increment the trace id
        self.trace_id += 1
        if not jitlog_enabled():
            return
        self.metainterp_sd = metainterp_sd
        content = [encode_le_addr(self.trace_id)]
        if faildescr:
            content.append(encode_str('bridge'))
            descrnmr = compute_unique_id(faildescr)
            content.append(encode_le_addr(descrnmr))
        else:
            content.append(encode_str('loop'))
            content.append(encode_le_addr(int(entry_bridge)))
        content.append(encode_str(jd_name))
        self._write_marked(MARK_START_TRACE, ''.join(content))

    def trace_aborted(self):
        if not jitlog_enabled():
            return
        self._write_marked(MARK_ABORT_TRACE, encode_le_addr(self.trace_id))

    def _write_marked(self, mark, line):
        if not we_are_translated():
            assert jitlog_enabled()
        jitlog_write_marked(mark + line, len(line) + 1)

    def log_jit_counter(self, struct):
        _log_jit_counter(struct)

    def log_trace(self, tag, metainterp_sd, mc, memo=None):
        if not jitlog_enabled():
            return EMPTY_TRACE_LOG
        assert self.metainterp_sd is not None
        if memo is None:
            memo = {}
        return LogTrace(tag, memo, self.metainterp_sd, mc, self)

    def log_patch_guard(self, descr_number, addr):
        if not jitlog_enabled():
            return
        le_descr_number = encode_le_addr(descr_number)
        le_addr = encode_le_addr(addr)
        lst = [le_descr_number, le_addr]
        self._write_marked(MARK_STITCH_BRIDGE, ''.join(lst))

class BaseLogTrace(object):
    def write_trace(self, trace):
        return None

    def write(self, args, ops, ops_offset={}):
        return None

EMPTY_TRACE_LOG = BaseLogTrace()

class PrefixCompressor(object):
    def __init__(self, count):
        self.prefixes = [None] * count
        self.written_prefixes = [None] * count

    def get_last(self, index):
        return self.prefixes[index]

    def get_last_written(self, index):
        return self.written_prefixes[index]

    def compress(self, index, string):
        assert string is not None
        last = self.get_last(index)
        if last is None:
            self.prefixes[index] = string
            return None
        cp = commonprefix(last, string)
        if len(cp) <= 1: # prevent very small common prefixes (like "/")
            self.prefixes[index] = string
            return None
        return cp


    def write(self, log, index, prefix):
        # we have a new prefix
        log._write_marked(MARK_COMMON_PREFIX, chr(index) \
                                          + encode_str(prefix))
        self.written_prefixes[index] = prefix

def encode_merge_point(log, compressor, values):
    line = []
    i = 0
    for value in values:
        line.append(value.encode(log,i,compressor))
        i += 1
    return ''.join(line)


class LogTrace(BaseLogTrace):
    def __init__(self, tag, memo, metainterp_sd, mc, logger):
        self.memo = memo
        self.metainterp_sd = metainterp_sd
        self.tag = tag
        self.mc = mc
        self.logger = logger
        self.common_prefix = None

    def write_trace(self, trace):
        ops = []
        i = trace.get_iter()
        while not i.done():
            ops.append(i.next())
        self.write(i.inputargs, ops)

    def write(self, args, ops, ops_offset={}):
        log = self.logger
        tid = self.logger.trace_id
        log._write_marked(self.tag, encode_le_addr(tid))

        # input args
        str_args = [self.var_to_str(arg) for arg in args]
        string = encode_str(','.join(str_args))
        log._write_marked(MARK_INPUT_ARGS, string)

        # assembler address (to not duplicate it in write_code_dump)
        if self.mc is not None:
            absaddr = self.mc.absolute_addr()
            rel = self.mc.get_relative_pos()
            # packs <start addr> <end addr> as two unsigend longs
            le_addr1 = encode_le_addr(absaddr)
            le_addr2 = encode_le_addr(absaddr + rel)
            log._write_marked(MARK_ASM_ADDR, le_addr1 + le_addr2)
        for i,op in enumerate(ops):
            if rop.DEBUG_MERGE_POINT == op.getopnum():
                self.encode_debug_info(op)
                continue
            mark, line = self.encode_op(op)
            log._write_marked(mark, line)
            self.write_core_dump(ops, i, op, ops_offset)

        self.memo = {}

    def encode_once(self):
        pass

    def encode_debug_info(self, op):
        # the idea is to write the debug merge point as it's own well known
        # tag. Compression for common prefixes is implemented:

        log = self.logger
        jd_sd = self.metainterp_sd.jitdrivers_sd[op.getarg(0).getint()]
        if not jd_sd.warmstate.get_location:
            return
        values = jd_sd.warmstate.get_location(op.getarglist()[3:])
        if values is None:
            # indicates that this function is not provided to the jit driver
            return
        types = jd_sd.warmstate.get_location_types

        if self.common_prefix is None:
            # first time visiting a merge point
            # setup the common prefix
            self.common_prefix = PrefixCompressor(len(types))
            encoded_types = []
            for i, (semantic_type, generic_type) in enumerate(types):
                encoded_types.append(chr(semantic_type))
                encoded_types.append(generic_type)
            count = encode_le_16bit(len(types))
            log._write_marked(MARK_INIT_MERGE_POINT, count + ''.join(encoded_types))

        # the types have already been written
        encoded = encode_merge_point(log, self.common_prefix, values)
        log._write_marked(MARK_MERGE_POINT, encoded)

    def encode_op(self, op):
        """ an operation is written as follows:
            <marker> <opid (16 bit)> \
                     <len (32 bit)> \
                     <res_val>,<arg_0>,...,<arg_n> \
                     <descr>
                     <failarg_0>,...<failarg_n>
            The marker indicates if the last argument is
            a descr or a normal argument.
        """
        str_args = [self.var_to_str(arg) for arg in op.getarglist()]
        descr = op.getdescr()
        le_opnum = encode_le_16bit(op.getopnum())
        str_res = self.var_to_str(op)
        line = ','.join([str_res] + str_args)
        failargslist = op.getfailargs()
        failargs = ''
        if failargslist:
            failargs = ','.join([self.var_to_str(farg) for farg in failargslist])
        #
        if descr:
            descr_str = descr.repr_of_descr()
            line = line + ',' + descr_str
            string = encode_str(line)
            descr_number = compute_unique_id(descr)
            le_descr_number = encode_le_addr(descr_number)
            return MARK_RESOP_DESCR, le_opnum + string + le_descr_number + encode_str(failargs)
        else:
            string = encode_str(line)
            return MARK_RESOP, le_opnum + string + encode_str(failargs)


    def write_core_dump(self, operations, i, op, ops_offset):
        if self.mc is None:
            return

        op2 = None
        j = i+1
        # find the next op that is in the offset hash
        while j < len(operations):
            op2 = operations[j]
            if op in ops_offset:
                break
            j += 1

        # this op has no known offset in the machine code (it might be
        # a debug operation)
        if op not in ops_offset:
            return
        # there is no well defined boundary for the end of the
        # next op in the assembler
        if op2 is not None and op2 not in ops_offset:
            return
        dump = []

        start_offset = ops_offset[op]
        assert start_offset >= 0
        # end offset is either the last pos in the assembler
        # or the offset of op2
        if op2 is None:
            end_offset = self.mc.get_relative_pos()
        else:
            end_offset = ops_offset[op2]

        count = end_offset - start_offset
        dump = self.copy_core_dump(self.mc.absolute_addr(), start_offset, count)
        offset = encode_le_16bit(start_offset)
        edump = encode_str(dump)
        self.logger._write_marked(MARK_ASM, offset + edump)

    def copy_core_dump(self, addr, offset=0, count=-1):
        dump = []
        src = rffi.cast(rffi.CCHARP, addr)
        end = self.mc.get_relative_pos()
        if count != -1:
            end = offset + count
        for p in range(offset, end):
            dump.append(src[p])
        return ''.join(dump)

    def var_to_str(self, arg):
        if arg is None:
            return '-'
        try:
            mv = self.memo[arg]
        except KeyError:
            mv = len(self.memo)
            self.memo[arg] = mv
        if isinstance(arg, ConstInt):
            if self.metainterp_sd and int_could_be_an_address(arg.value):
                addr = arg.getaddr()
                name = self.metainterp_sd.get_name_from_address(addr)
                if name:
                    return 'ConstClass(' + name + ')'
            return str(arg.value)
        elif isinstance(arg, ConstPtr):
            if arg.value:
                return 'ConstPtr(ptr' + str(mv) + ')'
            return 'ConstPtr(null)'
        if isinstance(arg, ConstFloat):
            return str(arg.getfloat())
        elif arg is None:
            return 'None'
        elif arg.is_vector():
            return 'v' + str(mv)
        elif arg.type == 'i':
            return 'i' + str(mv)
        elif arg.type == 'r':
            return 'p' + str(mv)
        elif arg.type == 'f':
            return 'f' + str(mv)
        else:
            return '?'

def int_could_be_an_address(x):
    if we_are_translated():
        x = rffi.cast(lltype.Signed, x)       # force it
        return not (-32768 <= x <= 32767)
    else:
        return isinstance(x, llmemory.AddressAsInt)
