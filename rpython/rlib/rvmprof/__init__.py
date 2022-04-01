from rpython.rlib.objectmodel import specialize
from rpython.rlib.rvmprof.rvmprof import _get_vmprof, VMProfError
from rpython.rlib.rvmprof.rvmprof import vmprof_execute_code, MAX_FUNC_NAME
from rpython.rlib.rvmprof.rvmprof import _was_registered
from rpython.rlib.rvmprof.cintf import VMProfPlatformUnsupported
from rpython.rtyper.lltypesystem import rffi, lltype

#
# See README.txt.
#

#vmprof_execute_code(): implemented directly in rvmprof.py

def register_code_object_class(CodeClass, full_name_func):
    _get_vmprof().register_code_object_class(CodeClass, full_name_func)

@specialize.argtype(0)
def register_code(code, name):
    _get_vmprof().register_code(code, name)

@specialize.call_location()
def get_unique_id(code):
    """Return the internal unique ID of a code object.  Can only be
    called after register_code().  Call this in the jitdriver's
    method 'get_unique_id(*greenkey)'.  This always returns 0 if we
    didn't call register_code_object_class() on the class.
    """
    assert code is not None
    if _was_registered(code.__class__):
        # '0' can occur here too, if the code object was prebuilt,
        # or if register_code() was not called for another reason.
        return code._vmprof_unique_id
    return 0

def enable(fileno, interval, memory=0, native=0, real_time=0):
    _get_vmprof().enable(fileno, interval, memory, native, real_time)

def disable():
    _get_vmprof().disable()

def is_enabled():
    vmp = _get_vmprof()
    return vmp.is_enabled

def get_profile_path(space):
    vmp = _get_vmprof()
    if not vmp.is_enabled:
        return None

    with rffi.scoped_alloc_buffer(4096) as buf:
        length = vmp.cintf.vmprof_get_profile_path(buf.raw, buf.size) 
        if length == -1:
            return ""
        return buf.str(length)

    return None

def stop_sampling():
    return _get_vmprof().stop_sampling()

def start_sampling():
    return _get_vmprof().start_sampling()

# ----------------
# stacklet support
# ----------------
#
# Ideally, vmprof_tl_stack, VMPROFSTACK etc. should be part of "self.cintf":
# not sure why they are a global. Eventually, we should probably fix all this
# mess.
from rpython.rlib.rvmprof.cintf import vmprof_tl_stack, VMPROFSTACK

def save_stack():
    stop_sampling()
    return vmprof_tl_stack.get_or_make_raw()

def empty_stack():
    vmprof_tl_stack.setraw(lltype.nullptr(VMPROFSTACK))

def restore_stack(x):
    vmprof_tl_stack.setraw(x)
    start_sampling()
