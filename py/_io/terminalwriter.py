"""

Helper functions for writing to terminals and files.

"""


import sys, os
import py
py3k = sys.version_info[0] >= 3
from py.builtin import text, bytes

win32_and_ctypes = False
colorama = None
if sys.platform == "win32":
    try:
        import colorama
    except ImportError:
        try:
            import ctypes
            win32_and_ctypes = True
        except ImportError:
            pass


def _getdimensions():
    import termios,fcntl,struct
    call = fcntl.ioctl(1,termios.TIOCGWINSZ,"\000"*8)
    height,width = struct.unpack( "hhhh", call ) [:2]
    return height, width


def get_terminal_width():
    height = width = 0
    try:
        height, width = _getdimensions()
    except py.builtin._sysex:
        raise
    except:
        # pass to fallback below
        pass

    if width == 0:
        # FALLBACK:
        # * some exception happened
        # * or this is emacs terminal which reports (0,0)
        width = int(os.environ.get('COLUMNS', 80))

    # XXX the windows getdimensions may be bogus, let's sanify a bit
    if width < 40:
        width = 80
    return width

terminal_width = get_terminal_width()

# XXX unify with _escaped func below
def ansi_print(text, esc, file=None, newline=True, flush=False):
    if file is None:
        file = sys.stderr
    text = text.rstrip()
    if esc and not isinstance(esc, tuple):
        esc = (esc,)
    if esc and sys.platform != "win32" and file.isatty():
        text = (''.join(['\x1b[%sm' % cod for cod in esc])  +
                text +
                '\x1b[0m')     # ANSI color code "reset"
    if newline:
        text += '\n'

    if esc and win32_and_ctypes and file.isatty():
        if 1 in esc:
            bold = True
            esc = tuple([x for x in esc if x != 1])
        else:
            bold = False
        esctable = {()   : FOREGROUND_WHITE,                 # normal
                    (31,): FOREGROUND_RED,                   # red
                    (32,): FOREGROUND_GREEN,                 # green
                    (33,): FOREGROUND_GREEN|FOREGROUND_RED,  # yellow
                    (34,): FOREGROUND_BLUE,                  # blue
                    (35,): FOREGROUND_BLUE|FOREGROUND_RED,   # purple
                    (36,): FOREGROUND_BLUE|FOREGROUND_GREEN, # cyan
                    (37,): FOREGROUND_WHITE,                 # white
                    (39,): FOREGROUND_WHITE,                 # reset
                    }
        attr = esctable.get(esc, FOREGROUND_WHITE)
        if bold:
            attr |= FOREGROUND_INTENSITY
        STD_OUTPUT_HANDLE = -11
        STD_ERROR_HANDLE = -12
        if file is sys.stderr:
            handle = GetStdHandle(STD_ERROR_HANDLE)
        else:
            handle = GetStdHandle(STD_OUTPUT_HANDLE)
        oldcolors = GetConsoleInfo(handle).wAttributes
        attr |= (oldcolors & 0x0f0)
        SetConsoleTextAttribute(handle, attr)
        while len(text) > 32768:
            file.write(text[:32768])
            text = text[32768:]
        if text:
            file.write(text)
        SetConsoleTextAttribute(handle, oldcolors)
    else:
        file.write(text)

    if flush:
        file.flush()

def should_do_markup(file):
    if os.environ.get('PY_COLORS') == '1':
        return True
    if os.environ.get('PY_COLORS') == '0':
        return False
    return hasattr(file, 'isatty') and file.isatty() \
           and os.environ.get('TERM') != 'dumb' \
           and not (sys.platform.startswith('java') and os._name == 'nt')

class TerminalWriter(object):
    _esctable = dict(black=30, red=31, green=32, yellow=33,
                     blue=34, purple=35, cyan=36, white=37,
                     Black=40, Red=41, Green=42, Yellow=43,
                     Blue=44, Purple=45, Cyan=46, White=47,
                     bold=1, light=2, blink=5, invert=7)

    # XXX deprecate stringio argument
    def __init__(self, file=None, stringio=False, encoding=None):
        if file is None:
            if stringio:
                self.stringio = file = py.io.TextIO()
            else:
                file = py.std.sys.stdout
        elif py.builtin.callable(file) and not (
             hasattr(file, "write") and hasattr(file, "flush")):
            file = WriteFile(file, encoding=encoding)
        if hasattr(file, "isatty") and file.isatty() and colorama:
            file = colorama.AnsiToWin32(file).stream
        self.encoding = encoding or getattr(file, 'encoding', "utf-8")
        self._file = file
        self.fullwidth = get_terminal_width()
        self.hasmarkup = should_do_markup(file)
        self._lastlen = 0

    def _escaped(self, text, esc):
        if esc and self.hasmarkup:
            text = (''.join(['\x1b[%sm' % cod for cod in esc])  +
                text +'\x1b[0m')
        return text

    def markup(self, text, **kw):
        esc = []
        for name in kw:
            if name not in self._esctable:
                raise ValueError("unknown markup: %r" %(name,))
            if kw[name]:
                esc.append(self._esctable[name])
        return self._escaped(text, tuple(esc))

    def sep(self, sepchar, title=None, fullwidth=None, **kw):
        if fullwidth is None:
            fullwidth = self.fullwidth
        # the goal is to have the line be as long as possible
        # under the condition that len(line) <= fullwidth
        if sys.platform == "win32":
            # if we print in the last column on windows we are on a
            # new line but there is no way to verify/neutralize this
            # (we may not know the exact line width)
            # so let's be defensive to avoid empty lines in the output
            fullwidth -= 1
        if title is not None:
            # we want 2 + 2*len(fill) + len(title) <= fullwidth
            # i.e.    2 + 2*len(sepchar)*N + len(title) <= fullwidth
            #         2*len(sepchar)*N <= fullwidth - len(title) - 2
            #         N <= (fullwidth - len(title) - 2) // (2*len(sepchar))
            N = (fullwidth - len(title) - 2) // (2*len(sepchar))
            fill = sepchar * N
            line = "%s %s %s" % (fill, title, fill)
        else:
            # we want len(sepchar)*N <= fullwidth
            # i.e.    N <= fullwidth // len(sepchar)
            line = sepchar * (fullwidth // len(sepchar))
        # in some situations there is room for an extra sepchar at the right,
        # in particular if we consider that with a sepchar like "_ " the
        # trailing space is not important at the end of the line
        if len(line) + len(sepchar.rstrip()) <= fullwidth:
            line += sepchar.rstrip()

        self.line(line, **kw)

    def write(self, msg, **kw):
        if msg:
            if not isinstance(msg, (bytes, text)):
                msg = text(msg)
            if self.hasmarkup and kw:
                markupmsg = self.markup(msg, **kw)
            else:
                markupmsg = msg
            write_out(self._file, markupmsg)

    def line(self, s='', **kw):
        self.write(s, **kw)
        self._checkfill(s)
        self.write('\n')

    def reline(self, line, **kw):
        if not self.hasmarkup:
            raise ValueError("cannot use rewrite-line without terminal")
        self.write(line, **kw)
        self._checkfill(line)
        self.write('\r')
        self._lastlen = len(line)

    def _checkfill(self, line):
        diff2last = self._lastlen - len(line)
        if diff2last > 0:
            self.write(" " * diff2last)

class Win32ConsoleWriter(TerminalWriter):
    def write(self, msg, **kw):
        if msg:
            if not isinstance(msg, (bytes, text)):
                msg = text(msg)
            oldcolors = None
            if self.hasmarkup and kw:
                handle = GetStdHandle(STD_OUTPUT_HANDLE)
                oldcolors = GetConsoleInfo(handle).wAttributes
                default_bg = oldcolors & 0x00F0
                attr = default_bg
                if kw.pop('bold', False):
                    attr |= FOREGROUND_INTENSITY

                if kw.pop('red', False):
                    attr |= FOREGROUND_RED
                elif kw.pop('blue', False):
                    attr |= FOREGROUND_BLUE
                elif kw.pop('green', False):
                    attr |= FOREGROUND_GREEN
                elif kw.pop('yellow', False):
                    attr |= FOREGROUND_GREEN|FOREGROUND_RED
                else:
                    attr |= oldcolors & 0x0007

                SetConsoleTextAttribute(handle, attr)
            write_out(self._file, msg)
            if oldcolors:
                SetConsoleTextAttribute(handle, oldcolors)

class WriteFile(object):
    def __init__(self, writemethod, encoding=None):
        self.encoding = encoding
        self._writemethod = writemethod

    def write(self, data):
        if self.encoding:
            data = data.encode(self.encoding, "replace")
        self._writemethod(data)

    def flush(self):
        return


if win32_and_ctypes:
    TerminalWriter = Win32ConsoleWriter
    import ctypes
    from ctypes import wintypes

    # ctypes access to the Windows console
    STD_OUTPUT_HANDLE = -11
    STD_ERROR_HANDLE  = -12
    FOREGROUND_BLACK     = 0x0000 # black text
    FOREGROUND_BLUE      = 0x0001 # text color contains blue.
    FOREGROUND_GREEN     = 0x0002 # text color contains green.
    FOREGROUND_RED       = 0x0004 # text color contains red.
    FOREGROUND_WHITE     = 0x0007
    FOREGROUND_INTENSITY = 0x0008 # text color is intensified.
    BACKGROUND_BLACK     = 0x0000 # background color black
    BACKGROUND_BLUE      = 0x0010 # background color contains blue.
    BACKGROUND_GREEN     = 0x0020 # background color contains green.
    BACKGROUND_RED       = 0x0040 # background color contains red.
    BACKGROUND_WHITE     = 0x0070
    BACKGROUND_INTENSITY = 0x0080 # background color is intensified.

    SHORT = ctypes.c_short
    class COORD(ctypes.Structure):
        _fields_ = [('X', SHORT),
                    ('Y', SHORT)]
    class SMALL_RECT(ctypes.Structure):
        _fields_ = [('Left', SHORT),
                    ('Top', SHORT),
                    ('Right', SHORT),
                    ('Bottom', SHORT)]
    class CONSOLE_SCREEN_BUFFER_INFO(ctypes.Structure):
        _fields_ = [('dwSize', COORD),
                    ('dwCursorPosition', COORD),
                    ('wAttributes', wintypes.WORD),
                    ('srWindow', SMALL_RECT),
                    ('dwMaximumWindowSize', COORD)]

    _GetStdHandle = ctypes.windll.kernel32.GetStdHandle
    _GetStdHandle.argtypes = [wintypes.DWORD]
    _GetStdHandle.restype = wintypes.HANDLE
    def GetStdHandle(kind):
        return _GetStdHandle(kind)

    SetConsoleTextAttribute = ctypes.windll.kernel32.SetConsoleTextAttribute
    SetConsoleTextAttribute.argtypes = [wintypes.HANDLE, wintypes.WORD]
    SetConsoleTextAttribute.restype = wintypes.BOOL

    _GetConsoleScreenBufferInfo = \
        ctypes.windll.kernel32.GetConsoleScreenBufferInfo
    _GetConsoleScreenBufferInfo.argtypes = [wintypes.HANDLE,
                                ctypes.POINTER(CONSOLE_SCREEN_BUFFER_INFO)]
    _GetConsoleScreenBufferInfo.restype = wintypes.BOOL
    def GetConsoleInfo(handle):
        info = CONSOLE_SCREEN_BUFFER_INFO()
        _GetConsoleScreenBufferInfo(handle, ctypes.byref(info))
        return info

    def _getdimensions():
        handle = GetStdHandle(STD_OUTPUT_HANDLE)
        info = GetConsoleInfo(handle)
        # Substract one from the width, otherwise the cursor wraps
        # and the ending \n causes an empty line to display.
        return info.dwSize.Y, info.dwSize.X - 1

def write_out(fil, msg):
    # XXX sometimes "msg" is of type bytes, sometimes text which
    # complicates the situation.  Should we try to enforce unicode?
    try:
        # on py27 and above writing out to sys.stdout with an encoding
        # should usually work for unicode messages (if the encoding is
        # capable of it)
        fil.write(msg)
    except UnicodeEncodeError:
        # on py26 it might not work because stdout expects bytes
        if fil.encoding:
            try:
                fil.write(msg.encode(fil.encoding))
            except UnicodeEncodeError:
                # it might still fail if the encoding is not capable
                pass
            else:
                fil.flush()
                return
        # fallback: escape all unicode characters
        msg = msg.encode("unicode-escape").decode("ascii")
        fil.write(msg)
    fil.flush()
