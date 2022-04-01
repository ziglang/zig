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

from __future__ import print_function
from contextlib import contextmanager
import os

from pyrepl.reader import Reader
from pyrepl.console import Console, Event


class EqualsAnything(object):
    def __eq__(self, other):
        return True


EA = EqualsAnything()


class TestConsole(Console):
    height = 24
    width = 80
    encoding = 'utf-8'

    def __init__(self, events, verbose=False):
        self.events = events
        self.next_screen = None
        self.verbose = verbose

    def refresh(self, screen, xy):
        if self.next_screen is not None:
                assert screen == self.next_screen, "[ %s != %s after %r ]" % (
                    screen, self.next_screen, self.last_event_name)

    def get_event(self, block=1):
        ev, sc = self.events.pop(0)
        self.next_screen = sc
        if not isinstance(ev, tuple):
            ev = (ev, None)
        self.last_event_name = ev[0]
        if self.verbose:
            print("event", ev)
        return Event(*ev)


    def getpending(self):
        """Nothing pending, but do not return None here."""
        return Event('key', '', b'')


class BaseTestReader(Reader):

    def get_prompt(self, lineno, cursor_on_line):
        return ''

    def refresh(self):
        Reader.refresh(self)
        self.dirty = True


def read_spec(test_spec, reader_class=BaseTestReader):
    # remember to finish your test_spec with 'accept' or similar!
    con = TestConsole(test_spec, verbose=True)
    reader = reader_class(con)
    reader.readline()


@contextmanager
def sane_term():
    """Ensure a TERM that supports clear"""
    old_term, os.environ['TERM'] = os.environ.get('TERM'), 'xterm'
    yield
    if old_term is not None:
        os.environ['TERM'] = old_term
    else:
        del os.environ['TERM']
