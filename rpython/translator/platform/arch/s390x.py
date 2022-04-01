import re
import os

def extract_s390x_cpu_ids(lines):
    ids = []

    re_number = re.compile("processor (\d+):")
    re_version = re.compile("version = ([0-9A-Fa-f]+)")
    re_id = re.compile("identification = ([0-9A-Fa-f]+)")
    re_machine = re.compile("machine = ([0-9A-Fa-f]+)")
    for line in lines:
        number = -1
        version = None
        ident = None
        machine = 0

        match = re_number.match(line)
        if not match:
            continue
        number = int(match.group(1))

        match = re_version.search(line)
        if match:
            version = match.group(1)

        match = re_version.search(line)
        if match:
            version = match.group(1)

        match = re_id.search(line)
        if match:
            ident = match.group(1)

        match = re_machine.search(line)
        if match:
            machine = int(match.group(1), 16)

        ids.append((number, version, ident, machine))

    return ids

def s390x_detect_vx():
    chunks = []
    try:
        fd = os.open("/proc/cpuinfo", os.O_RDONLY, 0644)
        try:
            while True:
                chunk = os.read(fd, 4096)
                if not chunk:
                    break
                chunks.append(chunk)
        finally:
            os.close(fd)
    except OSError:
        pass
    content = ''.join(chunks)
    start = content.find("features", 0)
    if start >= 0:
        after_colon = content.find(":", start)
        if after_colon < 0:
            return False
        newline = content.find("\n", after_colon)
        if newline < 0:
            return False
        split = content[after_colon+1:newline].strip().split(' ')
        if 'vx' in split:
            return True
    return False

def s390x_cpu_revision():
    # linux kernel does the same classification
    # http://lists.llvm.org/pipermail/llvm-commits/Week-of-Mon-20131028/193311.html

    with open("/proc/cpuinfo", "rb") as fd:
        lines = fd.read().splitlines()
        cpu_ids = extract_s390x_cpu_ids(lines)
    machine = -1
    for number, version, id, m in cpu_ids:
        if machine != -1:
            assert machine == m
        machine = m

    if machine == 0x2097 or machine == 0x2098:
        return "z10"
    if machine == 0x2817 or machine == 0x2818:
        return "z196"
    if machine == 0x2827 or machine == 0x2828:
        return "zEC12"
    if machine == 0x2964:
        return "z13"
    if machine == 0x3907:  # gcc supports z14 as of 2019/05/08
        return "z14"
    if machine == 0x8561:
        return "z15"

    # well all others are unsupported!
    return "unknown"

def update_cflags(cflags):
    """ NOT_RPYTHON """
    # force the right target arch for s390x
    for cflag in cflags:
        if cflag.startswith('-march='):
            break
    else:
        # the default cpu architecture is zEC12
        # one can directly specifying -march=... if needed
        revision = 'zEC12'
        cflags += ('-march='+revision,)
    cflags += ('-m64','-mzarch')
    return cflags
