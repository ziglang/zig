from rpython.jit.backend.llsupport.test.ztranslation_test import TranslationTestJITStats
from rpython.translator.translator import TranslationContext
from rpython.config.translationoption import DEFL_GC
from rpython.jit.backend.x86.arch import WORD
import sys


class TestTranslationJITStatsX86(TranslationTestJITStats):
    def _check_cbuilder(self, cbuilder):
        #We assume here that we have sse2.  If not, the CPUClass
        # needs to be changed to CPU386_NO_SSE2, but well.
        if WORD == 4 and sys.platform != 'win32':
            assert '-msse2' in cbuilder.eci.compile_extra
            assert '-mfpmath=sse' in cbuilder.eci.compile_extra
