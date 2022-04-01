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

reader_emacs_keymap = tuple(
    [(r'\C-a', 'beginning-of-line'),
     (r'\C-b', 'left'),
     (r'\C-c', 'interrupt'),
     (r'\C-d', 'delete'),
     (r'\C-e', 'end-of-line'),
     (r'\C-f', 'right'),
     (r'\C-g', 'cancel'),
     (r'\C-h', 'backspace'),
     (r'\C-j', 'self-insert'),
     (r'\<return>', 'accept'),
     (r'\C-k', 'kill-line'),
     (r'\C-l', 'clear-screen'),
#     (r'\C-m', 'accept'),
     (r'\C-q', 'quoted-insert'),
     (r'\C-t', 'transpose-characters'),
     (r'\C-u', 'unix-line-discard'),
     (r'\C-v', 'quoted-insert'),
     (r'\C-w', 'unix-word-rubout'),
     (r'\C-x\C-u', 'upcase-region'),
     (r'\C-y', 'yank'),
     (r'\C-z', 'suspend'),
     
     (r'\M-b', 'backward-word'),
     (r'\M-c', 'capitalize-word'),
     (r'\M-d', 'kill-word'),
     (r'\M-f', 'forward-word'),
     (r'\M-l', 'downcase-word'),
     (r'\M-t', 'transpose-words'),
     (r'\M-u', 'upcase-word'),
     (r'\M-y', 'yank-pop'),
     (r'\M--', 'digit-arg'),
     (r'\M-0', 'digit-arg'),
     (r'\M-1', 'digit-arg'),
     (r'\M-2', 'digit-arg'),
     (r'\M-3', 'digit-arg'),
     (r'\M-4', 'digit-arg'),
     (r'\M-5', 'digit-arg'),
     (r'\M-6', 'digit-arg'),
     (r'\M-7', 'digit-arg'),
     (r'\M-8', 'digit-arg'),
     (r'\M-9', 'digit-arg'),
     (r'\M-\n', 'self-insert'),
     (r'\<backslash>', 'self-insert')] + \
    [(c, 'self-insert')
     for c in map(chr, range(32, 127)) if c != '\\'] + \
    [(c, 'self-insert')
     for c in map(chr, range(128, 256)) if c.isalpha()] + \
    [(r'\<up>', 'up'),
     (r'\<down>', 'down'),
     (r'\<left>', 'left'),
     (r'\<right>', 'right'),
     (r'\<insert>', 'quoted-insert'),
     (r'\<delete>', 'delete'),
     (r'\<backspace>', 'backspace'),
     (r'\M-\<backspace>', 'backward-kill-word'),
     (r'\<end>', 'end'),
     (r'\<home>', 'home'),
     (r'\<f1>', 'help'),
     (r'\EOF', 'end'),  # the entries in the terminfo database for xterms
     (r'\EOH', 'home'), # seem to be wrong.  this is a less than ideal
                        # workaround
     ])

hist_emacs_keymap = reader_emacs_keymap + (
    (r'\C-n', 'next-history'),
    (r'\C-p', 'previous-history'),
    (r'\C-o', 'operate-and-get-next'),
    (r'\C-r', 'reverse-history-isearch'),
    (r'\C-s', 'forward-history-isearch'),
    (r'\M-r', 'restore-history'),
    (r'\M-.', 'yank-arg'),
    (r'\<page down>', 'last-history'),
    (r'\<page up>', 'first-history'))

comp_emacs_keymap = hist_emacs_keymap + (
    (r'\t', 'complete'),)

python_emacs_keymap = comp_emacs_keymap + (
    (r'\n', 'maybe-accept'),
    (r'\M-\n', 'self-insert'))
    
reader_vi_insert_keymap = tuple(
    [(c, 'self-insert')
     for c in map(chr, range(32, 127)) if c != '\\'] + \
    [(c, 'self-insert')
     for c in map(chr, range(128, 256)) if c.isalpha()] + \
    [(r'\C-d', 'delete'),
     (r'\<backspace>', 'backspace'),
     ('')])

reader_vi_command_keymap = tuple(
    [
    ('E', 'enter-emacs-mode'),
    ('R', 'enter-replace-mode'),
    ('dw', 'delete-word'),
    ('dd', 'delete-line'),
    
    ('h', 'left'),
    ('i', 'enter-insert-mode'),
    ('j', 'down'),
    ('k', 'up'),
    ('l', 'right'),
    ('r', 'replace-char'),
    ('w', 'forward-word'),
    ('x', 'delete'),
    ('.', 'repeat-edit'), # argh!
    (r'\<insert>', 'enter-insert-mode'),
     ] + 
    [(c, 'digit-arg') for c in '01234567689'] +
    [])
   

reader_keymaps = {
    'emacs' : reader_emacs_keymap,
    'vi-insert' : reader_vi_insert_keymap,
    'vi-command' : reader_vi_command_keymap
    }

del c # from the listcomps

