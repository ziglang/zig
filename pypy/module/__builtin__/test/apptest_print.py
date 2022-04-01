import pytest

class filelike():
    def __init__(self):
        self.written = ''
        self.flushed = 0
    def write(self, str):
        self.written += str
    def flush(self):
        self.flushed += 1

def test_print_flush():
    # operation of the flush flag

    f = filelike()
    print(1, file=f, end='', flush=True)
    print(2, file=f, end='', flush=True)
    print(3, file=f, flush=False)
    assert f.written == '123\n'
    assert f.flushed == 2

    # ensure exceptions from flush are passed through
    class noflush():
        def write(self, str):
            pass
        def flush(self):
            raise RuntimeError
    with pytest.raises(RuntimeError):
        print(1, file=noflush(), flush=True)

def test_end_None():
    f = filelike()
    print(1, file=f, end=None)
    assert f.written == '1\n'

def test_sep_None():
    f = filelike()
    print(1, 2, 3, file=f, sep=None)
    assert f.written == '1 2 3\n'
