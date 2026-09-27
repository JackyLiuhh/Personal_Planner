"""Manage the same planner tasks used by the web and mobile apps."""

import argparse;
import asyncio;
import sys;
import from datetime { date }
import from jaclang.server.bridge { BridgeError, BridgeUnavailable }
import from server.main {
    TaskView,
    add_task,
    list_tasks,
    today_plan,
    set_done,
    delete_task
}


def build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog="planner",
        description="Add, review, and complete tasks in your shared Jac planner."
    );
    commands = parser.add_subparsers(dest="command", required=True);

    add = commands.add_parser("add", help="Add a task");
    add.add_argument("title", help="What needs to be done");
    add.add_argument("--due", dest="due_date", `default="", help="Due date (YYYY-MM-DD)");
    add.add_argument(
        "--priority", choices=["low", "medium", "high"], `default="medium",
        help="Task priority (default: medium)"
    );

    listing = commands.add_parser("list", help="Show saved tasks");
    listing.add_argument(
        "--status", choices=["all", "open", "done"], `default="all",
        help="Filter by completion status"
    );
    commands.add_parser("today", help="Show today's open plan");

    done = commands.add_parser("done", help="Mark a task complete");
    done.add_argument("task_id", help="Task ID or a unique ID prefix");
    reopen = commands.add_parser("reopen", help="Mark a completed task open");
    reopen.add_argument("task_id", help="Task ID or a unique ID prefix");
    delete = commands.add_parser("delete", help="Delete a task");
    delete.add_argument("task_id", help="Task ID or a unique ID prefix");
    return parser;
}


def render_task(task: TaskView) -> str {
    mark = "[x]" if task.done else "[ ]";
    due = task.due_date if task.due_date else "No due date";
    return f"{mark} {task.id}  {task.title}  ({task.priority}, {due})";
}


def show_tasks(tasks: list[TaskView], empty_message: str) -> None {
    if not tasks {
        print(empty_message);
        return;
    }
    for task in tasks {
        print(render_task(task));
    }
}


async def resolve_task_id(prefix: str) -> str {
    query = prefix.strip();
    if not query {
        print("A task ID is required.", file=sys.stderr);
        return "";
    }
    matches = [task.id for task in await list_tasks() if task.id.startswith(query)];
    if len(matches) == 1 {
        return matches[0];
    }
    if not matches {
        print(f"No task matches '{query}'. Run `jac run cli -- list` to see IDs.", file=sys.stderr);
    } else {
        print(f"'{query}' matches multiple tasks. Use a longer ID prefix.", file=sys.stderr);
    }
    return "";
}


async def dispatch(args: argparse.Namespace) -> int {
    if args.command == "add" {
        title = args.title.strip();
        if not title {
            print("Task title cannot be empty.", file=sys.stderr);
            return 2;
        }
        due_date = args.due_date;
        if due_date {
            try {
                _ = date.fromisoformat(due_date);
            } except ValueError {
                print("Use YYYY-MM-DD for --due (for example, 2026-10-01).", file=sys.stderr);
                return 2;
            }
        }
        task = await add_task(title, due_date, args.priority);
        print("Added " + render_task(task));
        return 0;
    }
    if args.command == "list" {
        tasks = await list_tasks();
        if args.status == "open" {
            tasks = [task for task in tasks if not task.done];
        } elif args.status == "done" {
            tasks = [task for task in tasks if task.done];
        }
        show_tasks(tasks, "No tasks found.");
        return 0;
    }
    if args.command == "today" {
        show_tasks(await today_plan(), "Your plan is clear today.");
        return 0;
    }
    if args.command == "done" or args.command == "reopen" {
        task_id = await resolve_task_id(args.task_id);
        if not task_id {
            return 1;
        }
        updated = await set_done(task_id, args.command == "done");
        if updated is None {
            print("Task no longer exists. Run `jac run cli -- list` to refresh.", file=sys.stderr);
            return 1;
        }
        print(("Completed " if updated.done else "Reopened ") + render_task(updated));
        return 0;
    }
    if args.command == "delete" {
        task_id = await resolve_task_id(args.task_id);
        if not task_id {
            return 1;
        }
        if not await delete_task(task_id) {
            print("Task no longer exists. Run `jac run cli -- list` to refresh.", file=sys.stderr);
            return 1;
        }
        print("Deleted task " + task_id);
        return 0;
    }
    return 2;
}


async def main(argv: list[str] | None = None) -> int {
    args = build_parser().parse_args(argv);
    try {
        return await dispatch(args);
    } except BridgeUnavailable {
        print(
            "Planner service is unavailable. Start `jac run planner` and set "
            "JAC_APP_SERVER_URL to the printed API URL plus /api/server.",
            file=sys.stderr
        );
        return 3;
    } except BridgeError as error {
        print("Planner service error: " + (error.detail or str(error)), file=sys.stderr);
        return 1;
    }
}


with entry:__main__ {
    sys.`exit(asyncio.run(main()));
}
