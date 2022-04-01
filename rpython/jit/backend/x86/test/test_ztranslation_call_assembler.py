from rpython.jit.backend.llsupport.test.ztranslation_test import TranslationTestCallAssembler
from rpython.translator.translator import TranslationContext
from rpython.config.translationoption import DEFL_GC
from rpython.jit.backend.x86.arch import WORD
import sys


# On Windows, this test crashes obscurely, but only if compiled with
# Boehm, not if run with no GC at all.  So for now we'll assume it is
# really a Boehm bug, or maybe a Boehm-on-Windows-specific issue, and
# skip.
if sys.platform == 'win32':
    import py
    py.test.skip("crashes on Windows (Boehm issue?)")


class TestTranslationCallAssemblerX86(TranslationTestCallAssembler):
    def _check_cbuilder(self, cbuilder):
        #We assume here that we have sse2.  If not, the CPUClass
        # needs to be changed to CPU386_NO_SSE2, but well.
        if WORD == 4 and sys.platform != 'win32':
            assert '-msse2' in cbuilder.eci.compile_extra
            assert '-mfpmath=sse' in cbuilder.eci.compile_extra
