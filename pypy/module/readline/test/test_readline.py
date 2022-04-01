# -*- coding: utf-8 -*-
import sys
import pytest

def setup_module(mod):
    try:
        import curses
        curses.setupterm()
    except:
        pytest.skip("Cannot test this here")


class AppTestReadline:
    spaceconfig = dict(usemodules=[
        'unicodedata', 'select', 'signal', 
        '_minimal_curses', 'faulthandler', '_socket', 'binascii',
        '_posixsubprocess',
    ])
    if sys.platform == 'win32':
        pass
    else:
        spaceconfig['usemodules'] += ['fcntl', 'termios']

    def test_nonascii_history(self):
        import os, readline
        TESTFN = "{}_{}_tmp".format("@test", os.getpid())

        is_editline = readline.__doc__ and "libedit" in readline.__doc__

        readline.clear_history()
        try:
            readline.add_history("entrée 1")
        except UnicodeEncodeError as err:
            skip("Locale cannot encode test data: " + format(err))
        readline.add_history("entrée 2")
        readline.replace_history_item(1, "entrée 22")
        readline.write_history_file(TESTFN)
        readline.clear_history()
        readline.read_history_file(TESTFN)
        if is_editline:
            # An add_history() call seems to be required for get_history_
            # item() to register items from the file
            readline.add_history("dummy")
        assert readline.get_history_item(1) ==  "entrée 1"
        assert readline.get_history_item(2) == "entrée 22"


    def test_insert_text_leading_tab(self):
        """
        A literal tab can be inserted at the beginning of a line.

        See <https://bugs.python.org/issue25660>
        """
        import readline
        readline.insert_text("\t")
        assert readline.get_line_buffer() == b"\t"
