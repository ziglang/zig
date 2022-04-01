import builtins
import keyword
import re
import time

from idlelib.config import idleConf
from idlelib.delegator import Delegator

DEBUG = False


def any(name, alternates):
    "Return a named group pattern matching list of alternates."
    return "(?P<%s>" % name + "|".join(alternates) + ")"


def make_pat():
    kw = r"\b" + any("KEYWORD", keyword.kwlist) + r"\b"
    builtinlist = [str(name) for name in dir(builtins)
                   if not name.startswith('_') and
                   name not in keyword.kwlist]
    builtin = r"([^.'\"\\#]\b|^)" + any("BUILTIN", builtinlist) + r"\b"
    comment = any("COMMENT", [r"#[^\n]*"])
    stringprefix = r"(?i:r|u|f|fr|rf|b|br|rb)?"
    sqstring = stringprefix + r"'[^'\\\n]*(\\.[^'\\\n]*)*'?"
    dqstring = stringprefix + r'"[^"\\\n]*(\\.[^"\\\n]*)*"?'
    sq3string = stringprefix + r"'''[^'\\]*((\\.|'(?!''))[^'\\]*)*(''')?"
    dq3string = stringprefix + r'"""[^"\\]*((\\.|"(?!""))[^"\\]*)*(""")?'
    string = any("STRING", [sq3string, dq3string, sqstring, dqstring])
    return (kw + "|" + builtin + "|" + comment + "|" + string +
            "|" + any("SYNC", [r"\n"]))


prog = re.compile(make_pat(), re.S)
idprog = re.compile(r"\s+(\w+)", re.S)


def color_config(text):
    """Set color options of Text widget.

    If ColorDelegator is used, this should be called first.
    """
    # Called from htest, TextFrame, Editor, and Turtledemo.
    # Not automatic because ColorDelegator does not know 'text'.
    theme = idleConf.CurrentTheme()
    normal_colors = idleConf.GetHighlight(theme, 'normal')
    cursor_color = idleConf.GetHighlight(theme, 'cursor')['foreground']
    select_colors = idleConf.GetHighlight(theme, 'hilite')
    text.config(
        foreground=normal_colors['foreground'],
        background=normal_colors['background'],
        insertbackground=cursor_color,
        selectforeground=select_colors['foreground'],
        selectbackground=select_colors['background'],
        inactiveselectbackground=select_colors['background'],  # new in 8.5
        )


class ColorDelegator(Delegator):
    """Delegator for syntax highlighting (text coloring).

    Instance variables:
        delegate: Delegator below this one in the stack, meaning the
                one this one delegates to.

        Used to track state:
        after_id: Identifier for scheduled after event, which is a
                timer for colorizing the text.
        allow_colorizing: Boolean toggle for applying colorizing.
        colorizing: Boolean flag when colorizing is in process.
        stop_colorizing: Boolean flag to end an active colorizing
                process.
    """

    def __init__(self):
        Delegator.__init__(self)
        self.init_state()
        self.prog = prog
        self.idprog = idprog
        self.LoadTagDefs()

    def init_state(self):
        "Initialize variables that track colorizing state."
        self.after_id = None
        self.allow_colorizing = True
        self.stop_colorizing = False
        self.colorizing = False

    def setdelegate(self, delegate):
        """Set the delegate for this instance.

        A delegate is an instance of a Delegator class and each
        delegate points to the next delegator in the stack.  This
        allows multiple delegators to be chained together for a
        widget.  The bottom delegate for a colorizer is a Text
        widget.

        If there is a delegate, also start the colorizing process.
        """
        if self.delegate is not None:
            self.unbind("<<toggle-auto-coloring>>")
        Delegator.setdelegate(self, delegate)
        if delegate is not None:
            self.config_colors()
            self.bind("<<toggle-auto-coloring>>", self.toggle_colorize_event)
            self.notify_range("1.0", "end")
        else:
            # No delegate - stop any colorizing.
            self.stop_colorizing = True
            self.allow_colorizing = False

    def config_colors(self):
        "Configure text widget tags with colors from tagdefs."
        for tag, cnf in self.tagdefs.items():
            self.tag_configure(tag, **cnf)
        self.tag_raise('sel')

    def LoadTagDefs(self):
        "Create dictionary of tag names to text colors."
        theme = idleConf.CurrentTheme()
        self.tagdefs = {
            "COMMENT": idleConf.GetHighlight(theme, "comment"),
            "KEYWORD": idleConf.GetHighlight(theme, "keyword"),
            "BUILTIN": idleConf.GetHighlight(theme, "builtin"),
            "STRING": idleConf.GetHighlight(theme, "string"),
            "DEFINITION": idleConf.GetHighlight(theme, "definition"),
            "SYNC": {'background': None, 'foreground': None},
            "TODO": {'background': None, 'foreground': None},
            "ERROR": idleConf.GetHighlight(theme, "error"),
            # "hit" is used by ReplaceDialog to mark matches. It shouldn't be changed by Colorizer, but
            # that currently isn't technically possible. This should be moved elsewhere in the future
            # when fixing the "hit" tag's visibility, or when the replace dialog is replaced with a
            # non-modal alternative.
            "hit": idleConf.GetHighlight(theme, "hit"),
            }

        if DEBUG: print('tagdefs', self.tagdefs)

    def insert(self, index, chars, tags=None):
        "Insert chars into widget at index and mark for colorizing."
        index = self.index(index)
        self.delegate.insert(index, chars, tags)
        self.notify_range(index, index + "+%dc" % len(chars))

    def delete(self, index1, index2=None):
        "Delete chars between indexes and mark for colorizing."
        index1 = self.index(index1)
        self.delegate.delete(index1, index2)
        self.notify_range(index1)

    def notify_range(self, index1, index2=None):
        "Mark text changes for processing and restart colorizing, if active."
        self.tag_add("TODO", index1, index2)
        if self.after_id:
            if DEBUG: print("colorizing already scheduled")
            return
        if self.colorizing:
            self.stop_colorizing = True
            if DEBUG: print("stop colorizing")
        if self.allow_colorizing:
            if DEBUG: print("schedule colorizing")
            self.after_id = self.after(1, self.recolorize)
        return

    def close(self):
        if self.after_id:
            after_id = self.after_id
            self.after_id = None
            if DEBUG: print("cancel scheduled recolorizer")
            self.after_cancel(after_id)
        self.allow_colorizing = False
        self.stop_colorizing = True

    def toggle_colorize_event(self, event=None):
        """Toggle colorizing on and off.

        When toggling off, if colorizing is scheduled or is in
        process, it will be cancelled and/or stopped.

        When toggling on, colorizing will be scheduled.
        """
        if self.after_id:
            after_id = self.after_id
            self.after_id = None
            if DEBUG: print("cancel scheduled recolorizer")
            self.after_cancel(after_id)
        if self.allow_colorizing and self.colorizing:
            if DEBUG: print("stop colorizing")
            self.stop_colorizing = True
        self.allow_colorizing = not self.allow_colorizing
        if self.allow_colorizing and not self.colorizing:
            self.after_id = self.after(1, self.recolorize)
        if DEBUG:
            print("auto colorizing turned",
                  "on" if self.allow_colorizing else "off")
        return "break"

    def recolorize(self):
        """Timer event (every 1ms) to colorize text.

        Colorizing is only attempted when the text widget exists,
        when colorizing is toggled on, and when the colorizing
        process is not already running.

        After colorizing is complete, some cleanup is done to
        make sure that all the text has been colorized.
        """
        self.after_id = None
        if not self.delegate:
            if DEBUG: print("no delegate")
            return
        if not self.allow_colorizing:
            if DEBUG: print("auto colorizing is off")
            return
        if self.colorizing:
            if DEBUG: print("already colorizing")
            return
        try:
            self.stop_colorizing = False
            self.colorizing = True
            if DEBUG: print("colorizing...")
            t0 = time.perf_counter()
            self.recolorize_main()
            t1 = time.perf_counter()
            if DEBUG: print("%.3f seconds" % (t1-t0))
        finally:
            self.colorizing = False
        if self.allow_colorizing and self.tag_nextrange("TODO", "1.0"):
            if DEBUG: print("reschedule colorizing")
            self.after_id = self.after(1, self.recolorize)

    def recolorize_main(self):
        "Evaluate text and apply colorizing tags."
        next = "1.0"
        while True:
            item = self.tag_nextrange("TODO", next)
            if not item:
                break
            head, tail = item
            self.tag_remove("SYNC", head, tail)
            item = self.tag_prevrange("SYNC", head)
            head = item[1] if item else "1.0"

            chars = ""
            next = head
            lines_to_get = 1
            ok = False
            while not ok:
                mark = next
                next = self.index(mark + "+%d lines linestart" %
                                         lines_to_get)
                lines_to_get = min(lines_to_get * 2, 100)
                ok = "SYNC" in self.tag_names(next + "-1c")
                line = self.get(mark, next)
                ##print head, "get", mark, next, "->", repr(line)
                if not line:
                    return
                for tag in self.tagdefs:
                    self.tag_remove(tag, mark, next)
                chars = chars + line
                m = self.prog.search(chars)
                while m:
                    for key, value in m.groupdict().items():
                        if value:
                            a, b = m.span(key)
                            self.tag_add(key,
                                         head + "+%dc" % a,
                                         head + "+%dc" % b)
                            if value in ("def", "class"):
                                m1 = self.idprog.match(chars, b)
                                if m1:
                                    a, b = m1.span(1)
                                    self.tag_add("DEFINITION",
                                                 head + "+%dc" % a,
                                                 head + "+%dc" % b)
                    m = self.prog.search(chars, m.end())
                if "SYNC" in self.tag_names(next + "-1c"):
                    head = next
                    chars = ""
                else:
                    ok = False
                if not ok:
                    # We're in an inconsistent state, and the call to
                    # update may tell us to stop.  It may also change
                    # the correct value for "next" (since this is a
                    # line.col string, not a true mark).  So leave a
                    # crumb telling the next invocation to resume here
                    # in case update tells us to leave.
                    self.tag_add("TODO", next)
                self.update()
                if self.stop_colorizing:
                    if DEBUG: print("colorizing stopped")
                    return

    def removecolors(self):
        "Remove all colorizing tags."
        for tag in self.tagdefs:
            self.tag_remove(tag, "1.0", "end")


def _color_delegator(parent):  # htest #
    from tkinter import Toplevel, Text
    from idlelib.percolator import Percolator

    top = Toplevel(parent)
    top.title("Test ColorDelegator")
    x, y = map(int, parent.geometry().split('+')[1:])
    top.geometry("700x250+%d+%d" % (x + 20, y + 175))
    source = (
        "if True: int ('1') # keyword, builtin, string, comment\n"
        "elif False: print(0)\n"
        "else: float(None)\n"
        "if iF + If + IF: 'keyword matching must respect case'\n"
        "if'': x or''  # valid keyword-string no-space combinations\n"
        "async def f(): await g()\n"
        "# All valid prefixes for unicode and byte strings should be colored.\n"
        "'x', '''x''', \"x\", \"\"\"x\"\"\"\n"
        "r'x', u'x', R'x', U'x', f'x', F'x'\n"
        "fr'x', Fr'x', fR'x', FR'x', rf'x', rF'x', Rf'x', RF'x'\n"
        "b'x',B'x', br'x',Br'x',bR'x',BR'x', rb'x', rB'x',Rb'x',RB'x'\n"
        "# Invalid combinations of legal characters should be half colored.\n"
        "ur'x', ru'x', uf'x', fu'x', UR'x', ufr'x', rfu'x', xf'x', fx'x'\n"
        )
    text = Text(top, background="white")
    text.pack(expand=1, fill="both")
    text.insert("insert", source)
    text.focus_set()

    color_config(text)
    p = Percolator(text)
    d = ColorDelegator()
    p.insertfilter(d)


if __name__ == "__main__":
    from unittest import main
    main('idlelib.idle_test.test_colorizer', verbosity=2, exit=False)

    from idlelib.idle_test.htest import run
    run(_color_delegator)
