import py
from rpython.rlib import rurandom

def test_rurandom():
    context = rurandom.init_urandom()
    s = rurandom.urandom(context, 5000)
    assert type(s) is str and len(s) == 5000
    for x in [1, 11, 111, 222]:
        assert s.count(chr(x)) >= 1

@py.test.mark.skipif("sys.platform == 'win32'")
def test_rurandom_no_syscall(monkeypatch):
    monkeypatch.setattr(rurandom, 'SYS_getrandom', None)
    test_rurandom()
