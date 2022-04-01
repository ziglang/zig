from rpython.rtyper.llinterp import LLInterpreter
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.extregistry import ExtRegistryEntry

def maybe_on_top_of_llinterp(rtyper, fnptr):
    # Run a generated graph on top of the llinterp for testing.
    # When translated, this just returns the fnptr.
    def process_args(args):
        real_args = []
        ARGS = lltype.typeOf(funcobj).ARGS
        i = 0
        for ARG in ARGS:
            if ARG is lltype.Void:
                real_args.append(None)
            else:
                if ARG is lltype.Float:
                    real_args.append(args[i])
                elif isinstance(ARG, lltype.Primitive):
                    real_args.append(lltype.cast_primitive(ARG, args[i]))
                elif isinstance(ARG, lltype.Ptr):
                    if ARG.TO._gckind == 'gc':
                        real_args.append(lltype.cast_opaque_ptr(ARG, args[i]))
                    else:
                        real_args.append(rffi.cast(ARG, args[i]))
                else:
                    raise Exception("Unexpected arg: %s" % ARG)
                i += 1
        return real_args

    funcobj = fnptr._obj
    if hasattr(funcobj, 'graph'):
        # cache the llinterp; otherwise the remember_malloc/remember_free
        # done on the LLInterpreter don't match
        try:
            llinterp = rtyper._on_top_of_llinterp_llinterp
        except AttributeError:
            llinterp = LLInterpreter(rtyper)  #, exc_data_ptr=exc_data_ptr)
            rtyper._on_top_of_llinterp_llinterp = llinterp
        def on_top_of_llinterp(*args):
            real_args = process_args(args)
            return llinterp.eval_graph(funcobj.graph, real_args)
    else:
        assert hasattr(funcobj, '_callable')
        def on_top_of_llinterp(*args):
            args = process_args(args)
            return funcobj._callable(*args)
    return on_top_of_llinterp

class Entry(ExtRegistryEntry):
    _about_ = maybe_on_top_of_llinterp
    def compute_result_annotation(self, s_rtyper, s_fnptr):
        return s_fnptr
    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.inputarg(hop.args_r[1], arg=1)
