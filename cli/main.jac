"""Manage the same planner tasks used by the web and mobile apps."""

import argparse;
import asyncio;
import re;
import sys;
import from datetime { date }
import from jaclang.server.bridge { BridgeError, BridgeUnavailable }
import from server.main {
    TaskView,
    add_task,
    list_tasks,
    today_plan,
    day_plan,
    deadline_reminders,
    set_done,
    delete_task
}


def parse_date(value: str) -> str {
    if not value {
        return "";
    }
    try {
        parsed = date.fromisoformat(value);
        if parsed.isoformat() == value {
            return value;
        }
    } except ValueError {
        raise argparse.ArgumentTypeError("Use a valid date in YYYY-MM-DD format (for example, 2026-10-01).");
    }
    raise argparse.ArgumentTypeError("Use a valid date in YYYY-MM-DD format (for example, 2026-10-01).");
}


def parse_time(value: str) -> str {
    if not value {
        return "";
    }
    if re.fullmatch(r"(?:(?:[01][0-9]|2[0-3]):[0-5][0-9]|24:00)", value) {
        return value;
    }
    raise argparse.ArgumentTypeError("Use 24-hour HH:MM for --time (for example, 14:30).");
}


def parse_duration(value: str) -> int {
    try {
        minutes = int(value);
        if 0 <= minutes <= 1440 {
            return minutes;
        }
    } except ValueError {
        raise argparse.ArgumentTypeError("Duration must be a whole number from 0 to 1440 minutes.");
    }
    raise argparse.ArgumentTypeError("Duration must be a whole number from 0 to 1440 minutes.");
}


def build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog="planner",
        description="Add, review, and complete tasks in your shared Jac planner."
    );
    commands = parser.add_subparsers(dest="command", required=True);

    add = commands.add_parser("add", help="Add a task");
    add.add_argument("title", help="What needs to be done");
    add.add_argument("--deadline", action="store_true", help="Add a deadline or goal; --due is required and --time is the due time");
    add.add_argument("--due", dest="due_date", type=parse_date, `default="", help="Task date or first recurring date (YYYY-MM-DD)");
    add.add_argument(
        "--priority", choices=["low", "medium", "high"], `default="medium",
        help="Task priority (default: medium)"
    );
    add.add_argument("--time", dest="start_time", type=parse_time, `default="", help="Start time in 24-hour HH:MM format; requires --due");
    add.add_argument("--duration", dest="duration_minutes", type=parse_duration, `default=0, help="Expected duration in minutes (0 means not set)");
    add.add_argument(
        "--repeat", dest="recurrence", choices=["none", "daily", "weekdays", "weekly", "monthly"],
        `default="none", help="Repeat schedule (default: none); requires --due"
    );

    listing = commands.add_parser("list", help="Show saved tasks");
    listing.add_argument("--date", dest="plan_date", type=parse_date, `default="", help="Show recurring occurrences on or after this date (default: today)");
    listing.add_argument(
        "--status", choices=["all", "open", "done"], `default="all",
        help="Filter by completion status"
    );
    commands.add_parser("today", help="Show today's open plan");
    commands.add_parser("reminders", help="Show open deadlines and goals, earliest due first");
    day = commands.add_parser("day", help="Show a day's tasks, including completed tasks and the undated inbox");
    day.add_argument("plan_date", nargs="?", type=parse_date, `default="", help="Date in YYYY-MM-DD format (default: today)");

    done = commands.add_parser("done", help="Mark a task or recurring occurrence complete");
    done.add_argument("task_id", help="Task ID or a unique ID prefix");
    done.add_argument("--date", dest="occurrence_date", type=parse_date, `default="", help="Recurring occurrence date (default: next occurrence on or after today)");
    reopen = commands.add_parser("reopen", help="Mark a completed task or recurring occurrence open");
    reopen.add_argument("task_id", help="Task ID or a unique ID prefix");
    reopen.add_argument("--date", dest="occurrence_date", type=parse_date, `default="", help="Recurring occurrence date (default: next occurrence on or after today)");
    delete = commands.add_parser("delete", help="Delete a task or its entire recurring series");
    delete.add_argument("task_id", help="Task ID or a unique ID prefix");
    return parser;
}


def render_task(task: TaskView) -> str {
    mark = "[x]" if task.done else "[ ]";
    due = task.occurrence_date or task.due_date or "Undated inbox";
    if task.item_type == "deadline" {
        return f"{mark} {task.id}  {task.title}  (deadline / goal, due {due} " +
            (task.due_time or "end of day") + f", {task.priority})";
    }
    schedule = due + (" at " + task.start_time if task.start_time else ", no start time");
    duration = f"{task.duration_minutes} min" if task.duration_minutes else "duration not set";
    repeat = ", repeats " + task.recurrence if task.recurrence != "none" else "";
    return f"{mark} {task.id}  {task.title}  ({task.priority}, {schedule}, {duration}{repeat})";
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


def show_day(tasks: list[TaskView], plan_date: str, open_only: bool = False) -> None {
    heading = "Open plan" if open_only else "Plan";
    print(f"{heading} for {plan_date}");
    show_tasks(tasks, "No tasks in this plan.");
    counted = tasks if open_only else [task for task in tasks if task.due_date];
    total = sum(task.duration_minutes for task in counted);
    remaining = sum(task.duration_minutes for task in counted if not task.done);
    total_label = "Open backlog expected time" if open_only else "Scheduled expected time";
    print(f"{total_label}: {total} min | Remaining: {remaining} min");
    if `any(not task.due_date for task in tasks) {
        inbox_minutes = sum(task.duration_minutes for task in tasks if not task.due_date);
        hint = "Included in backlog total" if open_only else "Excluded from scheduled total";
        print(f"Undated inbox: {inbox_minutes} min. {hint}; assign dates to schedule these tasks.");
    }
}


async def resolve_task_id(prefix: str, plan_date: str = "") -> str {
    query = prefix.strip();
    if not query {
        print("A task ID is required.", file=sys.stderr);
        return "";
    }
    matches = [task.id for task in await list_tasks(plan_date) if task.id.startswith(query)];
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
        if not args.due_date and (args.start_time or args.recurrence != "none") {
            print("Add --due YYYY-MM-DD when using --time or --repeat.", file=sys.stderr);
            return 2;
        }
        if args.deadline and (not args.due_date or args.duration_minutes or args.recurrence != "none") {
            print("Deadlines need --due and do not use --duration or --repeat. Use --time for the due time.", file=sys.stderr);
            return 2;
        }
        task = await add_task(title, args.due_date, args.priority,
            "" if args.deadline else args.start_time, args.duration_minutes, args.recurrence,
            "deadline" if args.deadline else "task", args.start_time if args.deadline else "");
        print("Added " + render_task(task));
        return 0;
    }
    if args.command == "list" {
        tasks = await list_tasks(args.plan_date);
        if args.status == "open" {
            tasks = [task for task in tasks if not task.done];
        } elif args.status == "done" {
            tasks = [task for task in tasks if task.done];
        }
        show_tasks(tasks, "No tasks found.");
        return 0;
    }
    if args.command == "today" {
        show_day(await today_plan(), date.today().isoformat(), True);
        return 0;
    }
    if args.command == "reminders" {
        show_tasks(await deadline_reminders(), "No open deadlines or goals.");
        return 0;
    }
    if args.command == "day" {
        plan_date = args.plan_date or date.today().isoformat();
        show_day(await day_plan(plan_date), plan_date);
        return 0;
    }
    if args.command == "done" or args.command == "reopen" {
        task_id = await resolve_task_id(args.task_id, args.occurrence_date);
        if not task_id {
            return 1;
        }
        updated = await set_done(task_id, args.command == "done", args.occurrence_date);
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
