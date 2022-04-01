from pypy.objspace.fake.checkmodule import checkmodule
from pypy.module._cffi_backend import ctypeptr
from rpython.rtyper.lltypesystem import lltype, rffi

# side-effect: FORMAT_LONGDOUBLE must be built before test_checkmodule()
from pypy.module._cffi_backend import misc
from pypy.module._cffi_backend import embedding

def test_checkmodule():
    # prepare_file_argument() is not working without translating the _file
    # module too
    def dummy_prepare_file_argument(space, fileobj):
        # call pypy_init_embedded_cffi_module() from a random place like here
        # --- this calls load_cffi1_module(), too
        embedding.pypy_init_embedded_cffi_module(
            rffi.cast(rffi.INT, embedding.EMBED_VERSION_MIN),
            42)
        return lltype.nullptr(rffi.CCHARP.TO)
    old = ctypeptr.prepare_file_argument
    try:
        ctypeptr.prepare_file_argument = dummy_prepare_file_argument
        #
        checkmodule('_cffi_backend')
        #
    finally:
        ctypeptr.prepare_file_argument = old
