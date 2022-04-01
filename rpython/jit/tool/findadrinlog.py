import sys, re
from rpython.tool import logparser

# fflush(pypy_debug_file)

if len(sys.argv) != 3:
    print "Usage: %s <log file> <address>" % sys.argv[0]

log = logparser.parse_log_file(sys.argv[1])
text = logparser.extract_category(log, catprefix='jit-backend')
address = int(sys.argv[2], 16)

for l in text:
    m = re.match('(Loop|Bridge)(.*?) \(.*has address (\w+) to (\w+)', l)
    if m is not None:
        trace = m.group(1) + m.group(2)
        start = int(m.group(3), 16)
        stop = int(m.group(4), 16)
        if start <= address <= stop:
            offset = address - start
            print trace
            print 'at offset ', offset
            break
else:
    print "Not found"
    exit(0)
                                         
if trace.startswith('Bridge'):
    cat = 'jit-log-opt-bridge'
else:
    cat = 'jit-log-opt-loop'
text = logparser.extract_category(log, catprefix=cat)

print "..."
s = trace.lower()
s = re.subn('#', '', s)[0]
s = '# ' + s + ' '
for ll in text:
    if ll.lower().startswith(s):
        for l in ll.split('\n'):
            m = re.match('\+(\d+):', l)
            if m is not None:
                if abs(int(m.group(1)) - offset) < 50:
                    print l
print "..."

        
