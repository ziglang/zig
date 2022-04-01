from rpython.jit.metainterp.history import ConstInt, ConstFloat, ConstPtr
from rpython.jit.metainterp.resoperation import rop, AbstractInputArg
from rpython.rlib.debug import (have_debug_prints, debug_start, debug_stop,
    debug_print)
from rpython.rlib.objectmodel import we_are_translated, compute_unique_id
from rpython.rlib.rarithmetic import r_uint
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi


class Logger(object):
    def __init__(self, metainterp_sd, guard_number=False):
        self.metainterp_sd = metainterp_sd
        self.guard_number = guard_number

    def log_loop_from_trace(self, trace, memo):
        debug_start("jit-log-noopt")
        if not have_debug_prints():
            debug_stop("jit-log-noopt")
            return
        inputargs, ops = self._unpack_trace(trace)
        debug_print("# Traced loop or bridge with", len(ops), "ops")
        logops = self._log_operations(inputargs, ops, None, memo)
        debug_stop("jit-log-noopt")
        return logops

    def _unpack_trace(self, trace):
        ops = []
        i = trace.get_iter()
        while not i.done():
            ops.append(i.next())
        return i.inputargs, ops

    def log_loop(self, inputargs, operations, number=0, type=None,
                 ops_offset=None, name='', memo=None):
        if type is None:
            # XXX this case not normally used any more, I think
            debug_start("jit-log-noopt-loop")
            debug_print("# Loop", number, '(%s)' % name, ":", "noopt",
                        "with", len(operations), "ops")
            logops = self._log_operations(inputargs, operations, ops_offset,
                                          memo)
            debug_stop("jit-log-noopt-loop")
        elif type == "rewritten":
            debug_start("jit-log-rewritten-loop")
            debug_print("# Loop", number, '(%s)' % name, ":", type,
                        "with", len(operations), "ops")
            logops = self._log_operations(inputargs, operations, ops_offset,
                                          memo)
            debug_stop("jit-log-rewritten-loop")
        elif number == -2:
            debug_start("jit-log-compiling-loop")
            logops = self._log_operations(inputargs, operations, ops_offset,
                                          memo)
            debug_stop("jit-log-compiling-loop")
        else:
            debug_start("jit-log-opt-loop")
            debug_print("# Loop", number, '(%s)' % name, ":", type,
                        "with", len(operations), "ops")
            logops = self._log_operations(inputargs, operations, ops_offset,
                                          memo)
            debug_stop("jit-log-opt-loop")
        return logops

    def log_bridge(self, inputargs, operations, extra=None,
                   descr=None, ops_offset=None, memo=None):
        if extra == "noopt":
            # XXX this case no longer used
            debug_start("jit-log-noopt-bridge")
            debug_print("# bridge out of Guard",
                        "0x%x" % compute_unique_id(descr),
                        "with", len(operations), "ops")
            logops = self._log_operations(inputargs, operations, ops_offset,
                                          memo)
            debug_stop("jit-log-noopt-bridge")
        elif extra == "rewritten":
            debug_start("jit-log-rewritten-bridge")
            debug_print("# bridge out of Guard",
                        "0x%x" % compute_unique_id(descr),
                        "with", len(operations), "ops")
            logops = self._log_operations(inputargs, operations, ops_offset,
                                          memo)
            debug_stop("jit-log-rewritten-bridge")
        elif extra == "compiling":
            debug_start("jit-log-compiling-bridge")
            logops = self._log_operations(inputargs, operations, ops_offset,
                                          memo)
            debug_stop("jit-log-compiling-bridge")
        else:
            debug_start("jit-log-opt-bridge")
            debug_print("# bridge out of Guard",
                        "0x%x" % r_uint(compute_unique_id(descr)),
                        "with", len(operations), "ops")
            logops = self._log_operations(inputargs, operations, ops_offset,
                                          memo)
            debug_stop("jit-log-opt-bridge")
        return logops

    def log_short_preamble(self, inputargs, operations, memo=None):
        debug_start("jit-log-short-preamble")
        logops = self._log_operations(inputargs, operations, ops_offset=None,
                                      memo=memo)
        debug_stop("jit-log-short-preamble")
        return logops

    def log_abort_loop(self, trace, memo=None):
        debug_start("jit-abort-log")
        if not have_debug_prints():
            debug_stop("jit-abort-log")
            return
        inputargs, operations = self._unpack_trace(trace)
        logops = self._log_operations(inputargs, operations, ops_offset=None,
                                      memo=memo)
        debug_stop("jit-abort-log")
        return logops

    def _log_operations(self, inputargs, operations, ops_offset, memo=None):
        if not have_debug_prints():
            return None
        logops = self._make_log_operations(memo)
        logops._log_operations(inputargs, operations, ops_offset, memo)
        return logops

    def _make_log_operations(self, memo):
        return LogOperations(self.metainterp_sd, self.guard_number, memo)

    def repr_of_resop(self, op):
        # XXX fish the memo from somewhere
        return LogOperations(self.metainterp_sd, self.guard_number,
                             None).repr_of_resop(op)


class LogOperations(object):
    """
    ResOperation logger.
    """
    def __init__(self, metainterp_sd, guard_number, memo):
        self.metainterp_sd = metainterp_sd
        self.guard_number = guard_number
        if memo is None:
            memo = {}
        self.memo = memo

    def repr_of_descr(self, descr):
        return descr.repr_of_descr()

    def repr_of_arg(self, arg):
        try:
            mv = self.memo[arg]
        except KeyError:
            mv = len(self.memo)
            self.memo[arg] = mv
        if isinstance(arg, ConstInt):
            if int_could_be_an_address(arg.value):
                addr = arg.getaddr()
                name = self.metainterp_sd.get_name_from_address(addr)
                if name:
                    return 'ConstClass(' + name + ')'
            return str(arg.value)
        elif isinstance(arg, ConstPtr):
            if arg.value:
                return 'ConstPtr(ptr' + str(mv) + ')'
            return 'ConstPtr(null)'
        elif isinstance(arg, ConstFloat):
            return str(arg.getfloat())
        elif arg is None:
            return 'None'
        elif arg.is_vector():
            # cannot infer this information, VectorizationInfo
            # might be lost here already
            #vecinfo = arg.get_forwarded()
            #assert isinstance(vecinfo, VectorizationInfo)
            #suffix = '[%dx%s%d]' % (vecinfo.count, vecinfo.datatype, vecinfo.bytesize * 8)
            return 'v' + str(mv)
        elif arg.type == 'i':
            return 'i' + str(mv)
        elif arg.type == 'r':
            return 'p' + str(mv)
        elif arg.type == 'f':
            return 'f' + str(mv)
        else:
            return '?'

    def repr_of_resop(self, op, ops_offset=None):
        if isinstance(op, AbstractInputArg):
            return self.repr_of_arg(op)
        if op.getopnum() == rop.DEBUG_MERGE_POINT:
            jd_sd = self.metainterp_sd.jitdrivers_sd[op.getarg(0).getint()]
            s = jd_sd.warmstate.get_location_str(op.getarglist()[3:])
            s = s.replace(',', '.') # we use comma for argument splitting
            return "debug_merge_point(%d, %d, '%s')" % (op.getarg(1).getint(), op.getarg(2).getint(), s)
        if op.getopnum() == rop.JIT_DEBUG:
            args = op.getarglist()
            s = args[0]._get_str()
            s = s.replace(',', '.') # we use comma for argument splitting
            s2 = ''
            for box in args[1:]:
                if isinstance(box, ConstInt):
                    s2 += ', %d' % box.getint()
                else:
                    s2 += ', box'
            return "jit_debug('%s'%s)" % (s, s2)
        if ops_offset is None:
            offset = -1
        else:
            final_op = op.get_box_replacement()
            offset = ops_offset.get(final_op, -1)
        if offset == -1:
            s_offset = ""
        else:
            s_offset = "+%d: " % offset
        args = ", ".join([self.repr_of_arg(op.getarg(i)) for i in range(op.numargs())])

        if op.type != 'v':
            res = self.repr_of_arg(op) + " = "
        else:
            res = ""
        is_guard = op.is_guard()
        if op.getdescr() is not None:
            descr = op.getdescr()
            if is_guard and self.guard_number:
                hash = r_uint(compute_unique_id(descr))
                r = "<Guard0x%x>" % hash
            else:
                r = self.repr_of_descr(descr)
            if args:
                args += ', descr=' + r
            else:
                args = "descr=" + r
        if is_guard and op.getfailargs() is not None:
            fail_args = ' [' + ", ".join([self.repr_of_arg(arg)
                                          for arg in op.getfailargs()]) + ']'
        else:
            fail_args = ''
        return s_offset + res + op.getopname() + '(' + args + ')' + fail_args


    def _log_operations(self, inputargs, operations, ops_offset=None,
                        memo=None):
        if not have_debug_prints():
            return
        if ops_offset is None:
            ops_offset = {}
        if inputargs is not None:
            args = ", ".join([self.repr_of_arg(arg) for arg in inputargs])
            debug_print('[' + args + ']')
        for i in range(len(operations)):
            #op = operations[i]
            debug_print(self.repr_of_resop(operations[i], ops_offset))
            #if op.getopnum() == rop.LABEL:
            #    self._log_inputarg_setup_ops(op)
        if ops_offset and None in ops_offset:
            offset = ops_offset[None]
            debug_print("+%d: --end of the loop--" % offset)

    def log_loop(self, loop, memo=None):
        self._log_operations(loop.inputargs, loop.operations, memo=memo)

def int_could_be_an_address(x):
    if we_are_translated():
        x = rffi.cast(lltype.Signed, x)       # force it
        return not (-32768 <= x <= 32767)
    else:
        return isinstance(x, llmemory.AddressAsInt)
