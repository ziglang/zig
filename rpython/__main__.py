"""RPython translation usage:

rpython <translation options> target <targetoptions>

run with --help for more information
"""

import sys

# no implicit targets
if len(sys.argv) == 1:
    print __doc__
    sys.exit(1)

from rpython.translator.goal.translate import main
main()
