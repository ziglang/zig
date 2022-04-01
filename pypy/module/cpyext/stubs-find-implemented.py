import re
import os


for line in open('stubs.py'):
    if not line.strip():
        continue
    if line.startswith('    '):
        continue
    if line.startswith('#'):
        continue
    if line.startswith('@cpython_api'):
        continue
    if line.endswith(' = rffi.VOIDP\n'):
        continue

    #print line.rstrip()
    m = re.match(r"def ([\w\d_]+)[(]", line)
    assert m, line
    funcname = m.group(1)
    os.system('grep -w %s [a-r]*.py s[a-s]*.py str*.py stubsa*.py sy*.py [t-z]*.py' % funcname)
