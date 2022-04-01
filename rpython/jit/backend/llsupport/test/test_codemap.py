import sys
import pytest
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.jit.backend.llsupport.codemap import CodemapStorage, \
     CodemapBuilder, unpack_traceback, find_codemap_at_addr

NULL = lltype.nullptr(rffi.CArray(lltype.Signed))
     
def test_register_codemap():
    codemap = CodemapStorage()
    codemap.setup()
    codemap.register_codemap((100, 20, [13, 14, 15]))
    codemap.register_codemap((300, 30, [16, 17, 18]))
    codemap.register_codemap((200, 100, [19, 20, 21, 22, 23]))
    #
    raw100 = find_codemap_at_addr(100, NULL)
    assert find_codemap_at_addr(119, NULL) == raw100
    assert not find_codemap_at_addr(120, NULL)
    #
    raw200 = find_codemap_at_addr(200, NULL)
    assert raw200 != raw100
    assert find_codemap_at_addr(299, NULL) == raw200
    #
    raw300 = find_codemap_at_addr(329, NULL)
    assert raw300 != raw100 and raw300 != raw200
    assert find_codemap_at_addr(300, NULL) == raw300
    #
    codemap.free()

@pytest.mark.skipif(sys.platform=='win32', reason='codemap unused, and long/Signed confusion on win64')
def test_free_with_alignment():
    codemap = CodemapStorage()
    codemap.setup()
    builder = CodemapBuilder()
    builder.enter_portal_frame(23, 34, 0)
    builder.enter_portal_frame(45, 56, 20)
    codemap.register_codemap(builder.get_final_bytecode(200, 100))
    assert unpack_traceback(215) == [34]
    assert unpack_traceback(225) == [34, 56]
    codemap.free_asm_block(190, 310)   # a bit larger
    assert unpack_traceback(215) == []
    assert unpack_traceback(225) == []
    codemap.free()
