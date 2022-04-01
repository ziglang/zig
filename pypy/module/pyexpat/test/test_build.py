from rpython.translator.translator import TranslationContext
from rpython.translator.c.genc import CStandaloneBuilder
from rpython.annotator.listdef import s_list_of_strings
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.tool.rffi_platform import CompilationError

import os
import py
try:
    import pyexpat
except ImportError:
    py.test.skip("No module expat")

try:
    from pypy.module.pyexpat import interp_pyexpat
except (ImportError, CompilationError):
    py.test.skip("Expat not installed")

def test_build():
    def entry_point(argv):
        parser = interp_pyexpat.XML_ParserCreate("test")
        interp_pyexpat.XML_ParserFree(parser)
        res = interp_pyexpat.XML_ErrorString(3)
        os.write(1, rffi.constcharp2str(res))
        return 0

    t = TranslationContext()
    t.buildannotator().build_types(entry_point, [s_list_of_strings])
    t.buildrtyper().specialize()

    builder = CStandaloneBuilder(t, entry_point, t.config)
    builder.generate_source()
    builder.compile()
    data = builder.cmdexec()
    assert data == pyexpat.ErrorString(3)
