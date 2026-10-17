"""Exact-text edits that keep each file's line endings (used by the agent)."""
import sys

def edit(path, old, new, count=1):
    s = open(path, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in s else '\n'
    o = old.replace('\r\n', '\n').replace('\n', nl)
    n = new.replace('\r\n', '\n').replace('\n', nl)
    if o not in s:
        raise SystemExit('NOT FOUND in %s:\n%s' % (path, old[:200]))
    s = s.replace(o, n, count)
    open(path, 'w', encoding='utf-8', newline='').write(s)
