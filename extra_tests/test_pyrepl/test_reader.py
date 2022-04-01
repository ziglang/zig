
def test_process_prompt():
    from pyrepl.reader import Reader
    r = Reader(None)
    assert r.process_prompt("hi!") == ("hi!", 3)
    assert r.process_prompt("h\x01i\x02!") == ("hi!", 2)
    assert r.process_prompt("hi\033[11m!") == ("hi\033[11m!", 3)
    assert r.process_prompt("h\x01i\033[11m!\x02") == ("hi\033[11m!", 1)
    assert r.process_prompt("h\033[11m\x01i\x02!") == ("h\033[11mi!", 2)
