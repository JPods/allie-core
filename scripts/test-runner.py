#!/usr/bin/env python3
"""
Test Runner — run test sequences and report results to the agent data stores.

Each agent contributes observations from their perspective:
  - Claude: "I wrote this code and these tests passed/failed"
  - Alice: "This test exposed a pattern I should watch for"
  - Allie: "This test result connects to a lesson from a prior session"

Results go to:
  1. Console output (immediate feedback)
  2. allie.observations table (persistent team knowledge)
  3. Agent message bus (notify relevant agents)
  4. Claude's vector store (searchable in future sessions)

Usage:
    python3 test-runner.py                    # run all tests
    python3 test-runner.py test_pending_path  # run specific test
    python3 test-runner.py --list             # list available tests
    python3 test-runner.py --report           # show recent results
"""
import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# Paths
WC3_DIR = Path('/Users/williamjames/Documents/CommerceExpert/webClerk3')
TESTS_DIR = WC3_DIR / 'tests'
VENV_PYTHON = str(WC3_DIR / 'venv' / 'bin' / 'python')
ALLIE_PYTHON = str(Path.home() / 'Allie' / 'source' / 'bin' / 'python')

# Database connections
DB_COMMERCE = {'dbname': 'commerce_expert', 'user': os.getlogin(), 'host': 'localhost'}
DB_ALLIE = {'dbname': 'allie', 'user': os.getlogin(), 'host': 'localhost'}

try:
    import psycopg2
    import psycopg2.extras
    HAS_DB = True
except ImportError:
    HAS_DB = False


def _now_ms():
    return int(time.time() * 1000)


def _connect_allie():
    if not HAS_DB:
        return None
    try:
        return psycopg2.connect(**DB_ALLIE)
    except Exception:
        return None


def discover_tests():
    """Find all test files in the tests directory."""
    tests = []
    if TESTS_DIR.exists():
        for f in sorted(TESTS_DIR.glob('test_*.py')):
            tests.append({
                'name': f.stem,
                'path': str(f),
                'size': f.stat().st_size,
            })
    # Also check for manage.py test targets
    return tests


def run_test(test_name: str, verbose: bool = False) -> dict:
    """Run a single test file and capture results.

    Returns: {
        test_name, passed, failed, errors, duration_seconds,
        output, error_output, summary
    }
    """
    # Find the test file
    test_file = TESTS_DIR / f'{test_name}.py'
    if not test_file.exists():
        # Try without test_ prefix
        test_file = TESTS_DIR / f'test_{test_name}.py'
    if not test_file.exists():
        return {'test_name': test_name, 'error': f'Test file not found: {test_name}'}

    print(f'\n{"="*60}')
    print(f'Running: {test_name}')
    print(f'{"="*60}')

    start = time.time()

    env = os.environ.copy()
    env['DJANGO_SETTINGS_MODULE'] = 'webclerk3_api.settings'
    env['PYTEST_FORCE_DB'] = '1'

    try:
        result = subprocess.run(
            [VENV_PYTHON, '-m', 'pytest', str(test_file), '-v', '--tb=short', '--no-header'],
            capture_output=True,
            text=True,
            cwd=str(WC3_DIR),
            env=env,
            timeout=120,
        )

        duration = time.time() - start
        output = result.stdout
        error_output = result.stderr

        # Parse pytest output
        passed = 0
        failed = 0
        errors = 0

        for line in output.split('\n'):
            if 'passed' in line.lower():
                import re
                m = re.search(r'(\d+) passed', line)
                if m:
                    passed = int(m.group(1))
            if 'failed' in line.lower():
                import re
                m = re.search(r'(\d+) failed', line)
                if m:
                    failed = int(m.group(1))
            if 'error' in line.lower():
                import re
                m = re.search(r'(\d+) error', line)
                if m:
                    errors = int(m.group(1))

        success = result.returncode == 0
        summary = f'{passed} passed, {failed} failed, {errors} errors in {duration:.1f}s'

        if verbose or not success:
            print(output)
            if error_output:
                print(error_output)

        status = 'PASS' if success else 'FAIL'
        color = '\033[92m' if success else '\033[91m'
        print(f'\n{color}{status}: {summary}\033[0m')

        return {
            'test_name': test_name,
            'passed': passed,
            'failed': failed,
            'errors': errors,
            'success': success,
            'duration_seconds': round(duration, 2),
            'output': output[-2000:],  # last 2000 chars
            'error_output': error_output[-1000:] if error_output else '',
            'summary': summary,
            'dt': _now_ms(),
        }

    except subprocess.TimeoutExpired:
        duration = time.time() - start
        return {
            'test_name': test_name,
            'passed': 0, 'failed': 0, 'errors': 1,
            'success': False,
            'duration_seconds': round(duration, 2),
            'output': '', 'error_output': 'TIMEOUT after 120 seconds',
            'summary': f'TIMEOUT after {duration:.0f}s',
            'dt': _now_ms(),
        }
    except Exception as e:
        return {
            'test_name': test_name,
            'passed': 0, 'failed': 0, 'errors': 1,
            'success': False,
            'duration_seconds': 0,
            'output': '', 'error_output': str(e),
            'summary': f'ERROR: {e}',
            'dt': _now_ms(),
        }


def run_all_tests(verbose: bool = False) -> list[dict]:
    """Run all discovered tests."""
    tests = discover_tests()
    if not tests:
        print('No tests found in', TESTS_DIR)
        return []

    results = []
    for test in tests:
        result = run_test(test['name'], verbose=verbose)
        results.append(result)

    return results


def report_results(results: list[dict]):
    """Report results to console, database, and agent bus."""
    total_passed = sum(r.get('passed', 0) for r in results)
    total_failed = sum(r.get('failed', 0) for r in results)
    total_errors = sum(r.get('errors', 0) for r in results)
    all_success = all(r.get('success', False) for r in results)

    print(f'\n{"="*60}')
    print(f'TEST SUMMARY')
    print(f'{"="*60}')
    for r in results:
        status = '✓' if r.get('success') else '✗'
        print(f'  {status} {r["test_name"]}: {r.get("summary", "?")}')
    print(f'\nTotal: {total_passed} passed, {total_failed} failed, {total_errors} errors')
    print(f'Overall: {"ALL PASS" if all_success else "FAILURES DETECTED"}')

    # Save to allie database
    conn = _connect_allie()
    if conn:
        try:
            with conn.cursor() as cur:
                # Log as observation
                summary_text = f'Test run: {total_passed} passed, {total_failed} failed, {total_errors} errors. ' + \
                    '; '.join(f'{r["test_name"]}={r.get("summary", "?")}' for r in results)

                cur.execute("""
                    INSERT INTO observations (dt_created, observer, domain, category, content, resolved, metadata)
                    VALUES (%s, 'claude', 'WC3', 'test_result', %s, %s, %s)
                """, (
                    _now_ms(), summary_text, all_success,
                    json.dumps({'results': [{k: v for k, v in r.items() if k != 'output'} for r in results]}),
                ))

                # Send agent message if failures
                if not all_success:
                    cur.execute("""
                        INSERT INTO agent_messages (dt_created, from_agent, to_agent, subject, body, priority, category, context)
                        VALUES (%s, 'test_runner', 'all', %s, %s, %s, 'alert', %s)
                    """, (
                        _now_ms(),
                        f'Test failures: {total_failed} failed, {total_errors} errors',
                        summary_text,
                        2 if total_failed > 0 else 1,
                        json.dumps({'test_names': [r['test_name'] for r in results if not r.get('success')]}),
                    ))

                # Also notify Alice specifically about patterns
                if total_failed > 0:
                    cur.execute("""
                        INSERT INTO agent_messages (dt_created, from_agent, to_agent, subject, body, priority, category)
                        VALUES (%s, 'test_runner', 'alice', 'Test failures for pattern review', %s, 1, 'observation')
                    """, (_now_ms(), summary_text))

                conn.commit()
                print('\nResults saved to allie database + agent bus')

        except Exception as e:
            print(f'\nWarning: could not save to database: {e}')
        finally:
            conn.close()

    return all_success


def show_recent_results(limit: int = 10):
    """Show recent test results from the database."""
    conn = _connect_allie()
    if not conn:
        print('Cannot connect to allie database')
        return

    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT dt_created, content, resolved as all_passed, metadata
                FROM observations
                WHERE observer = 'claude' AND category = 'test_result'
                ORDER BY dt_created DESC LIMIT %s
            """, (limit,))
            rows = cur.fetchall()

            if not rows:
                print('No test results in database')
                return

            print(f'\nRecent test results ({len(rows)}):')
            print(f'{"="*60}')
            for row in rows:
                dt = datetime.fromtimestamp(row['dt_created'] / 1000, tz=timezone.utc)
                status = '✓ PASS' if row['all_passed'] else '✗ FAIL'
                print(f'\n{dt.strftime("%Y-%m-%d %H:%M")} — {status}')
                print(f'  {row["content"][:200]}')
    except Exception as e:
        print(f'Error: {e}')
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description='Test Runner — run tests and report to agent data stores')
    parser.add_argument('tests', nargs='*', help='Test names to run (default: all)')
    parser.add_argument('--list', action='store_true', help='List available tests')
    parser.add_argument('--report', action='store_true', help='Show recent results')
    parser.add_argument('--verbose', '-v', action='store_true', help='Show full test output')
    args = parser.parse_args()

    if args.list:
        tests = discover_tests()
        print(f'Available tests ({len(tests)}):')
        for t in tests:
            print(f'  {t["name"]} ({t["size"]} bytes)')
        return

    if args.report:
        show_recent_results()
        return

    if args.tests:
        results = [run_test(t, verbose=args.verbose) for t in args.tests]
    else:
        results = run_all_tests(verbose=args.verbose)

    if results:
        success = report_results(results)
        sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
