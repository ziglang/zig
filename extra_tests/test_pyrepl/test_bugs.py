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

from pyrepl.historical_reader import HistoricalReader
from .infrastructure import EA, BaseTestReader, sane_term, read_spec

# this test case should contain as-verbatim-as-possible versions of
# (applicable) bug reports

import pytest


class HistoricalTestReader(HistoricalReader, BaseTestReader):
    pass


@pytest.mark.xfail(reason='event missing', run=False)
def test_transpose_at_start():
    read_spec([
        ('transpose', [EA, '']),
        ('accept',    [''])])


def test_cmd_instantiation_crash():
    spec = [
        ('reverse-history-isearch', ["(r-search `') "]),
        (('key', 'left'), ['']),
        ('accept', [''])
    ]
    read_spec(spec, HistoricalTestReader)


@pytest.mark.skipif("os.name != 'posix' or 'darwin' in sys.platform or "
                    "'kfreebsd' in sys.platform")
def test_signal_failure(monkeypatch):
    import os
    import pty
    import signal
    from pyrepl.unix_console import UnixConsole

    def failing_signal(a, b):
        raise ValueError

    def really_failing_signal(a, b):
        raise AssertionError

    mfd, sfd = pty.openpty()
    try:
        with sane_term():
            c = UnixConsole(sfd, sfd)
            c.prepare()
            c.restore()
            monkeypatch.setattr(signal, 'signal', failing_signal)
            c.prepare()
            monkeypatch.setattr(signal, 'signal', really_failing_signal)
            c.restore()
    finally:
        os.close(mfd)
        os.close(sfd)
