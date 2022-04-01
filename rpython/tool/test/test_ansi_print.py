from _pytest.monkeypatch import monkeypatch
from rpython.tool import ansi_print, ansi_mandelbrot


class FakeOutput(object):
    def __init__(self, tty=True):
        self.monkey = monkeypatch()
        self.tty = tty
        self.output = []
    def __enter__(self, *args):
        ansi_print.wrote_dot = False
        self.monkey.setattr(ansi_print, 'ansi_print', self._print)
        self.monkey.setattr(ansi_print, 'isatty', self._isatty)
        self.monkey.setattr(ansi_mandelbrot, 'ansi_print', self._print)
        return self.output
    def __exit__(self, *args):
        self.monkey.undo()

    def _print(self, text, colors, newline=True, flush=True):
        if newline:
            text += '\n'
        self.output.append((text, colors))
    def _isatty(self):
        return self.tty


def test_simple():
    log = ansi_print.AnsiLogger('test')
    with FakeOutput() as output:
        log('Hello')
    assert output == [('[test] Hello\n', ())]

def test_bold():
    log = ansi_print.AnsiLogger('test')
    with FakeOutput() as output:
        log.bold('Hello')
    assert output == [('[test] Hello\n', (1,))]

def test_not_a_tty():
    log = ansi_print.AnsiLogger('test')
    with FakeOutput(tty=False) as output:
        log.bold('Hello')
    assert output == [('[test] Hello\n', ())]

def test_dot_1():
    log = ansi_print.AnsiLogger('test')
    with FakeOutput() as output:
        log.dot()
    assert len(output) == 1
    assert len(output[0][0]) == 1    # single character
    # output[0][1] is some ansi color code from mandelbort_driver

def test_dot_mixing_with_regular_lines():
    log = ansi_print.AnsiLogger('test')
    with FakeOutput() as output:
        log.dot()
        log.dot()
        log.WARNING('oops')
        log.WARNING('maybe?')
        log.dot()
    assert len(output) == 5
    assert len(output[0][0]) == 1    # single character
    assert len(output[1][0]) == 1    # single character
    assert output[2] == ('\n[test:WARNING] oops\n', (31,))
    assert output[3] == ('[test:WARNING] maybe?\n', (31,))
    assert len(output[4][0]) == 1    # single character

def test_no_tty():
    log = ansi_print.AnsiLogger('test')
    with FakeOutput(tty=False) as output:
        log.dot()
        log.dot()
        log.WARNING('oops')
        log.WARNING('maybe?')
        log.dot()
    assert len(output) == 2
    assert output[0] == ('[test:WARNING] oops\n', ())
    assert output[1] == ('[test:WARNING] maybe?\n', ())
        

def test_unknown_method_names():
    log = ansi_print.AnsiLogger('test')
    with FakeOutput() as output:
        log.foo('Hello')
        log.foo('World')
        log.BAR('!')
    assert output == [('[test:foo] Hello\n', ()),
                      ('[test:foo] World\n', ()),
                      ('[test:BAR] !\n', ())]

def test_output_disabled():
    log = ansi_print.AnsiLogger('test')
    with FakeOutput() as output:
        log('Hello')
        log.output_disabled = True
        log('World')
    assert output == [('[test] Hello\n', ())]
