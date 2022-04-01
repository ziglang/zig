# Copyright: 2009 Nadia Alramli
# License: BSD

"""Terminal controller module
Example of usage:
    print BG_BLUE + 'Text on blue background' + NORMAL
    print BLUE + UNDERLINE + 'Blue underlined text' + NORMAL
    print BLUE + BG_YELLOW + BOLD + 'text' + NORMAL
"""

import sys

# The current module
MODULE = sys.modules[__name__]

COLORS = "BLUE GREEN CYAN RED MAGENTA YELLOW WHITE BLACK".split()
# List of terminal controls, you can add more to the list.
CONTROLS = {
    'BOL':'cr', 'UP':'cuu1', 'DOWN':'cud1', 'LEFT':'cub1', 'RIGHT':'cuf1',
    'CLEAR_SCREEN':'clear', 'CLEAR_EOL':'el', 'CLEAR_BOL':'el1',
    'CLEAR_EOS':'ed', 'BOLD':'bold', 'BLINK':'blink', 'DIM':'dim',
    'REVERSE':'rev', 'UNDERLINE':'smul', 'NORMAL':'sgr0',
    'HIDE_CURSOR':'cinvis', 'SHOW_CURSOR':'cnorm'
}

# List of numeric capabilities
VALUES = {
    'COLUMNS':'cols', # Width of the terminal (80 for unknown)
    'LINES':'lines',  # Height of the terminal (25 for unknown)
    'MAX_COLORS': 'colors',
}

def default():
    """Set the default attribute values"""
    for color in COLORS:
        setattr(MODULE, color, '')
        setattr(MODULE, 'BG_%s' % color, '')
    for control in CONTROLS:
        setattr(MODULE, control, '')
    MODULE.COLUMNS = 80
    MODULE.LINES = 25
    MODULE.MAX_COLORS = 1

def setup():
    """Set the terminal control strings"""
    # Initializing the terminal
    curses.setupterm()
    # Get the color escape sequence template or '' if not supported
    # setab and setaf are for ANSI escape sequences
    bgColorSeq = curses.tigetstr('setab') or curses.tigetstr('setb') or ''
    fgColorSeq = curses.tigetstr('setaf') or curses.tigetstr('setf') or ''

    for color in COLORS:
        # Get the color index from curses
        colorIndex = getattr(curses, 'COLOR_%s' % color)
        # Set the color escape sequence after filling the template with index
        setattr(MODULE, color, curses.tparm(fgColorSeq, colorIndex))
        # Set background escape sequence
        setattr(
            MODULE, 'BG_%s' % color, curses.tparm(bgColorSeq, colorIndex)
        )
    for control in CONTROLS:
        # Set the control escape sequence
        setattr(MODULE, control, curses.tigetstr(CONTROLS[control]) or '')
    if hasattr(curses, 'tigetnum'):
        for value in VALUES:
            # Set terminal related values
            setattr(MODULE, value, curses.tigetnum(VALUES[value]))

def render(text):
    """Helper function to apply controls easily
    Example:
    apply("%(GREEN)s%(BOLD)stext%(NORMAL)s") -> a bold green text
    """
    return text % MODULE.__dict__

try:
    import curses
    setup()
except Exception as e:
    # There is a failure; set all attributes to default
    print 'Warning: %s' % e
    default()
