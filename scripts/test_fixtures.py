"""Black-box Conftest regression tests; compilation/tool errors never count as detection."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
cases = json.loads((root / "tests/fixtures/cases.json").read_text())
failed = 0
for case in cases:
    result = subprocess.run(
        ["bash", "-c", 'source scripts/tools.sh; conftest test --policy policies --output json "$1"',
         "fixtures", case["file"]], cwd=root, capture_output=True, text=True, check=False,
    )
    try:
        reports = json.loads(result.stdout)
        messages = [entry["msg"] for report in reports for entry in report.get("failures", [])]
        expected = case["expected"]
        if expected:
            ok = result.returncode == 1 and any(expected in msg for msg in messages)
        else:
            ok = result.returncode == 0 and not messages
    except (ValueError, TypeError, KeyError):
        ok = False
    print(f'{"PASS" if ok else "FAIL"}: {case["file"]}')
    if not ok:
        failed += 1
        print(result.stdout, result.stderr, file=sys.stderr)
sys.exit(1 if failed else 0)
