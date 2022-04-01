from pypy.interpreter.gateway import unwrap_spec
from rpython.rtyper.lltypesystem import rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
import sys

if sys.platform.startswith('darwin'):
    eci = ExternalCompilationInfo()
elif sys.platform.startswith('linux'):
    # crypt() is defined only in crypt.h on some Linux variants (eg. Fedora 28)
    eci = ExternalCompilationInfo(libraries=['crypt'], includes=["crypt.h"])
else:
    eci = ExternalCompilationInfo(libraries=['crypt'])
c_crypt = rffi.llexternal('crypt', [rffi.CCHARP, rffi.CCHARP], rffi.CCHARP,
                          compilation_info=eci, releasegil=False)

@unwrap_spec(word='text', salt='text')
def crypt(space, word, salt):
    """word will usually be a user's password. salt is a 2-character string
    which will be used to select one of 4096 variations of DES. The characters
    in salt must be either ".", "/", or an alphanumeric character. Returns
    the hashed password as a string, which will be composed of characters from
    the same alphabet as the salt."""
    res = c_crypt(word, salt)
    if not res:
        return space.w_None
    str_res = rffi.charp2str(res)
    return space.newtext(str_res)
