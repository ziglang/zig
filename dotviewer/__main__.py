# alternative entry point when packaged
from __future__ import absolute_import

import argparse

from dotviewer import graphclient

parser = argparse.ArgumentParser(description='Show a graphviz file')
parser.add_argument('filename', metavar='FILE',
                    help='a .dot file or a .plain file to show')

if __name__ == '__main__':
    args = parser.parse_args()
    graphclient.display_dot_file(args.filename)


