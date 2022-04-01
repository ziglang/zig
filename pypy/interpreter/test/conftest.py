from pypy.conftest import PYTHON3

def get_banner():
    import subprocess
    p = subprocess.Popen([PYTHON3, "-c",
                          "import sys; print(sys.version.splitlines()[0])"],
                         stdout=subprocess.PIPE)
    return p.stdout.read().rstrip()
banner = get_banner() if PYTHON3 else "PYTHON3 not found"

def pytest_report_header(config):
    if PYTHON3:
        return "PYTHON3: %s\n(Version %s)" % (PYTHON3, banner)
