#   Copyright 2000-2007 Michael Hudson-Doyle <micahel@gmail.com>
#                       Bob Ippolito
#                       Maciek Fijalkowski
#
#                        All Rights Reserved
#
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose is hereby granted without fee,
# provided that the above copyright notice appear in all copies and
# that both that copyright notice and this permission notice appear in
# supporting documentation.
#
# THE AUTHOR MICHAEL HUDSON DISCLAIMS ALL WARRANTIES WITH REGARD TO
# THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS, IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL,
# INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
# RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
# CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# one impressive collections of imports:
from __future__ import print_function
from __future__ import unicode_literals
from pyrepl.completing_reader import CompletingReader
from pyrepl.historical_reader import HistoricalReader
from pyrepl import completing_reader, reader
from pyrepl import commands, completer
from pyrepl import module_lister
import imp, sys, os, re, code, traceback
import atexit, warnings

try:
    unicode
except:
    unicode = str

try:
    imp.find_module("twisted")
except ImportError:
    default_interactmethod = "interact"
else:
    default_interactmethod = "twistedinteract"

CommandCompiler = code.CommandCompiler

def eat_it(*args):
    """this function eats warnings, if you were wondering"""
    pass

if sys.version_info >= (3,0):
    def _reraise(cls, val, tb):
        __tracebackhide__ = True
        assert hasattr(val, '__traceback__')
        raise val
else:
    exec ("""
def _reraise(cls, val, tb):
    __tracebackhide__ = True
    raise cls, val, tb
""")




class maybe_accept(commands.Command):
    def do(self):
        r = self.reader
        text = r.get_unicode()
        try:
            # ooh, look at the hack:
            code = r.compiler(text)
        except (OverflowError, SyntaxError, ValueError):
            self.finish = 1
        else:
            if code is None:
                r.insert("\n")
            else:
                self.finish = 1

from_line_prog = re.compile(
    "^from\s+(?P<mod>[A-Za-z_.0-9]*)\s+import\s+(?P<name>[A-Za-z_.0-9]*)")
import_line_prog = re.compile(
    "^(?:import|from)\s+(?P<mod>[A-Za-z_.0-9]*)\s*$")

def saver(reader=reader):
    try:
        with open(os.path.expanduser("~/.pythoni.hist"), "wb") as fp:
            fp.write(b'\n'.join(item.encode('unicode_escape')
                                for item in reader.history))
    except IOError as e:
        print(e)
        pass

class PythonicReader(CompletingReader, HistoricalReader):
    def collect_keymap(self):
        return super(PythonicReader, self).collect_keymap() + (
            (r'\n', 'maybe-accept'),
            (r'\M-\n', 'insert-nl'))
    
    def __init__(self, console, locals,
                 compiler=None):
        super(PythonicReader, self).__init__(console)
        self.completer = completer.Completer(locals)
        st = self.syntax_table
        for c in "._0123456789":
            st[c] = reader.SYNTAX_WORD
        self.locals = locals
        if compiler is None:
            self.compiler = CommandCompiler()
        else:
            self.compiler = compiler
        try:
            file = open(os.path.expanduser("~/.pythoni.hist"), 'rb')
        except IOError:
            self.history = []
        else:
            try:
                lines = file.readlines()
                self.history = [ x.rstrip(b'\n').decode('unicode_escape') for x in lines]
            except:
                self.history = []
            self.historyi = len(self.history)
            file.close()
        atexit.register(lambda: saver(self))
        for c in [maybe_accept]:
            self.commands[c.__name__] = c
            self.commands[c.__name__.replace('_', '-')] = c        
    
    def get_completions(self, stem):
        b = self.get_unicode()
        m = import_line_prog.match(b)
        if m:
            if not self._module_list_ready:
                module_lister._make_module_list()
                self._module_list_ready = True

            mod = m.group("mod")
            try:
                return module_lister.find_modules(mod)
            except ImportError:
                pass
        m = from_line_prog.match(b)
        if m:
            mod, name = m.group("mod", "name")
            try:
                l = module_lister._packages[mod]
            except KeyError:
                try:
                    mod = __import__(mod, self.locals, self.locals, [''])
                    return [x for x in dir(mod) if x.startswith(name)]
                except ImportError:
                    pass
            else:
                return [x[len(mod) + 1:]
                        for x in l if x.startswith(mod + '.' + name)]
        try:
            l = sorted(set(self.completer.complete(stem)))
            return l
        except (NameError, AttributeError):
            return []

class ReaderConsole(code.InteractiveInterpreter):
    II_init = code.InteractiveInterpreter.__init__
    def __init__(self, console, locals=None):
        if locals is None:
            locals = {}
        self.II_init(locals)
        self.compiler = CommandCompiler()
        self.compile = self.compiler.compiler
        self.reader = PythonicReader(console, locals, self.compiler)
        locals['Reader'] = self.reader

    def run_user_init_file(self):
        for key in "PYREPLSTARTUP", "PYTHONSTARTUP":
            initfile = os.environ.get(key)
            if initfile is not None and os.path.exists(initfile):
                break
        else:
            return
        try:
            execfile(initfile, self.locals, self.locals)
        except:
            etype, value, tb = sys.exc_info()
            traceback.print_exception(etype, value, tb.tb_next)

    def execute(self, text):
        try:
            # ooh, look at the hack:
            code = self.compile(text, '<stdin>', 'single')
        except (OverflowError, SyntaxError, ValueError):
            self.showsyntaxerror('<stdin>')
        else:
            self.runcode(code)
            if sys.stdout and not sys.stdout.closed:
                sys.stdout.flush()

    def interact(self):
        while 1:
            try: # catches EOFError's and KeyboardInterrupts during execution
                try: # catches KeyboardInterrupts during editing
                    try: # warning saver
                        # can't have warnings spewed onto terminal
                        sv = warnings.showwarning
                        warnings.showwarning = eat_it
                        l = unicode(self.reader.readline(), 'utf-8')
                    finally:
                        warnings.showwarning = sv
                except KeyboardInterrupt:
                    print("KeyboardInterrupt")
                else:
                    if l:
                        self.execute(l)
            except EOFError:
                break
            except KeyboardInterrupt:
                continue

    def prepare(self):
        self.sv_sw = warnings.showwarning
        warnings.showwarning = eat_it
        self.reader.prepare()
        self.reader.refresh() # we want :after methods...

    def restore(self):
        self.reader.restore()
        warnings.showwarning = self.sv_sw

    def handle1(self, block=1):
        try:
            r = 1
            r = self.reader.handle1(block)
        except KeyboardInterrupt:
            self.restore()
            print("KeyboardInterrupt")
            self.prepare()
        else:
            if self.reader.finished:
                text = self.reader.get_unicode()
                self.restore()
                if text:
                    self.execute(text)
                self.prepare()
        return r

    def tkfilehandler(self, file, mask):
        try:
            self.handle1(block=0)
        except:
            self.exc_info = sys.exc_info()

    # how the <expletive> do you get this to work on Windows (without
    # createfilehandler)?  threads, I guess
    def really_tkinteract(self):
        import _tkinter
        _tkinter.createfilehandler(
            self.reader.console.input_fd, _tkinter.READABLE,
            self.tkfilehandler)
        
        self.exc_info = None
        while 1:
            # dooneevent will return 0 without blocking if there are
            # no Tk windows, 1 after blocking until an event otherwise
            # so the following does what we want (this wasn't expected
            # to be obvious).
            if not _tkinter.dooneevent(_tkinter.ALL_EVENTS):
                self.handle1(block=1)
            if self.exc_info:
                type, value, tb = self.exc_info
                self.exc_info = None
                _reraise(type, value, tb)
        
    def tkinteract(self):
        """Run a Tk-aware Python interactive session.

        This function simulates the Python top-level in a way that
        allows Tk's mainloop to run."""
        
        # attempting to understand the control flow of this function
        # without help may cause internal injuries.  so, some
        # explanation.

        # The outer while loop is there to restart the interaction if
        # the user types control-c when execution is deep in our
        # innards.  I'm not sure this can't leave internals in an
        # inconsistent state, but it's a good start.

        # then the inside loop keeps calling self.handle1 until
        # _tkinter gets imported; then control shifts to
        # self.really_tkinteract, above.

        # this function can only return via an exception; we mask
        # EOFErrors (but they end the interaction) and
        # KeyboardInterrupts cause a restart.  All other exceptions
        # are likely bugs in pyrepl (well, 'cept for SystemExit, of
        # course).
        
        while 1:
            try:
                try:
                    self.prepare()
                    try:
                        while 1:
                            if sys.modules.has_key("_tkinter"):
                                self.really_tkinteract()
                                # really_tkinteract is not expected to
                                # return except via an exception, but:
                                break
                            self.handle1()
                    except EOFError:
                        pass
                finally:
                    self.restore()
            except KeyboardInterrupt:
                continue
            else:
                break

    def twistedinteract(self):
        from twisted.internet import reactor
        from twisted.internet.abstract import FileDescriptor
        import signal
        outerself = self
        class Me(FileDescriptor):
            def fileno(self):
                """ We want to select on FD 0 """
                return 0

            def doRead(self):
                """called when input is ready"""
                try:
                    outerself.handle1()
                except EOFError:
                    reactor.stop()

        reactor.addReader(Me())
        reactor.callWhenRunning(signal.signal,
                                signal.SIGINT,
                                signal.default_int_handler)
        self.prepare()
        try:
            reactor.run()
        finally:
            self.restore()
        

    def cocoainteract(self, inputfilehandle=None, outputfilehandle=None):
        # only call this when there's a run loop already going!
        # note that unlike the other *interact methods, this returns immediately
        from cocoasupport import CocoaInteracter
        self.cocoainteracter = CocoaInteracter.alloc().init(self, inputfilehandle, outputfilehandle)
        
        
def main(use_pygame_console=0, interactmethod=default_interactmethod, print_banner=True, clear_main=True):
    si, se, so = sys.stdin, sys.stderr, sys.stdout
    try:
        if 0 and use_pygame_console: # pygame currently borked
            from pyrepl.pygame_console import PyGameConsole, FakeStdin, FakeStdout
            con = PyGameConsole()
            sys.stderr = sys.stdout = FakeStdout(con)
            sys.stdin = FakeStdin(con)
        else:
            from pyrepl.unix_console import UnixConsole
            try:
                import locale
            except ImportError:
                encoding = None
            else:
                if hasattr(locale, 'nl_langinfo') \
                       and hasattr(locale, 'CODESET'):
                    encoding = locale.nl_langinfo(locale.CODESET)
                elif os.environ.get('TERM_PROGRAM') == 'Apple_Terminal':
                    # /me whistles innocently...
                    code = int(os.popen(
                        "defaults read com.apple.Terminal StringEncoding"
                        ).read())
                    if code == 4:
                        encoding = 'utf-8'
                        # More could go here -- and what's here isn't
                        # bulletproof.  What would be?  AppleScript?
                        # Doesn't seem to be possible.
                    else:
                        encoding = None
                else:
                    encoding = None # so you get ASCII...
            con = UnixConsole(os.dup(0), os.dup(1), None, encoding)
        if print_banner:
            print("Python", sys.version, "on", sys.platform)
            print('Type "help", "copyright", "credits" or "license" '\
                  'for more information.')
        sys.path.insert(0, os.getcwd())

        if clear_main and __name__ != '__main__':
            mainmod = imp.new_module('__main__')
            sys.modules['__main__'] = mainmod
        else:
            mainmod = sys.modules['__main__']

        rc = ReaderConsole(con, mainmod.__dict__)
        rc.reader._module_list_ready = False
        rc.run_user_init_file()
        getattr(rc, interactmethod)()
    finally:
        sys.stdin, sys.stderr, sys.stdout = si, se, so

if __name__ == '__main__':
    main()
