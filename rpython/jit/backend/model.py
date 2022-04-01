import weakref
from rpython.rlib.debug import debug_start, debug_print, debug_stop
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.rclass import OBJECTPTR
from rpython.jit.metainterp.history import ConstInt
from rpython.jit.metainterp.support import ptr2int

class CPUTotalTracker(object):
    total_compiled_loops = 0
    total_compiled_bridges = 0
    total_freed_loops = 0
    total_freed_bridges = 0

class AbstractCPU(object):
    supports_floats = False
    supports_longlong = False
    # ^^^ This is only useful on 32-bit platforms.  If True,
    # longlongs are supported by the JIT, but stored as doubles.
    # Boxes and Consts are BoxFloats and ConstFloats.
    supports_singlefloats = False
    supports_guard_gc_type = False
    supports_load_effective_address = False

    propagate_exception_descr = None

    remove_gctypeptr = False

    def __init__(self):
        self.tracker = CPUTotalTracker()

    def _freeze_(self):
        return True

    def setup_once(self):
        """Called once by the front-end when the program starts."""
        pass

    def finish_once(self):
        """Called once by the front-end when the program stops."""
        pass

    def get_all_loop_runs(self):
        """ Function that will return number of times all the loops were run.
        Requires earlier setting of set_debug(True), otherwise you won't
        get the information.

        Returns an instance of LOOP_RUN_CONTAINER from rlib.jit_hooks
        """
        raise NotImplementedError

    def set_debug(self, value):
        """ Enable or disable debugging info. Does nothing by default. Returns
        the previous setting.
        """
        return False

    def compile_loop(self, inputargs, operations, looptoken, jd_id=0,
                     unique_id=0, log=True, name='', logger=None):
        """Assemble the given loop.
        Should create and attach a fresh CompiledLoopToken to
        looptoken.compiled_loop_token and stick extra attributes
        on it to point to the compiled loop in assembler.
        Returns either None or an instance of rpython.rlib.jit.AsmInfo.
        """
        raise NotImplementedError

    def compile_bridge(self, faildescr, inputargs, operations,
                       original_loop_token, log=True, logger=None):
        """Assemble the bridge.
        The FailDescr is the descr of the original guard that failed.
        Returns either None or an instance of rpython.rlib.jit.AsmInfo.
        """
        raise NotImplementedError

    def dump_loop_token(self, looptoken):
        """Print a disassembled version of looptoken to stdout"""
        raise NotImplementedError

    def execute_token(self, looptoken, *args):
        """NOT_RPYTHON (for tests only)
        Execute the generated code referenced by the looptoken.
        When done, this returns a 'dead JIT frame' object that can
        be inspected with the get_latest_xxx() methods.
        """
        argtypes = [lltype.typeOf(x) for x in args]
        execute = self.make_execute_token(*argtypes)
        return execute(looptoken, *args)

    def make_execute_token(self, *argtypes):
        """Must make and return an execute_token() function that will be
        called with the given argtypes.
        """
        raise NotImplementedError

    def get_latest_descr(self, deadframe):
        """Returns the Descr for the last operation executed by the frame."""
        raise NotImplementedError

    def get_int_value(self, deadframe, index):
        """Returns the value for the index'th argument to the
        last executed operation (from 'fail_args' if it was a guard,
        or from 'args' if it was a FINISH).  Returns an int."""
        raise NotImplementedError

    def get_float_value(self, deadframe, index):
        """Returns the value for the index'th argument to the
        last executed operation (from 'fail_args' if it was a guard,
        or from 'args' if it was a FINISH).  Returns a FLOATSTORAGE."""
        raise NotImplementedError

    def get_ref_value(self, deadframe, index):
        """Returns the value for the index'th argument to the
        last executed operation (from 'fail_args' if it was a guard,
        or from 'args' if it was a FINISH).  Returns a GCREF."""
        raise NotImplementedError

    def grab_exc_value(self, deadframe):
        """Return the exception set by the latest execute_token(),
        when it exits due to a failure of a GUARD_EXCEPTION or
        GUARD_NO_EXCEPTION.  (Returns a GCREF)"""        # XXX remove me
        raise NotImplementedError

    def set_savedata_ref(self, deadframe, data):
        """For the front-end: store a GCREF on the deadframe object."""
        raise NotImplementedError

    def get_savedata_ref(self, deadframe):
        """For the front-end: get the GCREF saved with set_savedata_ref()."""
        raise NotImplementedError

    def force(self, force_token):
        """Take a 'force token' as produced by the FORCE_TOKEN operation,
        and 'kill' the corresponding JIT frame, which should be somewhere
        in the stack right now.  Returns it as a dead frame object.  When
        we later return to the JIT frame, the next operation executed must
        be a GUARD_NOT_FORCED, which will fail."""
        raise NotImplementedError

    def redirect_call_assembler(self, oldlooptoken, newlooptoken):
        """Redirect oldlooptoken to newlooptoken.  More precisely, it is
        enough to redirect all CALL_ASSEMBLERs already compiled that call
        oldlooptoken so that from now own they will call newlooptoken."""
        raise NotImplementedError

    def invalidate_loop(self, looptoken):
        """Activate all GUARD_NOT_INVALIDATED in the loop and its attached
        bridges.  Before this call, all GUARD_NOT_INVALIDATED do nothing;
        after this call, they all fail.  Note that afterwards, if one such
        guard fails often enough, it has a bridge attached to it; it is
        possible then to re-call invalidate_loop() on the same looptoken,
        which must invalidate all newer GUARD_NOT_INVALIDATED, but not the
        old one that already has a bridge attached to it."""
        raise NotImplementedError

    def free_loop_and_bridges(self, compiled_loop_token):
        """This method is called to free resources (machine code,
        references to resume guards, etc.) allocated by the compilation
        of a loop and all bridges attached to it.  After this call, the
        frontend cannot use this compiled loop any more; in fact, it
        guarantees that at the point of the call to free_code_group(),
        none of the corresponding assembler is currently running.
        """
        pass

    def sizeof(self, S):
        raise NotImplementedError

    def fielddescrof(self, S, fieldname):
        """Return the Descr corresponding to field 'fieldname' on the
        structure 'S'.  It is important that this function (at least)
        caches the results."""
        raise NotImplementedError

    def interiorfielddescrof(self, A, fieldname):
        raise NotImplementedError

    def arraydescrof(self, A):
        raise NotImplementedError

    def calldescrof(self, FUNC, ARGS, RESULT, extrainfo):
        # FUNC is the original function type, but ARGS is a list of types
        # with Voids removed
        raise NotImplementedError

    def typedescrof(self, TYPE):
        raise NotImplementedError

    def unpack_arraydescr_size(self, arraydescr):
        """
        Return basesize, itemsize, is_signed
        """
        raise NotImplementedError

    @staticmethod
    def cast_int_to_ptr(x, TYPE):
        x = llmemory.cast_int_to_adr(x)
        return llmemory.cast_adr_to_ptr(x, TYPE)

    def cls_of_box(self, box):
        obj = lltype.cast_opaque_ptr(OBJECTPTR, box.getref_base())
        return ConstInt(ptr2int(obj.typeptr))


    # ---------- the backend-dependent operations ----------

    # lltype specific operations
    # --------------------------

    def bh_getarrayitem_gc_i(self, array, index, arraydescr):
        raise NotImplementedError
    def bh_getarrayitem_gc_r(self, array, index, arraydescr):
        raise NotImplementedError
    def bh_getarrayitem_gc_f(self, array, index, arraydescr):
        raise NotImplementedError

    def bh_getfield_gc_i(self, struct, fielddescr):
        raise NotImplementedError
    def bh_getfield_gc_r(self, struct, fielddescr):
        raise NotImplementedError
    def bh_getfield_gc_f(self, struct, fielddescr):
        raise NotImplementedError

    def bh_getfield_raw_i(self, struct, fielddescr):
        raise NotImplementedError
    def bh_getfield_raw_r(self, struct, fielddescr):
        raise NotImplementedError
    def bh_getfield_raw_f(self, struct, fielddescr):
        raise NotImplementedError

    def bh_new(self, sizedescr):
        raise NotImplementedError
    def bh_new_with_vtable(self, vtable, sizedescr):
        raise NotImplementedError
    def bh_new_array(self, length, arraydescr):
        raise NotImplementedError
    def bh_newstr(self, length):
        raise NotImplementedError
    def bh_newunicode(self, length):
        raise NotImplementedError

    def bh_arraylen_gc(self, array, arraydescr):
        raise NotImplementedError

    def bh_classof(self, struct):
        raise NotImplementedError

    def bh_setarrayitem_gc_i(self, array, index, newvalue, arraydescr):
        raise NotImplementedError
    def bh_setarrayitem_gc_r(self, array, index, newvalue, arraydescr):
        raise NotImplementedError
    def bh_setarrayitem_gc_f(self, array, index, newvalue, arraydescr):
        raise NotImplementedError

    def bh_setfield_gc_i(self, struct, newvalue, fielddescr):
        raise NotImplementedError
    def bh_setfield_gc_r(self, struct, newvalue, fielddescr):
        raise NotImplementedError
    def bh_setfield_gc_f(self, struct, newvalue, fielddescr):
        raise NotImplementedError

    def bh_setfield_raw_i(self, struct, newvalue, fielddescr):
        raise NotImplementedError
    def bh_setfield_raw_f(self, struct, newvalue, fielddescr):
        raise NotImplementedError

    def bh_call_i(self, func, args_i, args_r, args_f, calldescr):
        raise NotImplementedError
    def bh_call_r(self, func, args_i, args_r, args_f, calldescr):
        raise NotImplementedError
    def bh_call_f(self, func, args_i, args_r, args_f, calldescr):
        raise NotImplementedError
    def bh_call_v(self, func, args_i, args_r, args_f, calldescr):
        raise NotImplementedError

    def bh_strlen(self, string):
        raise NotImplementedError
    def bh_strgetitem(self, string, index):
        raise NotImplementedError
    def bh_unicodelen(self, string):
        raise NotImplementedError
    def bh_unicodegetitem(self, string, index):
        raise NotImplementedError
    def bh_strsetitem(self, string, index, newvalue):
        raise NotImplementedError
    def bh_unicodesetitem(self, string, index, newvalue):
        raise NotImplementedError
    def bh_copystrcontent(self, src, dst, srcstart, dststart, length):
        raise NotImplementedError
    def bh_copyunicodecontent(self, src, dst, srcstart, dststart, length):
        raise NotImplementedError

class CompiledLoopToken(object):
    asmmemmgr_blocks = None
    asmmemmgr_gcreftracers = None

    def __init__(self, cpu, number):
        cpu.tracker.total_compiled_loops += 1
        self.cpu = cpu
        self.number = number
        self.bridges_count = 0
        self.invalidate_positions = []
        # a list of weakrefs to looptokens that has been redirected to
        # this one
        self.looptokens_redirected_to = []
        debug_start("jit-mem-looptoken-alloc")
        debug_print("allocating Loop #", self.number)
        debug_stop("jit-mem-looptoken-alloc")

    def compiling_a_bridge(self):
        self.cpu.tracker.total_compiled_bridges += 1
        self.bridges_count += 1
        debug_start("jit-mem-looptoken-alloc")
        debug_print("allocating Bridge #", self.bridges_count, "of Loop #", self.number)
        debug_stop("jit-mem-looptoken-alloc")

    def update_frame_info(self, oldlooptoken, baseofs):
        new_fi = self.frame_info
        new_loop_tokens = []
        for ref in oldlooptoken.looptokens_redirected_to:
            looptoken = ref()
            if looptoken:
                looptoken.frame_info.update_frame_depth(baseofs,
                                                     new_fi.jfi_frame_depth)
                new_loop_tokens.append(ref)
        oldlooptoken.frame_info.update_frame_depth(baseofs,
                                                   new_fi.jfi_frame_depth)
        assert oldlooptoken is not None
        new_loop_tokens.append(weakref.ref(oldlooptoken))
        self.looptokens_redirected_to = new_loop_tokens

    def __del__(self):
        #debug_start("jit-mem-looptoken-free")
        #debug_print("freeing Loop #", self.number, 'with',
        #            self.bridges_count, 'attached bridges')
        self.cpu.free_loop_and_bridges(self)
        self.cpu.tracker.total_freed_loops += 1
        self.cpu.tracker.total_freed_bridges += self.bridges_count
        #debug_stop("jit-mem-looptoken-free")
