from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem import rffi
from rpython.translator.platform import platform


def get_compiler_info():
    """Returns a string like 'MSC v.# 32 bit' or 'GCC #.#.#'.
    Before translation, returns '(untranslated)'.

    Must be called at run-time, not before translation, otherwise
    you're freezing the string '(untranslated)' into the executable!
    """
    if we_are_translated():
        return rffi.charp2str(COMPILER_INFO)
    return "(untranslated)"

# ____________________________________________________________


if platform.name == 'msvc':
    if platform.x64:
        # XXX hard-code the CPU name
        _C_COMPILER_INFO = '"MSC v." Py_STR(_MSC_VER) " 64 bit (AMD64)"'
    else:
        _C_COMPILER_INFO = '"MSC v." Py_STR(_MSC_VER) " 32 bit"'
else:
    _C_COMPILER_INFO = '("GCC " __VERSION__)'

COMPILER_INFO = rffi.CConstant(_C_COMPILER_INFO, rffi.CCHARP)
