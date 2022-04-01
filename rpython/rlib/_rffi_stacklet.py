import py
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rtyper.tool import rffi_platform
from rpython.rlib.rarithmetic import is_emulated_long
from rpython.translator import cdir


cdir = py.path.local(cdir)

eci = ExternalCompilationInfo(
    include_dirs = [cdir],
    includes = ['src/stacklet/stacklet.h'],
    separate_module_files = [cdir / 'src' / 'stacklet' / 'stacklet.c'],
)
if 'masm' in dir(eci.platform): # Microsoft compiler
    if is_emulated_long:
        asmsrc = 'switch_x64_msvc.asm'
    else:
        asmsrc = 'switch_x86_msvc.asm'
    eci.separate_module_files += (cdir / 'src' / 'stacklet' / asmsrc, )

rffi_platform.verify_eci(eci.convert_sources_to_files())

def llexternal(name, args, result, **kwds):
    return rffi.llexternal(name, args, result, compilation_info=eci,
                           _nowrapper=True, **kwds)

# ----- types -----

handle = rffi.COpaquePtr(typedef='stacklet_handle', compilation_info=eci)
thread_handle = rffi.COpaquePtr(typedef='stacklet_thread_handle',
                                compilation_info=eci)
run_fn = lltype.Ptr(lltype.FuncType([handle, llmemory.Address], handle))

# ----- constants -----

null_handle = lltype.nullptr(handle.TO)

def is_empty_handle(h):
    return rffi.cast(lltype.Signed, h) == -1

# ----- functions -----

newthread = llexternal('stacklet_newthread', [], thread_handle)
deletethread = llexternal('stacklet_deletethread',[thread_handle], lltype.Void)

new = llexternal('stacklet_new', [thread_handle, run_fn, llmemory.Address],
                 handle, random_effects_on_gcobjs=True)
switch = llexternal('stacklet_switch', [handle], handle,
                    random_effects_on_gcobjs=True)
destroy = llexternal('stacklet_destroy', [handle], lltype.Void)

_translate_pointer = llexternal("_stacklet_translate_pointer",
                                [llmemory.Address, llmemory.Address],
                                llmemory.Address)
