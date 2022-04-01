from rpython.jit.backend.llsupport.test.ztranslation_test import TranslationTest
from rpython.jit.backend.x86.arch import WORD
import sys


class TestTranslationX86(TranslationTest):
    def _check_cbuilder(self, cbuilder):
        # msse2 and sse are always on on x86-64
        if WORD == 4 and sys.platform != 'win32':
            assert '-msse2' in cbuilder.eci.compile_extra
            assert '-mfpmath=sse' in cbuilder.eci.compile_extra
