from rpython.memory.test import test_minimark_gc

class TestMiniMarkGCCardMarking(test_minimark_gc.TestMiniMarkGC):
    GC_PARAMS = {'card_page_indices': 4}
