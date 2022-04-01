
""" Module for keeping detailed information about
times of certain driver parts
"""

import time
import py
from rpython.tool.ansi_print import AnsiLogger
log = AnsiLogger("Timer")

class Timer(object):
    def __init__(self, timer=time.time):
        self.events = []
        self.next_even = None
        self.timer = timer
        self.t0 = None

    def start_event(self, event):
        now = self.timer()
        if self.t0 is None:
            self.t0 = now
        self.next_event = event
        self.start_time = now

    def end_event(self, event):
        assert self.next_event == event
        now = self.timer()
        self.events.append((event, now - self.start_time))
        self.next_event = None
        self.tk = now

    def ttime(self):
        try:
            return self.tk - self.t0
        except AttributeError:
            return 0.0

    def pprint(self):
        """ Pretty print
        """
        spacing = " "*(30 - len("Total:"))
        total = "Total:%s --- %.1f s" % (spacing, self.ttime())
        log.bold("Timings:")
        for event, time in self.events:
            spacing = " "*(30 - len(event))
            first = "%s%s --- " % (event, spacing)
            second = "%.1f s" % (time,)
            additional_spaces = " " * (len(total) - len(first) - len(second))
            log.bold("%s%s%s" % (first, additional_spaces, second))
        log.bold("=" * len(total))
        log.bold(total)

