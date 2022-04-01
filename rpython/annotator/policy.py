# base annotation policy for specialization
from rpython.annotator.specialize import default_specialize as default
from rpython.annotator.specialize import (
    specialize_argvalue, specialize_argtype, specialize_arglistitemtype,
    specialize_arg_or_var, memo, specialize_call_location)
from rpython.flowspace.operation import op
from rpython.flowspace.model import Constant
from rpython.annotator.model import SomeTuple


class AnnotatorPolicy(object):
    """
    Possibly subclass and pass an instance to the annotator to control
    special-casing during annotation
    """

    def event(pol, bookkeeper, what, *args):
        pass

    def get_specializer(pol, directive):
        if directive is None:
            return pol.default_specialize

        # specialize[(args)]
        directive_parts = directive.split('(', 1)
        if len(directive_parts) == 1:
            [name] = directive_parts
            parms = ()
        else:
            name, parms = directive_parts
            try:
                parms = eval("(lambda *parms: parms)(%s" % parms)
            except (KeyboardInterrupt, SystemExit):
                raise
            except:
                raise Exception("broken specialize directive parms: %s" % directive)
        name = name.replace(':', '__')
        try:
            specializer = getattr(pol, name)
        except AttributeError:
            raise AttributeError("%r specialize tag not defined in annotation"
                                 "policy %s" % (name, pol))
        else:
            if not parms:
                return specializer
            else:
                def specialize_with_parms(funcdesc, args_s):
                    return specializer(funcdesc, args_s, *parms)
                return specialize_with_parms

    # common specializations

    default_specialize = staticmethod(default)
    specialize__memo = staticmethod(memo)
    specialize__arg = staticmethod(specialize_argvalue) # specialize:arg(N)
    specialize__arg_or_var = staticmethod(specialize_arg_or_var)
    specialize__argtype = staticmethod(specialize_argtype) # specialize:argtype(N)
    specialize__arglistitemtype = staticmethod(specialize_arglistitemtype)
    specialize__call_location = staticmethod(specialize_call_location)

    def specialize__ll(pol, *args):
        from rpython.rtyper.annlowlevel import LowLevelAnnotatorPolicy
        return LowLevelAnnotatorPolicy.default_specialize(*args)

    def specialize__ll_and_arg(pol, *args):
        from rpython.rtyper.annlowlevel import LowLevelAnnotatorPolicy
        return LowLevelAnnotatorPolicy.specialize__ll_and_arg(*args)

    def no_more_blocks_to_annotate(pol, annotator):
        bk = annotator.bookkeeper
        # hint to all pending specializers that we are done
        for callback in bk.pending_specializations:
            callback()
        del bk.pending_specializations[:]
        if annotator.added_blocks is not None:
            all_blocks = annotator.added_blocks
        else:
            all_blocks = annotator.annotated
        for block in list(all_blocks):
            for i, instr in enumerate(block.operations):
                if not isinstance(instr, (op.simple_call, op.call_args)):
                    continue
                v_func = instr.args[0]
                s_func = annotator.annotation(v_func)
                if not hasattr(s_func, 'needs_sandboxing'):
                    continue
                key = ('sandboxing', s_func.const)
                if key not in bk.emulated_pbc_calls:
                    params_s = s_func.args_s
                    s_result = s_func.s_result
                    from rpython.translator.sandbox.rsandbox import make_sandbox_trampoline
                    sandbox_trampoline = make_sandbox_trampoline(
                        s_func.name, params_s, s_result)
                    sandbox_trampoline._signature_ = [SomeTuple(items=params_s)], s_result
                    bk.emulate_pbc_call(key, bk.immutablevalue(sandbox_trampoline), params_s)
                else:
                    s_trampoline = bk.emulated_pbc_calls[key][0]
                    sandbox_trampoline = s_trampoline.const
                new = instr.replace({instr.args[0]: Constant(sandbox_trampoline)})
                block.operations[i] = new
