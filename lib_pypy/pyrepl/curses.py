
#   Copyright 2000-2010 Michael Hudson-Doyle <micahel@gmail.com>
#                       Armin Rigo
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

# If we are running on top of pypy, we import only _minimal_curses.
# Don't try to fall back to _curses, because that's going to use cffi
# and fall again more loudly.
import sys
if '__pypy__' in sys.builtin_module_names:
    # pypy case
    import _minimal_curses as _curses
else:
    # cpython case
    try:
        import _curses
    except ImportError:
        # Who knows, maybe some environment has "curses" but not "_curses".
        # If not, at least the following import gives a clean ImportError.
        try:
            import curses as _curses
        except ImportError:
            import _curses

setupterm = _curses.setupterm
tigetstr = _curses.tigetstr
tparm = _curses.tparm
error = _curses.error
