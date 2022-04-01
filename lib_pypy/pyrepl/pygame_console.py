#   Copyright 2000-2004 Michael Hudson-Doyle <micahel@gmail.com>
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

# the pygame console is currently thoroughly broken.

# there's a fundamental difference from the UnixConsole: here we're
# the terminal emulator too, in effect.  This means, e.g., for pythoni
# we really need a separate process (or thread) to monitor for ^C
# during command execution and zap the executor process.  Making this
# work on non-Unix is expected to be even more entertaining.

from pygame.locals import *
from pyrepl.console import Console, Event
from pyrepl import pygame_keymap
import pygame
import types

lmargin = 5
rmargin = 5
tmargin = 5
bmargin = 5

try:
    bool
except NameError:
    def bool(x):
        return not not x

modcolors = {K_LCTRL:1,
             K_RCTRL:1,
             K_LMETA:1,
             K_RMETA:1,
             K_LALT:1,
             K_RALT:1,
             K_LSHIFT:1,
             K_RSHIFT:1}

class colors:
    fg = 250,240,230
    bg = 5, 5, 5
    cursor = 230, 0, 230
    margin = 5, 5, 15

class FakeStdout:
    def __init__(self, con):
        self.con = con
    def write(self, text):
        self.con.write(text)
    def flush(self):
        pass

class FakeStdin:
    def __init__(self, con):
        self.con = con
    def read(self, n=None):
        # argh!
        raise NotImplementedError
    def readline(self, n=None):
        from reader import Reader
        try:
            # this isn't quite right: it will clobber any prompt that's
            # been printed.  Not sure how to get around this...
            return Reader(self.con).readline()
        except EOFError:
            return ''

class PyGameConsole(Console):
    """Attributes:

    (keymap),
    (fd),
    screen,
    height,
    width,
    """
    
    def __init__(self):
        self.pygame_screen = pygame.display.set_mode((800, 600))
        pygame.font.init()
        pygame.key.set_repeat(500, 30)
        self.font = pygame.font.Font(
            "/usr/X11R6/lib/X11/fonts/TTF/luximr.ttf", 15)
        self.fw, self.fh = self.fontsize = self.font.size("X")
        self.cursor = pygame.Surface(self.fontsize)
        self.cursor.fill(colors.cursor)
        self.clear()
        self.curs_vis = 1
        self.height, self.width = self.getheightwidth()
        pygame.display.update()
        pygame.event.set_allowed(None)
        pygame.event.set_allowed(KEYDOWN)
        
    def install_keymap(self, keymap):
        """Install a given keymap.

        keymap is a tuple of 2-element tuples; each small tuple is a
        pair (keyspec, event-name).  The format for keyspec is
        modelled on that used by readline (so read that manual for
        now!)."""
        self.k = self.keymap = pygame_keymap.compile_keymap(keymap)

    def char_rect(self, x, y):
        return self.char_pos(x, y), self.fontsize

    def char_pos(self, x, y):
        return (lmargin + x*self.fw,
                tmargin + y*self.fh + self.cur_top + self.scroll)

    def paint_margin(self):
        s = self.pygame_screen
        c = colors.margin
        s.fill(c, [0, 0, 800, tmargin])
        s.fill(c, [0, 0, lmargin, 600])
        s.fill(c, [0, 600 - bmargin, 800, bmargin])
        s.fill(c, [800 - rmargin, 0, lmargin, 600])

    def refresh(self, screen, cxy):
        self.screen = screen
        self.pygame_screen.fill(colors.bg,
                                [0, tmargin + self.cur_top + self.scroll,
                                 800, 600])
        self.paint_margin()

        line_top = self.cur_top
        width, height = self.fontsize
        cx, cy = cxy
        self.cxy = (cx, cy)
        cp = self.char_pos(cx, cy)
        if cp[1] < tmargin:
            self.scroll = - (cy*self.fh + self.cur_top)
            self.repaint()
        elif cp[1] + self.fh > 600 - bmargin:
            self.scroll += (600 - bmargin) - (cp[1] + self.fh)
            self.repaint()
        if self.curs_vis:
            self.pygame_screen.blit(self.cursor, self.char_pos(cx, cy))
        for line in screen:
            if 0 <= line_top + self.scroll <= (600 - bmargin - tmargin - self.fh):
                if line:
                    ren = self.font.render(line, 1, colors.fg)
                    self.pygame_screen.blit(ren, (lmargin,
                                                  tmargin + line_top + self.scroll))
            line_top += self.fh
        pygame.display.update()

    def prepare(self):
        self.cmd_buf = ''
        self.k = self.keymap
        self.height, self.width = self.getheightwidth()
        self.curs_vis = 1
        self.cur_top = self.pos[0]
        self.event_queue = []

    def restore(self):
        pass

    def blit_a_char(self, linen, charn):
        line = self.screen[linen]
        if charn < len(line):
            text = self.font.render(line[charn], 1, colors.fg)
            self.pygame_screen.blit(text, self.char_pos(charn, linen))

    def move_cursor(self, x, y):
        cp = self.char_pos(x, y)
        if cp[1] < tmargin or cp[1] + self.fh > 600 - bmargin:
            self.event_queue.append(Event('refresh', '', ''))
        else:
            if self.curs_vis:
                cx, cy = self.cxy
                self.pygame_screen.fill(colors.bg, self.char_rect(cx, cy))
                self.blit_a_char(cy, cx)
                self.pygame_screen.blit(self.cursor, cp)
                self.blit_a_char(y, x)
                pygame.display.update()
            self.cxy = (x, y)

    def set_cursor_vis(self, vis):
        self.curs_vis = vis
        if vis:
            self.move_cursor(*self.cxy)
        else:
            cx, cy = self.cxy
            self.pygame_screen.fill(colors.bg, self.char_rect(cx, cy))
            self.blit_a_char(cy, cx)
            pygame.display.update()

    def getheightwidth(self):
        """Return (height, width) where height and width are the height
        and width of the terminal window in characters."""
        return ((600 - tmargin - bmargin)/self.fh,
                (800 - lmargin - rmargin)/self.fw)

    def tr_event(self, pyg_event):
        shift = bool(pyg_event.mod & KMOD_SHIFT)
        ctrl = bool(pyg_event.mod & KMOD_CTRL)
        meta = bool(pyg_event.mod & (KMOD_ALT|KMOD_META))

        try:
            return self.k[(pyg_event.unicode, meta, ctrl)], pyg_event.unicode
        except KeyError:
            try:
                return self.k[(pyg_event.key, meta, ctrl)], pyg_event.unicode
            except KeyError:
                return "invalid-key", pyg_event.unicode

    def get_event(self, block=1):
        """Return an Event instance.  Returns None if |block| is false
        and there is no event pending, otherwise waits for the
        completion of an event."""
        while 1:
            if self.event_queue:
                return self.event_queue.pop(0)
            elif block:
                pyg_event = pygame.event.wait()
            else:
                pyg_event = pygame.event.poll()
                if pyg_event.type == NOEVENT:
                    return

            if pyg_event.key in modcolors:
                continue

            k, c = self.tr_event(pyg_event)
            self.cmd_buf += c.encode('ascii', 'replace')
            self.k = k

            if not isinstance(k, types.DictType):
                e = Event(k, self.cmd_buf, [])
                self.k = self.keymap
                self.cmd_buf = ''
                return e

    def beep(self):
        # uhh, can't be bothered now.
        # pygame.sound.something, I guess.
        pass

    def clear(self):
        """Wipe the screen"""
        self.pygame_screen.fill(colors.bg)
        #self.screen = []
        self.pos = [0, 0]
        self.grobs = []
        self.cur_top = 0
        self.scroll = 0

    def finish(self):
        """Move the cursor to the end of the display and otherwise get
        ready for end.  XXX could be merged with restore?  Hmm."""
        if self.curs_vis:
            cx, cy = self.cxy
            self.pygame_screen.fill(colors.bg, self.char_rect(cx, cy))
            self.blit_a_char(cy, cx)
        for line in self.screen:
            self.write_line(line, 1)
        if self.curs_vis:
            self.pygame_screen.blit(self.cursor,
                                    (lmargin + self.pos[1],
                                     tmargin + self.pos[0] + self.scroll))
        pygame.display.update()

    def flushoutput(self):
        """Flush all output to the screen (assuming there's some
        buffering going on somewhere)"""
        # no buffering here, ma'am (though perhaps there should be!)
        pass

    def forgetinput(self):
        """Forget all pending, but not yet processed input."""
        while pygame.event.poll().type != NOEVENT:
            pass
    
    def getpending(self):
        """Return the characters that have been typed but not yet
        processed."""
        events = []
        while 1:
            event = pygame.event.poll()
            if event.type == NOEVENT:
                break
            events.append(event)

        return events

    def wait(self):
        """Wait for an event."""
        raise Exception("erp!")

    def repaint(self):
        # perhaps we should consolidate grobs?
        self.pygame_screen.fill(colors.bg)
        self.paint_margin()
        for (y, x), surf, text in self.grobs:
            if surf and 0 < y + self.scroll:
                self.pygame_screen.blit(surf, (lmargin + x,
                                               tmargin + y + self.scroll))
        pygame.display.update()

    def write_line(self, line, ret):
        charsleft = (self.width*self.fw - self.pos[1])/self.fw
        while len(line) > charsleft:
            self.write_line(line[:charsleft], 1)
            line = line[charsleft:]
        if line:
            ren = self.font.render(line, 1, colors.fg, colors.bg)
            self.grobs.append((self.pos[:], ren, line))
            self.pygame_screen.blit(ren,
                                    (lmargin + self.pos[1],
                                     tmargin + self.pos[0] + self.scroll))
        else:
            self.grobs.append((self.pos[:], None, line))
        if ret:
            self.pos[0] += self.fh
            if tmargin + self.pos[0] + self.scroll + self.fh > 600 - bmargin:
                self.scroll = 600 - bmargin - self.pos[0] - self.fh - tmargin
                self.repaint()
            self.pos[1] = 0
        else:
            self.pos[1] += self.fw*len(line)

    def write(self, text):
        lines = text.split("\n")
        if self.curs_vis:
            self.pygame_screen.fill(colors.bg,
                                    (lmargin + self.pos[1],
                                     tmargin + self.pos[0] + self.scroll,
                                     self.fw, self.fh))
        for line in lines[:-1]:
            self.write_line(line, 1)
        self.write_line(lines[-1], 0)
        if self.curs_vis:
            self.pygame_screen.blit(self.cursor,
                                    (lmargin + self.pos[1],
                                     tmargin + self.pos[0] + self.scroll))
        pygame.display.update()

    def flush(self):
        pass
