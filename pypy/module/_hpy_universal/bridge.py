from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.module._hpy_universal import llapi
from pypy.module._hpy_universal.apiset import APISet

# =============== HPy-RPython BRIDGE ===============
#
# Semi-complicate (but hopefully not too magic!) machinery to make it possible
# to call RPython functions from C in a way which works both before and after
# translation:
#
#   - during tests, the code runs on top of CPython, so we need ll2ctypes
#     callbacks: in bridge.h, a set of macros turn e.g. a call to foo() into
#     hpy_get_bridge()->foo()
#
#   - after translations, we want a direct call to the generated C functions

# NOTE: for bridge functions which take arguments of type "HPy", one more hack
# is needed. See the comment in bridge.h

# Adding a new bridge function is annoying because it involves modifying few
# different places: in theory it could be automated, but as long as the number
# of bridge function remains manageable, it is better to avoid adding
# unnecessary magic.  To add a new bridge function you need:
#
#   1. add the @BRIDGE.func decorator to your RPython function
#   2. add the corresponding field in _HPyBridge here
#   3. inside src/bridge.h:
#      a) add the corresponding field in _HPyBridge
#      b) write a macro for the RPYTHON_LL2CTYPES case
#      c) write the function prototype for the non-RPYTHON_LL2CTYPES case
#      d) if the func recevies HPy arguments, write a macro to convert them

llapi.cts.parse_source("""
typedef struct {
    void * hpy_err_Occurred_rpy;
    void * hpy_err_Clear;
} _HPyBridge;
""")

_HPyBridge = llapi.cts.gettype('_HPyBridge')
hpy_get_bridge = rffi.llexternal('hpy_get_bridge', [], lltype.Ptr(_HPyBridge),
                                 compilation_info=llapi.eci, _nowrapper=True)

BRIDGE = APISet(llapi.cts, is_debug=False, prefix='^hpy_', force_c_name=True)
