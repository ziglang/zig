from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.annotator import model as annmodel
import os


def find_gc_ptrs_in_type(TYPE):
    if isinstance(TYPE, lltype.Array):
        return find_gc_ptrs_in_type(TYPE.OF)
    elif isinstance(TYPE, lltype.Struct):
        result = []
        for name in TYPE._names:
            result.extend(find_gc_ptrs_in_type(TYPE._flds[name]))
        return result
    elif isinstance(TYPE, lltype.Ptr) and TYPE._needsgc():
        return [TYPE]
    elif isinstance(TYPE, lltype.GcOpaqueType):
        # heuristic: in theory the same problem exists with OpaqueType, but
        # we use OpaqueType for other things too that we know are safely
        # empty of further gc pointers
        raise Exception("don't know what is in %r" % (TYPE,))
    else:
        return []

def get_rtti(TYPE):
    if isinstance(TYPE, lltype.RttiStruct):
        try:
            return lltype.getRuntimeTypeInfo(TYPE)
        except ValueError:
            pass
    return None

def _static_deallocator_body_for_type(v, TYPE, depth=1):
    if isinstance(TYPE, lltype.Array):
        inner = list(_static_deallocator_body_for_type('v_%i'%depth, TYPE.OF, depth+1))
        if inner:
            yield '    '*depth + 'i_%d = 0'%(depth,)
            yield '    '*depth + 'l_%d = len(%s)'%(depth, v)
            yield '    '*depth + 'while i_%d < l_%d:'%(depth, depth)
            yield '    '*depth + '    v_%d = %s[i_%d]'%(depth, v, depth)
            for line in inner:
                yield line
            yield '    '*depth + '    i_%d += 1'%(depth,)
    elif isinstance(TYPE, lltype.Struct):
        for name in TYPE._names:
            inner = list(_static_deallocator_body_for_type(
                v + '_' + name, TYPE._flds[name], depth))
            if inner:
                yield '    '*depth + v + '_' + name + ' = ' + v + '.' + name
                for line in inner:
                    yield line
    elif isinstance(TYPE, lltype.Ptr) and TYPE._needsgc():
        yield '    '*depth + 'pop_alive(%s)'%v

class LLTransformerOp(object):
    """Objects that can be called in ll functions.
    Their calls are replaced by a simple operation of the GC transformer,
    e.g. ll_pop_alive.
    """
    def __init__(self, transformer_method):
        self.transformer_method = transformer_method

class LLTransformerOpEntry(ExtRegistryEntry):
    "Annotation and specialization of LLTransformerOp() instances."
    _type_ = LLTransformerOp

    def compute_result_annotation(self, s_arg):
        return annmodel.s_None

    def specialize_call(self, hop):
        op = self.instance   # the LLTransformerOp instance
        op.transformer_method(hop.args_v[0], hop.llops)
        hop.exception_cannot_occur()
        return hop.inputconst(hop.r_result.lowleveltype, hop.s_result.const)

def write(fd, string):
    from rpython.rlib.rposix import c_write
    return c_write(fd, string, len(string))

def ll_call_destructor(destrptr, destr_v, typename):
    llop.revdb_do_next_call(lltype.Void)
    try:
        destrptr(destr_v)
    except Exception as e:
        try:
            write(2, "a destructor of type ")
            write(2, typename)
            write(2, " raised an exception ")
            write(2, str(e))
            write(2, " ignoring it\n")
        except:
            pass

def ll_report_finalizer_error(e):
    try:
        write(2, "triggering finalizers raised an exception ")
        write(2, str(e))
        write(2, " ignoring it\n")
    except:
        pass
