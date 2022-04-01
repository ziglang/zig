#   Copyright 2000-2008 Michael Hudson-Doyle <micahel@gmail.com>
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

# keyspec parsing for a pygame console.  currently this is simply copy
# n' change from the unix (ie. trad terminal) variant; probably some
# refactoring will happen when I work out how it will work best.

# A key is represented as *either*

# a) a (keycode, meta, ctrl) sequence (used for special keys such as
# f1, the up arrow key, etc)
# b) a (unichar, meta, ctrl) sequence (used for printable chars)

# Because we allow keystokes like '\\C-xu', I'll use the same trick as
# the unix keymap module uses.

# '\\C-a' --> (K_a, 0, 1)

# XXX it's actually possible to test this module, so it should have a
# XXX test suite.

from pygame.locals import *

_escapes = {
    '\\': K_BACKSLASH,
    "'" : K_QUOTE,
    '"' : K_QUOTEDBL,
#    'a' : '\a',
    'b' : K_BACKSLASH,
    'e' : K_ESCAPE,
#    'f' : '\f',
    'n' : K_RETURN,
    'r' : K_RETURN,
    't' : K_TAB,
#    'v' : '\v'
    }

_keynames = {
    'backspace' : K_BACKSPACE,
    'delete'    : K_DELETE,
    'down'      : K_DOWN,
    'end'       : K_END,
    'enter'     : K_KP_ENTER,
    'escape'    : K_ESCAPE,
    'f1' : K_F1, 'f2' : K_F2, 'f3' : K_F3, 'f4' : K_F4,
    'f5' : K_F5, 'f6' : K_F6, 'f7' : K_F7, 'f8' : K_F8,
    'f9' : K_F9, 'f10': K_F10,'f11': K_F11,'f12': K_F12,
    'f13': K_F13,'f14': K_F14,'f15': K_F15,
    'home'   : K_HOME,
    'insert' : K_INSERT,
    'left'   : K_LEFT,
    'pgdown' : K_PAGEDOWN, 'page down' : K_PAGEDOWN,
    'pgup'   : K_PAGEUP,   'page up'   : K_PAGEUP,
    'return' : K_RETURN,
    'right'  : K_RIGHT,
    'space'  : K_SPACE,
    'tab'    : K_TAB,
    'up'     : K_UP,
    }

class KeySpecError(Exception):
    pass

def _parse_key1(key, s):
    ctrl = 0
    meta = 0
    ret = ''
    while not ret and s < len(key):
        if key[s] == '\\':
            c = key[s+1].lower()
            if _escapes.has_key(c):
                ret = _escapes[c]
                s += 2
            elif c == "c":
                if key[s + 2] != '-':
                    raise KeySpecError(
                              "\\C must be followed by `-' (char %d of %s)"%(
                        s + 2, repr(key)))
                if ctrl:
                    raise KeySpecError("doubled \\C- (char %d of %s)"%(
                        s + 1, repr(key)))
                ctrl = 1
                s += 3
            elif c == "m":
                if key[s + 2] != '-':
                    raise KeySpecError(
                              "\\M must be followed by `-' (char %d of %s)"%(
                        s + 2, repr(key)))
                if meta:
                    raise KeySpecError("doubled \\M- (char %d of %s)"%(
                        s + 1, repr(key)))
                meta = 1
                s += 3
            elif c.isdigit():
                n = key[s+1:s+4]
                ret = chr(int(n, 8))
                s += 4
            elif c == 'x':
                n = key[s+2:s+4]
                ret = chr(int(n, 16))
                s += 4
            elif c == '<':
                t = key.find('>', s)
                if t == -1:
                    raise KeySpecError(
                              "unterminated \\< starting at char %d of %s"%(
                        s + 1, repr(key)))
                try:
                    ret = _keynames[key[s+2:t].lower()]
                    s = t + 1
                except KeyError:
                    raise KeySpecError(
                              "unrecognised keyname `%s' at char %d of %s"%(
                        key[s+2:t], s + 2, repr(key)))
                if ret is None:
                    return None, s
            else:
                raise KeySpecError(
                          "unknown backslash escape %s at char %d of %s"%(
                    repr(c), s + 2, repr(key)))
        else:
            if ctrl:
                ret = chr(ord(key[s]) & 0x1f)   # curses.ascii.ctrl()
                ret = unicode(ret)
            else:
                ret = unicode(key[s])
            s += 1
    return (ret, meta, ctrl), s

def parse_keys(key):
    s = 0
    r = []
    while s < len(key):
        k, s = _parse_key1(key, s)
        if k is None:
            return None
        r.append(k)
    return tuple(r)

def _compile_keymap(keymap):
    r = {}
    for key, value in keymap.items():
        r.setdefault(key[0], {})[key[1:]] = value
    for key, value in r.items():
        if value.has_key(()):
            if len(value) != 1:
                raise KeySpecError(
                          "key definitions for %s clash"%(value.values(),))
            else:
                r[key] = value[()]
        else:
            r[key] = _compile_keymap(value)
    return r

def compile_keymap(keymap):
    r = {}
    for key, value in keymap:
        k = parse_keys(key)
        if value is None and r.has_key(k):
            del r[k]
        if k is not None:
            r[k] = value
    return _compile_keymap(r)

def keyname(key):
    longest_match = ''
    longest_match_name = ''
    for name, keyseq in keyset.items():
        if keyseq and key.startswith(keyseq) and \
               len(keyseq) > len(longest_match):
            longest_match = keyseq
            longest_match_name = name
    if len(longest_match) > 0:
        return longest_match_name, len(longest_match)
    else:
        return None, 0

_unescapes = {'\r':'\\r', '\n':'\\n', '\177':'^?'}

#for k,v in _escapes.items():
#    _unescapes[v] = k

def unparse_key(keyseq):
    if not keyseq:
        return ''
    name, s = keyname(keyseq)
    if name:
        if name != 'escape' or s == len(keyseq):
            return '\\<' + name + '>' + unparse_key(keyseq[s:])
        else:
            return '\\M-' + unparse_key(keyseq[1:])
    else:
        c = keyseq[0]
        r = keyseq[1:]
        if c == '\\':
            p = '\\\\'
        elif _unescapes.has_key(c):
            p = _unescapes[c]
        elif ord(c) < ord(' '):
            p = '\\C-%s'%(chr(ord(c)+96),)
        elif ord(' ') <= ord(c) <= ord('~'):
            p = c
        else:
            p = '\\%03o'%(ord(c),)
        return p + unparse_key(r)

def _unparse_keyf(keyseq):
    if not keyseq:
        return []
    name, s = keyname(keyseq)
    if name:
        if name != 'escape' or s == len(keyseq):
            return [name] + _unparse_keyf(keyseq[s:])
        else:
            rest = _unparse_keyf(keyseq[1:])
            return ['M-'+rest[0]] + rest[1:]
    else:
        c = keyseq[0]
        r = keyseq[1:]
        if c == '\\':
            p = '\\'
        elif _unescapes.has_key(c):
            p = _unescapes[c]
        elif ord(c) < ord(' '):
            p = 'C-%s'%(chr(ord(c)+96),)
        elif ord(' ') <= ord(c) <= ord('~'):
            p = c
        else:
            p = '\\%03o'%(ord(c),)
        return [p] + _unparse_keyf(r)

def unparse_keyf(keyseq):
    return " ".join(_unparse_keyf(keyseq))
