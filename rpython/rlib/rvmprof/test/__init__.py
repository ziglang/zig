import pytest
import platform

if not (platform.machine().startswith('x86') or platform.machine() == 'aarch64'):
    pytest.skip()
