import pytest

@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item):
    report = (yield).result
    if 'out' in item.funcargs:
        report.sections.append(('out', item.funcargs['out'].read()))
