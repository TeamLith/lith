#!/usr/bin/env python3

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional
from urllib import parse, request


TASK_HEADER_RE = re.compile(r"^## Task: (?P<title>.+)$")
FIELD_RE = re.compile(r"^- (?P<name>[^:]+):(?: (?P<value>.*))?$")


@dataclass
class Task:
    title: str
    input_specs: List[str] = field(default_factory=list)
    deliverables: List[str] = field(default_factory=list)
    steps: List[str] = field(default_factory=list)
    status: str = ""
    notes: List[str] = field(default_factory=list)


def parse_tasks(text: str) -> List[Task]:
    tasks: List[Task] = []
    current: Optional[Task] = None
    section: Optional[str] = None

    for raw_line in text.splitlines():
        line = raw_line.rstrip("\n")

        match = TASK_HEADER_RE.match(line)
        if match:
            if current is not None:
                tasks.append(current)
            current = Task(title=match.group("title"))
            section = None
            continue

        if current is None:
            continue

        if line.startswith("- Input specs:"):
            section = "input_specs"
            continue
        if line.startswith("- Deliverables:"):
            section = "deliverables"
            continue
        if line.startswith("- Steps:"):
            section = "steps"
            continue
        if line.startswith("- Notes/Blockers:"):
            section = "notes"
            continue

        field_match = FIELD_RE.match(line)
        if field_match:
            name = field_match.group("name")
            value = field_match.group("value") or ""
            if name == "Status":
                current.status = value
            section = None
            continue

        if line.startswith("  - ") and section:
            value = line[4:]
            getattr(current, section).append(value)

    if current is not None:
        tasks.append(current)

    return tasks


def resolve_source_mode(input_path: str, requested_mode: str) -> str:
    if requested_mode != "auto":
        return requested_mode
    if input_path != "-" and Path(input_path).name == "CONTRIBUTING_AGENTS.md":
        return "legacy-migration"
    return "task-intake"


def read_input_text(input_path: str) -> str:
    if input_path == "-":
        return sys.stdin.read()
    return Path(input_path).read_text()


def build_issue_body(task: Task, source_mode: str, source_path: str) -> str:
    body: List[str] = []
    if source_mode == "legacy-migration":
        body.append("Imported from the legacy `CONTRIBUTING_AGENTS.md` backlog during the GitHub Issues migration.")
    else:
        body.append("Created from the repo `## Task:` template during an explicit task-intake run.")
    body.append("")

    body.append("## Problem / Goal")
    body.append(f"- {task.title}")
    body.append("")

    if task.input_specs:
        body.append("## Input Specs")
        body.extend(f"- {item}" for item in task.input_specs)
        body.append("")

    if task.deliverables:
        body.append("## Deliverables")
        body.extend(f"- {item}" for item in task.deliverables)
        body.append("")

    if task.steps:
        body.append("## Steps")
        body.extend(f"- {item}" for item in task.steps)
        body.append("")

    if task.notes:
        body.append("## Notes / Blockers")
        body.extend(f"- {item}" for item in task.notes)
        body.append("")

    if source_mode == "legacy-migration":
        body.append("## Migration")
        body.append("- Source: `CONTRIBUTING_AGENTS.md`")
        body.append("- Legacy status at import time: `TODO`")
    else:
        body.append("## User-Facing Documentation Impact")
        body.append("- Update matching user-facing docs in the same issue if behavior changes; otherwise note that no user-facing docs update was needed.")
        body.append("")
        body.append("## Validation Expectations")
        body.append("- Run the relevant commands from `REPO_MAP.md` for the changed area.")
        body.append("- Use `scripts/validate.sh` when app wiring, project generation, CI/workflow files, or repo-process files change.")
        body.append("")
        body.append("## Task Intake")
        body.append("- Source template: repo `## Task:` markdown block")
        if source_path == "-":
            body.append("- Submitted from: stdin")
        else:
            body.append(f"- Submitted from: `{source_path}`")
    return "\n".join(body).rstrip() + "\n"


def github_request(url: str, token: str, method: str = "GET", data: Optional[dict] = None) -> dict:
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "lith-task-migrator",
    }
    payload = None
    if data is not None:
        payload = json.dumps(data).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = request.Request(url, headers=headers, method=method, data=payload)
    with request.urlopen(req) as response:
        raw = response.read()
    return json.loads(raw.decode("utf-8")) if raw else {}


def existing_issue_number(owner: str, repo: str, title: str, token: str) -> Optional[int]:
    q = f'repo:{owner}/{repo} is:issue in:title "{title}"'
    url = "https://api.github.com/search/issues?" + parse.urlencode({"q": q, "per_page": 10})
    result = github_request(url, token=token)
    for item in result.get("items", []):
        if item.get("title") == title:
            return item.get("number")
    return None


def create_issue(owner: str, repo: str, title: str, body: str, token: str) -> int:
    url = f"https://api.github.com/repos/{owner}/{repo}/issues"
    result = github_request(url, token=token, method="POST", data={"title": title, "body": body})
    return result["number"]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Export or create GitHub Issues from markdown task blocks that use the repo ## Task template."
    )
    parser.add_argument(
        "--input",
        default="CONTRIBUTING_AGENTS.md",
        help="Path to markdown containing repo ## Task blocks, or - to read from stdin.",
    )
    parser.add_argument("--owner", default="TeamLith", help="GitHub owner or organization.")
    parser.add_argument("--repo", default="lith", help="GitHub repository name.")
    parser.add_argument("--create", action="store_true", help="Create issues via the GitHub REST API.")
    parser.add_argument(
        "--source-mode",
        choices=["auto", "legacy-migration", "task-intake"],
        default="auto",
        help="How the task input should be labeled in generated issue bodies.",
    )
    parser.add_argument(
        "--manifest",
        help="Optional path to write the parsed issue payloads as JSON.",
    )
    args = parser.parse_args()

    text = read_input_text(args.input)
    source_mode = resolve_source_mode(args.input, args.source_mode)
    tasks = [task for task in parse_tasks(text) if task.status == "TODO"]
    payloads = [{"title": task.title, "body": build_issue_body(task, source_mode, args.input)} for task in tasks]

    if args.manifest:
        Path(args.manifest).write_text(json.dumps(payloads, indent=2) + "\n")

    if not args.create:
        print(f"Parsed {len(payloads)} pending tasks from {args.input}.")
        for payload in payloads:
            print(f"- {payload['title']}")
        return 0

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        print("Set GITHUB_TOKEN or GH_TOKEN to create issues.", file=sys.stderr)
        return 1

    created = 0
    for payload in payloads:
        number = existing_issue_number(args.owner, args.repo, payload["title"], token)
        if number is not None:
            print(f"Skipping existing issue #{number}: {payload['title']}")
            continue
        number = create_issue(args.owner, args.repo, payload["title"], payload["body"], token)
        created += 1
        print(f"Created issue #{number}: {payload['title']}")

    print(f"Created {created} new issues.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
