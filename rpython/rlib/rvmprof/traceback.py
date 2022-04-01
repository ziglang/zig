"""
Semi-public interface to gather and print a raw traceback, e.g.
from the faulthandler module.
"""

from rpython.rlib.rvmprof import cintf, rvmprof
from rpython.rlib.objectmodel import specialize
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi


def traceback(estimate_number_of_entries):
    """Build and return a vmprof-like traceback, as a pair (array_p,
    array_length).  The caller must free array_p.  Not for signal handlers:
    for these, call vmprof_get_traceback() from C code.
    """
    if not cintf.IS_SUPPORTED:
        return (None, 0)
    _cintf = rvmprof._get_vmprof().cintf
    size = estimate_number_of_entries * 2 + 4
    stack = cintf.get_rvmprof_stack()
    array_p = lltype.malloc(rffi.SIGNEDP.TO, size, flavor='raw')
    NULL = llmemory.NULL
    array_length = _cintf.vmprof_get_traceback(stack, NULL, array_p, size)
    return (array_p, array_length)


LOC_INTERPRETED    = 0
LOC_JITTED         = 1
LOC_JITTED_INLINED = 2


@specialize.arg(0, 1)
def _traceback_one(CodeClass, callback, arg, code_id, loc):
    found_code = None
    if code_id != 0:
        all_code_wrefs = CodeClass._vmprof_weak_list.get_all_handles()
        i = len(all_code_wrefs) - 1
        while i >= 0:
            code = all_code_wrefs[i]()
            if code is not None and code._vmprof_unique_id == code_id:
                found_code = code
                break
            i -= 1
    callback(found_code, loc, arg)

@specialize.arg(0, 1)
def walk_traceback(CodeClass, callback, arg, array_p, array_length):
    """Invoke 'callback(code_obj, loc, arg)' for every traceback entry.
    'code_obj' may be None if it can't be determined.  'loc' is one
    of the LOC_xxx constants.
    """
    if not cintf.IS_SUPPORTED:
        return
    i = 0
    while i < array_length - 1:
        tag = array_p[i]
        tagged_value = array_p[i + 1]
        if tag == rvmprof.VMPROF_CODE_TAG:
            loc = LOC_INTERPRETED
            _traceback_one(CodeClass, callback, arg, tagged_value, loc)
        elif tag == rvmprof.VMPROF_JITTED_TAG:
            if i + 2 >= array_length:  # skip last entry, can't determine if
                break                  # it's LOC_JITTED_INLINED or LOC_JITTED
            if array_p[i + 2] == rvmprof.VMPROF_JITTED_TAG:
                loc = LOC_JITTED_INLINED
            else:
                loc = LOC_JITTED
            _traceback_one(CodeClass, callback, arg, tagged_value, loc)
        i += 2
