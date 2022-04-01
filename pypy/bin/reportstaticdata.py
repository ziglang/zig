#!/usr/bin/env python

"""
Usage: reportstaticdata.py [-m1|-m2|-t] [OPTION]... FILENAME
Print a report for the static data information contained in FILENAME

The static data information is saved in the file staticdata.info when
passing --dump_static_data_info to translate.py.

Options:

  -m1      Print a report for each module, counting constants that are
           reacheable from more than one module multiple times (default)

  -m2      Print a report for each module, counting constants that are
           reacheable from more than one module only in the first module
           seen

  -t       Print a global report for all the constants

  -h       Print sizes in human readable formats (e.g., 1K 234M)

  -s       Print only the total size for each module

  -u       Print the list of graphs which belongs to unknown modules

  --help   Show this help message
"""

import sys

from rpython.translator.tool.staticsizereport import print_report

def parse_options(argv):
    kwds = {}
    for arg in argv:
        if arg.startswith('-'):
            if arg == '-m1':
                assert 'kind' not in kwds
                kwds['kind'] = 'by_module_with_duplicates'
            elif arg == '-m2':
                assert 'kind' not in kwds
                kwds['kind'] = 'by_module_without_duplicates'
            elif arg == '-t':
                assert 'kind' not in kwds
                kwds['kind'] = 'by_type'
            elif arg == '-h':
                kwds['human_readable'] = True
            elif arg == '-s':
                kwds['summary'] = True
            elif arg == '-u':
                kwds['show_unknown_graphs'] = True
            elif arg == '--help':
                raise AssertionError
        else:
            assert 'filename' not in kwds
            kwds['filename'] = arg

    assert 'filename' in kwds
    return kwds


def main():
    try:
        kwds = parse_options(sys.argv[1:])
    except AssertionError:
        print >> sys.stderr, __doc__
        sys.exit(1)
    print_report(**kwds)

if __name__ == '__main__':
    main()
