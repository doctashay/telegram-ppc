#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys


nm, sdk, arch, binary = sys.argv[1:]
system_library = Path(sdk) / "usr/lib/libSystem.B.dylib"
exports = set(subprocess.check_output(
    [nm, "-arch", arch, "-gjU", str(system_library)], text=True).splitlines())
listing = subprocess.check_output([nm, "-arch", arch, "-m", binary], text=True)
imports = set()
for line in listing.splitlines():
    if "(undefined)" in line and "weak" not in line:
        match = re.search(r"external (\S+) \(from libSystem\)", line)
        if match:
            imports.add(match[1])
missing = sorted(imports - exports)
if missing:
    print(f"Imports unavailable in Tiger libSystem: {binary} ({arch})", file=sys.stderr)
    print("\n".join(missing), file=sys.stderr)
    sys.exit(1)
