"""
A simple color logger.
"""

import sys
from py.io import ansi_print
from rpython.tool.ansi_mandelbrot import Driver


isatty = getattr(sys.stderr, 'isatty', lambda: False)
mandelbrot_driver = Driver()
wrote_dot = False     # global shared state


def _make_method(subname, colors):
    #
    def logger_method(self, text):
        global wrote_dot
        if self.output_disabled:
            return
        text = "[%s%s] %s" % (self.name, subname, text)
        if isatty():
            col = colors
        else:
            col = ()
        if wrote_dot:
            text = '\n' + text
        ansi_print(text, col)
        wrote_dot = False
    #
    return logger_method


class AnsiLogger(object):
    output_disabled = False

    def __init__(self, name):
        self.name = name

    # these methods write "[name:method] text" to the terminal, with color codes
    red      = _make_method('', (31,))
    bold     = _make_method('', (1,))
    WARNING  = _make_method(':WARNING', (31,))
    event    = _make_method('', (1,))
    ERROR    = _make_method(':ERROR', (1, 31))
    Error    = _make_method(':Error', (1, 31))
    info     = _make_method(':info', (35,))
    stub     = _make_method(':stub', (34,))

    # some more methods used by sandlib
    call      = _make_method(':call', (34,))
    result    = _make_method(':result', (34,))
    exception = _make_method(':exception', (34,))
    vpath     = _make_method(':vpath', (35,))
    timeout   = _make_method('', (1, 31))

    # directly calling the logger writes "[name] text" with no particular color
    __call__ = _make_method('', ())

    # calling unknown method names writes "[name:method] text" without color
    def __getattr__(self, name):
        if name[0].isalpha():
            method = _make_method(':' + name, ())
            setattr(self.__class__, name, method)
            return getattr(self, name)
        raise AttributeError(name)

    def dot(self):
        """Output a mandelbrot dot to the terminal."""
        if not isatty():
            return
        global wrote_dot
        if not wrote_dot:
            mandelbrot_driver.reset()
            wrote_dot = True
        mandelbrot_driver.dot()

    def debug(self, info):
        """For messages that are dropped.  Can be monkeypatched in tests."""
