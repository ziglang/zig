#   Copyright 2000-2007 Michael Hudson-Doyle <micahel@gmail.com>
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

"""Wedge pyrepl behaviour into cmd.Cmd-derived classes.

replize, when given a subclass of cmd.Cmd, returns a class that
behaves almost identically to the supplied class, except that it uses
pyrepl instead if raw_input.

It was designed to let you do this:

>>> import pdb
>>> from pyrepl import replize
>>> pdb.Pdb = replize(pdb.Pdb)

which is in fact done by the `pythoni' script that comes with
pyrepl."""

from __future__ import print_function

from pyrepl import completing_reader as cr, reader, completer
from pyrepl.completing_reader import CompletingReader as CR
import cmd

class CmdReader(CR):
    def collect_keymap(self):
        return super(CmdReader, self).collect_keymap() + (
            ("\\M-\\n", "invalid-key"),
            ("\\n", "accept"))
    
    CR_init = CR.__init__
    def __init__(self, completions):
        self.CR_init(self)
        self.completions = completions

    def get_completions(self, stem):
        if len(stem) != self.pos:
            return []
        return sorted(set(s for s in self.completions
                           if s.startswith(stem)))

def replize(klass, history_across_invocations=1):

    """Return a subclass of the cmd.Cmd-derived klass that uses
    pyrepl instead of readline.

    Raises a ValueError if klass does not derive from cmd.Cmd.

    The optional history_across_invocations parameter (default 1)
    controls whether instances of the returned class share
    histories."""

    completions = [s[3:]
                   for s in completer.get_class_members(klass)
                   if s.startswith("do_")]

    if not issubclass(klass, cmd.Cmd):
        raise Exception
#    if klass.cmdloop.im_class is not cmd.Cmd:
#        print "this may not work"

    class CmdRepl(klass):
        k_init = klass.__init__

        if history_across_invocations:
            _CmdRepl__history = []
            def __init__(self, *args, **kw):
                self.k_init(*args, **kw)
                self.__reader = CmdReader(completions)
                self.__reader.history = CmdRepl._CmdRepl__history
                self.__reader.historyi = len(CmdRepl._CmdRepl__history)
        else:
            def __init__(self, *args, **kw):
                self.k_init(*args, **kw)
                self.__reader = CmdReader(completions)
        
        def cmdloop(self, intro=None):
            self.preloop()
            if intro is not None:
                self.intro = intro
            if self.intro:
                print(self.intro)
            stop = None
            while not stop:
                if self.cmdqueue:
                    line = self.cmdqueue[0]
                    del self.cmdqueue[0]
                else:
                    try:
                        self.__reader.ps1 = self.prompt
                        line = self.__reader.readline()
                    except EOFError:
                        line = "EOF"
                line = self.precmd(line)
                stop = self.onecmd(line)
                stop = self.postcmd(stop, line)
            self.postloop()

    CmdRepl.__name__ = "replize(%s.%s)"%(klass.__module__, klass.__name__)
    return CmdRepl

