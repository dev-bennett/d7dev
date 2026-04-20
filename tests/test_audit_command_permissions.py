"""Tests for scripts/audit_command_permissions.py."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from audit_command_permissions import (
    ToolCall,
    audit,
    extract_tool_calls,
    is_covered,
    load_allowlist,
    main,
)


@pytest.fixture
def tmp_commands(tmp_path: Path) -> Path:
    d = tmp_path / "commands"
    d.mkdir()
    return d


@pytest.fixture
def tmp_settings(tmp_path: Path) -> Path:
    return tmp_path / "settings.json"


def _write_settings(path: Path, allow: list[str]) -> None:
    path.write_text(json.dumps({"permissions": {"allow": allow}}))


def test_extract_from_run_prefix(tmp_commands: Path) -> None:
    (tmp_commands / "cmd.md").write_text("Run: `git status`")
    calls = extract_tool_calls(tmp_commands / "cmd.md")
    assert len(calls) == 1
    assert calls[0].first_token == "git"
    assert calls[0].pattern == "git status"


def test_extract_from_fenced_bash_block(tmp_commands: Path) -> None:
    content = "Some text.\n\n```bash\npytest -v\nruff check scripts/\n```\n"
    (tmp_commands / "cmd.md").write_text(content)
    calls = extract_tool_calls(tmp_commands / "cmd.md")
    tokens = sorted(c.first_token for c in calls)
    assert tokens == ["pytest", "ruff"]


def test_extract_from_inline_backticks_with_args(tmp_commands: Path) -> None:
    (tmp_commands / "cmd.md").write_text("See `ls -la /tmp` for details.")
    calls = extract_tool_calls(tmp_commands / "cmd.md")
    assert len(calls) == 1
    assert calls[0].first_token == "ls"


def test_inline_backtick_without_args_not_extracted(tmp_commands: Path) -> None:
    # Bare identifiers like `checkpoint.md` or `pytest` without args are filtered
    # because they're usually file references or tool mentions in prose.
    (tmp_commands / "cmd.md").write_text("The `checkpoint.md` file holds state.")
    calls = extract_tool_calls(tmp_commands / "cmd.md")
    assert calls == []


def test_extract_tool_class_explicit(tmp_commands: Path) -> None:
    (tmp_commands / "cmd.md").write_text(
        "Pre-allowed: Write(.claude/hooks/session-briefing.md)."
    )
    calls = extract_tool_calls(tmp_commands / "cmd.md")
    assert len(calls) == 1
    assert calls[0].kind == "tool"
    assert calls[0].first_token == "Write"


def test_shell_keywords_not_extracted(tmp_commands: Path) -> None:
    (tmp_commands / "cmd.md").write_text("```bash\nfor f in *.py; do echo $f; done\n```")
    calls = extract_tool_calls(tmp_commands / "cmd.md")
    tokens = [c.first_token for c in calls]
    # `for` should be extracted (it's a loop starter); `do`, `done` should not.
    assert "for" in tokens
    assert "do" not in tokens
    assert "done" not in tokens


def test_load_allowlist_union(tmp_path: Path) -> None:
    a = tmp_path / "a.json"
    b = tmp_path / "b.json"
    _write_settings(a, ["Read", "Bash(git:*)"])
    _write_settings(b, ["Write", "Bash(ls:*)"])
    allow = load_allowlist([a, b])
    assert allow == {"Read", "Bash(git:*)", "Write", "Bash(ls:*)"}


def test_load_allowlist_missing_file_ignored(tmp_path: Path) -> None:
    missing = tmp_path / "missing.json"
    assert load_allowlist([missing]) == set()


def test_load_allowlist_invalid_json_ignored(tmp_path: Path) -> None:
    bad = tmp_path / "bad.json"
    bad.write_text("{ not json")
    assert load_allowlist([bad]) == set()


def test_bare_tool_entry_covers_any_invocation() -> None:
    call = ToolCall("x.md", "tool", "Write(path/file.md)", "Write")
    assert is_covered(call, {"Write"})


def test_bare_bash_entry_covers_any_bash() -> None:
    call = ToolCall("x.md", "bash", "anything", "anything")
    assert is_covered(call, {"Bash"})


def test_bash_prefix_wildcard_matches_subcommand() -> None:
    call = ToolCall("x.md", "bash", "git log --oneline", "git")
    assert is_covered(call, {"Bash(git:*)"})


def test_bash_prefix_wildcard_matches_piped_command() -> None:
    call = ToolCall("x.md", "bash", "ls -t path/ | head -1", "ls")
    assert is_covered(call, {"Bash(ls:*)"})


def test_bash_multi_word_prefix_wildcard() -> None:
    call = ToolCall("x.md", "bash", "git add foo.py", "git")
    assert is_covered(call, {"Bash(git add:*)"})


def test_bash_exact_literal_match() -> None:
    call = ToolCall("x.md", "bash", "done", "done")
    assert is_covered(call, {"Bash(done)"})


def test_uncovered_bash_command_flagged() -> None:
    call = ToolCall("x.md", "bash", "rsync -av /tmp /backup", "rsync")
    assert not is_covered(call, {"Bash(git:*)", "Bash(ls:*)"})


def test_uncovered_tool_class_flagged() -> None:
    call = ToolCall("x.md", "tool", "Edit(path)", "Edit")
    assert not is_covered(call, {"Read", "Write"})


def test_audit_end_to_end_all_covered(tmp_commands: Path, tmp_settings: Path) -> None:
    (tmp_commands / "one.md").write_text("Run: `git status`")
    (tmp_commands / "two.md").write_text("```bash\nls -la\n```")
    _write_settings(tmp_settings, ["Bash(git:*)", "Bash(ls:*)"])
    rows = audit(tmp_commands, load_allowlist([tmp_settings]))
    assert len(rows) == 2
    assert all(ok for _, ok in rows)


def test_audit_end_to_end_flags_gap(tmp_commands: Path, tmp_settings: Path) -> None:
    (tmp_commands / "one.md").write_text("Run: `rsync -av /tmp /backup`")
    _write_settings(tmp_settings, ["Bash(git:*)"])
    rows = audit(tmp_commands, load_allowlist([tmp_settings]))
    assert len(rows) == 1
    assert not rows[0][1]
    assert rows[0][0].first_token == "rsync"


def test_main_check_mode_passes(tmp_commands: Path, tmp_settings: Path) -> None:
    (tmp_commands / "ok.md").write_text("Run: `git status`")
    _write_settings(tmp_settings, ["Bash(git:*)"])
    exit_code = main(
        [
            "--check",
            "--commands-dir",
            str(tmp_commands),
            "--settings",
            str(tmp_settings),
        ]
    )
    assert exit_code == 0


def test_main_check_mode_fails_on_gap(
    tmp_commands: Path, tmp_settings: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    (tmp_commands / "bad.md").write_text("Run: `rsync -av /tmp /backup`")
    _write_settings(tmp_settings, ["Bash(git:*)"])
    exit_code = main(
        [
            "--check",
            "--commands-dir",
            str(tmp_commands),
            "--settings",
            str(tmp_settings),
        ]
    )
    assert exit_code == 1
    captured = capsys.readouterr()
    assert "rsync" in captured.err
    assert "bad.md" in captured.err


def test_main_report_mode_prints_table(
    tmp_commands: Path, tmp_settings: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    (tmp_commands / "ok.md").write_text("Run: `git status`")
    _write_settings(tmp_settings, ["Bash(git:*)"])
    main(
        [
            "--report",
            "--commands-dir",
            str(tmp_commands),
            "--settings",
            str(tmp_settings),
        ]
    )
    captured = capsys.readouterr()
    assert "1/1" in captured.out
    assert "git status" in captured.out


def test_main_with_live_repo_matches_expected() -> None:
    # Smoke test against the real repo. All 16 canonical commands should pass
    # after Phase 1 + Phase 2 allowlist extensions.
    exit_code = main(["--check"])
    assert exit_code == 0
