#! /usr/bin/env python
"""
Command-line interface for a dot file viewer.

    dotviewer.py filename.dot
    dotviewer.py filename.plain

In the first form, show the graph contained in a .dot file.
In the second form, the graph was already compiled to a .plain file.
"""

from __future__ import print_function
import os

PARENTDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

import sys
import getopt

def main(args = sys.argv[1:]):
     # make the dotviewer *package* importable
    sys.path.insert(0, PARENTDIR)

    options, args = getopt.getopt(args, 's:h', ['server=', 'help'])
    server_addr = None
    for option, value in options:
        if option in ('-h', '--help'):
            print(__doc__, file=sys.stderr)
            sys.exit(2)
        if option in ('-s', '--server'):      # deprecated
            server_addr = value
    if not args and server_addr is None:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    for filename in args:
        from dotviewer import graphclient
        graphclient.display_dot_file(filename)
    if server_addr is not None:
        from dotviewer import graphserver
        graphserver.listen_server(server_addr)

if __name__ == '__main__':
    main()
