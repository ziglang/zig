from pypy.interpreter.gateway import unwrap_spec
from rpython.rtyper.lltypesystem import lltype, rffi


ll_exit = rffi.llexternal('exit', [rffi.INT], lltype.Void, _nowrapper=True)

@unwrap_spec(status="c_int")
def exit(space, status):
    ll_exit(rffi.cast(rffi.INT, status))
