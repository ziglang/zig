from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import SomePtr, lltype_to_annotation
from rpython.rtyper.annlowlevel import (
    cast_instance_to_gcref, cast_gcref_to_instance, llstr)
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.lltypesystem import llmemory, lltype
from rpython.flowspace.model import Constant


def register_helper(s_result):
    def wrapper(helper):
        class Entry(ExtRegistryEntry):
            _about_ = helper

            def compute_result_annotation(self, *args):
                if (isinstance(s_result, annmodel.SomeObject) or
                        s_result is None):
                    return s_result
                return lltype_to_annotation(s_result)

            def specialize_call(self, hop):
                from rpython.rtyper.lltypesystem import lltype

                c_func = hop.inputconst(lltype.Void, helper)
                c_name = hop.inputconst(lltype.Void, 'access_helper')
                args_v = [hop.inputarg(arg, arg=i)
                          for i, arg in enumerate(hop.args_r)]
                hop.exception_cannot_occur()
                return hop.genop('jit_marker', [c_name, c_func] + args_v,
                                 resulttype=hop.r_result)
        return helper
    return wrapper

def _cast_to_box(llref):
    from rpython.jit.metainterp.history import AbstractValue
    return cast_gcref_to_instance(AbstractValue, llref)

def _cast_to_resop(llref):
    from rpython.jit.metainterp.resoperation import AbstractResOp
    return cast_gcref_to_instance(AbstractResOp, llref)

_cast_to_gcref = cast_instance_to_gcref

def emptyval():
    return lltype.nullptr(llmemory.GCREF.TO)

@register_helper(SomePtr(llmemory.GCREF))
def resop_new(no, llargs, llres):
    from rpython.jit.metainterp.history import ResOperation

    args = [_cast_to_box(llargs[i]) for i in range(len(llargs))]
    if llres:
        res = _cast_to_box(llres)
    else:
        res = None
    return _cast_to_gcref(ResOperation(no, args, res))

@register_helper(annmodel.SomeInteger())
def resop_getopnum(llop):
    return _cast_to_resop(llop).getopnum()

@register_helper(annmodel.SomeString(can_be_None=True))
def resop_getopname(llop):
    return llstr(_cast_to_resop(llop).getopname())

@register_helper(SomePtr(llmemory.GCREF))
def resop_getarg(llop, no):
    return _cast_to_gcref(_cast_to_resop(llop).getarg(no))

@register_helper(annmodel.s_None)
def resop_setarg(llop, no, llbox):
    _cast_to_resop(llop).setarg(no, _cast_to_box(llbox))

@register_helper(annmodel.SomeInteger())
def box_getint(llbox):
    return _cast_to_box(llbox).getint()

@register_helper(SomePtr(llmemory.GCREF))
def box_clone(llbox):
    return _cast_to_gcref(_cast_to_box(llbox).clonebox())

@register_helper(SomePtr(llmemory.GCREF))
def box_constbox(llbox):
    return _cast_to_gcref(_cast_to_box(llbox).constbox())

@register_helper(SomePtr(llmemory.GCREF))
def box_nonconstbox(llbox):
    return _cast_to_gcref(_cast_to_box(llbox).nonconstbox())

@register_helper(annmodel.SomeBool())
def box_isconst(llbox):
    from rpython.jit.metainterp.history import Const
    return isinstance(_cast_to_box(llbox), Const)

@register_helper(annmodel.SomeBool())
def box_isint(llbox):
    from rpython.jit.metainterp.history import INT
    return _cast_to_box(llbox).type == INT

# ------------------------- stats interface ---------------------------

@register_helper(annmodel.SomeBool())
def stats_set_debug(warmrunnerdesc, flag):
    return warmrunnerdesc.metainterp_sd.cpu.set_debug(flag)

@register_helper(annmodel.SomeInteger())
def stats_get_counter_value(warmrunnerdesc, no):
    return warmrunnerdesc.metainterp_sd.profiler.get_counter(no)

@register_helper(annmodel.SomeFloat())
def stats_get_times_value(warmrunnerdesc, no):
    return warmrunnerdesc.metainterp_sd.profiler.get_times(no)

LOOP_RUN_CONTAINER = lltype.GcArray(lltype.Struct('elem',
                                                  ('type', lltype.Char),
                                                  ('number', lltype.Signed),
                                                  ('counter', lltype.Signed)))

@register_helper(lltype.Ptr(LOOP_RUN_CONTAINER))
def stats_get_loop_run_times(warmrunnerdesc):
    return warmrunnerdesc.metainterp_sd.cpu.get_all_loop_runs()

@register_helper(annmodel.SomeInteger(unsigned=True))
def stats_asmmemmgr_allocated(warmrunnerdesc):
    return warmrunnerdesc.metainterp_sd.cpu.asmmemmgr.get_stats()[0]

@register_helper(annmodel.SomeInteger(unsigned=True))
def stats_asmmemmgr_used(warmrunnerdesc):
    return warmrunnerdesc.metainterp_sd.cpu.asmmemmgr.get_stats()[1]

@register_helper(None)
def stats_memmgr_release_all(warmrunnerdesc):
    warmrunnerdesc.memory_manager.release_all_loops()

# ---------------------- jitcell interface ----------------------

def _new_hook(name, resulttype):
    def hook(name, *greenkey):
        raise Exception("need to run translated")
    hook.__name__ = name

    class GetJitCellEntry(ExtRegistryEntry):
        _about_ = hook

        def compute_result_annotation(self, s_name, *args_s):
            assert s_name.is_constant()
            return resulttype

        def specialize_call(self, hop):
            c_jitdriver = Constant(hop.args_s[0].const, concretetype=lltype.Void)
            c_name = Constant(name, concretetype=lltype.Void)
            hop.exception_cannot_occur()
            args_v = [hop.inputarg(arg, arg=i + 1)
                      for i, arg in enumerate(hop.args_r[1:])]
            return hop.genop('jit_marker', [c_name, c_jitdriver] + args_v,
                             resulttype=hop.r_result)

    return hook

get_jitcell_at_key = _new_hook('get_jitcell_at_key', SomePtr(llmemory.GCREF))
trace_next_iteration = _new_hook('trace_next_iteration', None)
dont_trace_here = _new_hook('dont_trace_here', None)
trace_next_iteration_hash = _new_hook('trace_next_iteration_hash', None)
