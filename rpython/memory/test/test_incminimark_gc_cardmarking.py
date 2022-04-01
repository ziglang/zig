from rpython.memory.test import test_incminimark_gc

class TestIncrementalMiniMarkGCCardMarking(test_incminimark_gc.TestIncrementalMiniMarkGC):
    GC_PARAMS = {'card_page_indices': 4}
