
""" Some support code
"""

import re, sys, os, subprocess

def detect_number_of_processors(filename_or_file='/proc/cpuinfo'):
    if os.environ.get('MAKEFLAGS'):
        return 1    # don't override MAKEFLAGS.  This will call 'make' without any '-j' option
    if sys.platform == 'darwin':
        return sysctl_get_cpu_count('/usr/sbin/sysctl')
    elif sys.platform.startswith('freebsd'):
        return sysctl_get_cpu_count('/sbin/sysctl')
    elif not sys.platform.startswith('linux'):
        return 1    # implement me
    try:
        if isinstance(filename_or_file, str):
            f = open(filename_or_file, "r")
        else:
            f = filename_or_file
        count = max([int(re.split('processor.*(\d+)', line)[1])
                    for line in f.readlines()
                    if line.startswith('processor')]) + 1
        if count >= 4:
            return max(count // 2, 3)
        else:
            return count
    except:
        return 1 # we really don't want to explode here, at worst we have 1

def sysctl_get_cpu_count(cmd, name='hw.ncpu'):
    try:
        proc = subprocess.Popen([cmd, '-n', name], stdout=subprocess.PIPE)
        count = proc.communicate()[0]
        return int(count)
    except (OSError, ValueError):
        return 1

def detect_pax():
    """
    Function to determine if your system comes with PAX protection.
    """
    if sys.platform.startswith('linux'):
        # use PID of current process for the check
        with open("/proc/self/status") as fd:
            data = fd.read()
        if 'PaX' in data:
            return True
    return False
