from rpython.rtyper.lltypesystem import llmemory
from rpython.memory.gc.incminimark import IncrementalMiniMarkGC
from rpython.rlib.rarithmetic import LONG_BIT

# Note that most tests are in test_direct.py.


def test_card_marking_words_for_length():
    gc = IncrementalMiniMarkGC(None, card_page_indices=128)
    assert gc.card_page_shift == 7
    P = 128 * LONG_BIT
    assert gc.card_marking_words_for_length(1) == 1
    assert gc.card_marking_words_for_length(P) == 1
    assert gc.card_marking_words_for_length(P+1) == 2
    assert gc.card_marking_words_for_length(P+P) == 2
    assert gc.card_marking_words_for_length(P+P+1) == 3
    assert gc.card_marking_words_for_length(P+P+P+P+P+P+P+P) == 8
    assert gc.card_marking_words_for_length(P+P+P+P+P+P+P+P+1) == 9

def test_card_marking_bytes_for_length():
    gc = IncrementalMiniMarkGC(None, card_page_indices=128)
    assert gc.card_page_shift == 7
    P = 128 * 8
    assert gc.card_marking_bytes_for_length(1) == 1
    assert gc.card_marking_bytes_for_length(P) == 1
    assert gc.card_marking_bytes_for_length(P+1) == 2
    assert gc.card_marking_bytes_for_length(P+P) == 2
    assert gc.card_marking_bytes_for_length(P+P+1) == 3
    assert gc.card_marking_bytes_for_length(P+P+P+P+P+P+P+P) == 8
    assert gc.card_marking_bytes_for_length(P+P+P+P+P+P+P+P+1) == 9

def test_set_major_threshold():
    gc = IncrementalMiniMarkGC(None, major_collection_threshold=2.0,
                    growth_rate_max=1.5)
    gc.min_heap_size = 100.0
    gc.max_heap_size = 300.0
    gc.next_major_collection_initial = 0.0
    gc.next_major_collection_threshold = 0.0
    # first, we don't grow past min_heap_size
    for i in range(5):
        gc.set_major_threshold_from(100.0)
        assert gc.next_major_collection_threshold == 100.0
    # then we grow a lot
    b = gc.set_major_threshold_from(100 * 2.0)
    assert b is False
    assert gc.next_major_collection_threshold == 150.0
    b = gc.set_major_threshold_from(150 * 2.0)
    assert b is False
    assert gc.next_major_collection_threshold == 225.0
    b = gc.set_major_threshold_from(225 * 2.0)
    assert b is True
    assert gc.next_major_collection_threshold == 300.0   # max reached
    b = gc.set_major_threshold_from(300 * 2.0)
    assert b is True
    assert gc.next_major_collection_threshold == 300.0
    # then we shrink instantly
    b = gc.set_major_threshold_from(100.0)
    assert b is False
    assert gc.next_major_collection_threshold == 100.0
    # then we grow a bit
    b = gc.set_major_threshold_from(100 * 1.25)
    assert b is False
    assert gc.next_major_collection_threshold == 125.0
    b = gc.set_major_threshold_from(125 * 1.25)
    assert b is False
    assert gc.next_major_collection_threshold == 156.25
    # check that we cannot shrink below min_heap_size
    b = gc.set_major_threshold_from(42.7)
    assert b is False
    assert gc.next_major_collection_threshold == 100.0
