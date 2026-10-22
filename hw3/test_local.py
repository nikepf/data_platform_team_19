#!/usr/bin/env python3
import pathlib
import re
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parent
for script in root.glob('*.sh'):
    subprocess.run(['bash', '-n', str(script)], check=True)
blocks = re.findall(r"<<'PY'\n(.*?)\nPY", (root / 'load.sh').read_text(), re.S)
assert len(blocks) == 2
with tempfile.TemporaryDirectory() as directory:
    source = pathlib.Path(directory) / 'input.csv'
    target = pathlib.Path(directory) / 'output.csv'
    for content, day, valid in [
        ('1,book,120.00\n2,pen,30.00\n', '2026-10-21', True),
        ('"1","book","120.00"\r\n', '2026-10-21', True),
        ('', '2026-10-21', False),
        ('1,book,120\n', '2026-02-30', False),
        ('1,book,120\n', "2026-10-21');DROP TABLE sales;--", False),
        ('1,book,NaN\n', '2026-10-21', False),
        ('1,book,1.234\n', '2026-10-21', False),
        ('1,"a,b",10\n', '2026-10-21', False),
        ('2147483648,book,10\n', '2026-10-21', False),
    ]:
        source.write_bytes(content.encode())
        result = subprocess.run([sys.executable, '-c', blocks[0], str(source), day], capture_output=True)
        assert (result.returncode == 0) == valid, (content, day, result.stderr)
    source.write_bytes(b'"1","book","120.00"\r\n')
    subprocess.run([sys.executable, '-c', blocks[1], str(source), str(target)], check=True)
    assert target.read_bytes() == b'1,book,120.00\n'
