#! /usr/bin/env python
"""
Command-line interface for a dot file viewer.
Run with no arguments for help.
"""

import os
import sys
sys.path.insert(0, os.path.realpath(os.path.join(os.path.dirname(__file__), '..', '..')))
from dotviewer.dotviewer import main

if __name__ == '__main__':
    main()
