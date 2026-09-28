"""Planning API backed by one SQLite database shared across app processes."""

import calendar;
import datetime;
import os;
import re;
import sqlite3;
import uuid;

obj TaskView {
    has id: str,
        title: str,
        due_date: str,
        priority: str,
        done: bool,
        start_time: str = "",
        duration_minutes: int = 0,
        recurrence: str = "none",
        occurrence_date: str = "";
}

def _database_path -> str {
    configured = os.environ.get("PLANNER_DB_PATH", "");
    if configured {
        return os.path.abspath(configured);
    }
    return os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", ".jac", "data", "planner.sqlite3")
    );
}

def _connect -> sqlite3.Connection {
    path = _database_path();
    os.makedirs(os.path.dirname(path), exist_ok=True);
    conn = sqlite3.connect(path, timeout=10.0);
    conn.row_factory = sqlite3.Row;
    try {
        conn.execute("PRAGMA busy_timeout = 10000");
        conn.execute("PRAGMA journal_mode = WAL");
        conn.execute("PRAGMA foreign_keys = ON");
        # Serialize schema checks and additive migrations across app processes.
        conn.execute("BEGIN IMMEDIATE");
        conn.execute(
            "CREATE TABLE IF NOT EXISTS tasks ("
            "id TEXT PRIMARY KEY, title TEXT NOT NULL, "
            "due_date TEXT NOT NULL DEFAULT '', "
            "priority TEXT NOT NULL CHECK (priority IN ('high', 'medium', 'low')), "
            "done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1))"
            ")"
        );
        columns = [str(row["name"]) for row in conn.execute("PRAGMA table_info(tasks)")];
        for (name, definition) in [
            ("start_time", "TEXT NOT NULL DEFAULT ''"),
            ("duration_minutes", "INTEGER NOT NULL DEFAULT 0"),
            ("recurrence", "TEXT NOT NULL DEFAULT 'none'")
        ] {
            if name not in columns {
                conn.execute(f"ALTER TABLE tasks ADD COLUMN {name} {definition}");
            }
        }
        conn.execute(
            "CREATE TABLE IF NOT EXISTS task_completions ("
            "task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, "
            "occurrence_date TEXT NOT NULL, "
            "PRIMARY KEY (task_id, occurrence_date))"
        );
        conn.commit();
    } except Exception {
        conn.close();
        raise;
    }
    return conn;
}

def _to_view(row: sqlite3.Row, occurrence_date: str, done: bool) -> TaskView {
    return TaskView(
        id=str(row["id"]), title=str(row["title"]),
        due_date=str(row["due_date"]), priority=str(row["priority"]), done=done,
        start_time=str(row["start_time"]), duration_minutes=int(row["duration_minutes"]),
        recurrence=str(row["recurrence"]), occurrence_date=occurrence_date
    );
}

def _clean_title(title: str) -> str {
    cleaned = title.strip();
    if not cleaned { raise ValueError("Task title cannot be empty"); }
    return cleaned;
}

def _clean_due_date(due_date: str) -> str {
    cleaned = due_date.strip();
    if cleaned {
        try { parsed = datetime.date.fromisoformat(cleaned); }
        except ValueError { raise ValueError("Date must be YYYY-MM-DD"); }
        if parsed.isoformat() != cleaned { raise ValueError("Date must be YYYY-MM-DD"); }
    }
    return cleaned;
}

def _plan_date(plan_date: str) -> str {
    return _clean_due_date(plan_date) or datetime.date.today().isoformat();
}

def _clean_priority(priority: str) -> str {
    cleaned = priority.strip().lower();
    if cleaned not in ["high", "medium", "low"] {
        raise ValueError("Priority must be high, medium, or low");
    }
    return cleaned;
}

def _clean_time(start_time: str) -> str {
    cleaned = start_time.strip();
    if cleaned and re.fullmatch(r"(?:[01][0-9]|2[0-3]):[0-5][0-9]", cleaned) is None {
        raise ValueError("Start time must be HH:MM in 24-hour time");
    }
    return cleaned;
}

def _clean_duration(duration_minutes: str | int) -> int {
    # Keep numeric text until validation: int(1.5) would silently shorten a task.
    text = str(duration_minutes).strip();
    if re.fullmatch(r"[0-9]+", text) is None {
        raise ValueError("Duration must be a whole number of minutes from 0 to 1440");
    }
    value = int(text);
    if value > 1440 {
        raise ValueError("Duration must be a whole number of minutes from 0 to 1440");
    }
    return value;
}

def _clean_recurrence(recurrence: str) -> str {
    cleaned = recurrence.strip().lower();
    if cleaned not in ["none", "daily", "weekdays", "weekly", "monthly"] {
        raise ValueError("Repeat must be none, daily, weekdays, weekly, or monthly");
    }
    return cleaned;
}

def _priority_rank(priority: str) -> int {
    if priority == "high" { return 0; }
    if priority == "medium" { return 1; }
    return 2;
}

def _next_occurrence(anchor_text: str, recurrence: str, target_text: str) -> str {
    anchor = datetime.date.fromisoformat(anchor_text);
    target = datetime.date.fromisoformat(target_text);
    if target < anchor { target = anchor; }
    try {
        if recurrence == "daily" { return target.isoformat(); }
        if recurrence == "weekdays" {
            while target.weekday() >= 5 { target += datetime.timedelta(days=1); }
            return target.isoformat();
        }
        if recurrence == "weekly" {
            days = (target - anchor).days;
            return (anchor + datetime.timedelta(days=((days + 6) // 7) * 7)).isoformat();
        }
        if recurrence == "monthly" {
            year = target.year;
            month = target.month;
            day = min(anchor.day, calendar.monthrange(year, month)[1]);
            candidate = datetime.date(year, month, day);
            if candidate < target {
                month += 1;
                if month == 13 { year += 1; month = 1; }
                day = min(anchor.day, calendar.monthrange(year, month)[1]);
                candidate = datetime.date(year, month, day);
            }
            return candidate.isoformat();
        }
    } except (ValueError, OverflowError) {
        # No representable next date after the supported calendar's final day.
        return "";
    }
    return anchor_text;
}

def _project(conn: sqlite3.Connection, row: sqlite3.Row, occurrence_date: str) -> TaskView {
    done = bool(row["done"]);
    if str(row["recurrence"]) != "none" {
        done = conn.execute(
            "SELECT 1 FROM task_completions WHERE task_id = ? AND occurrence_date = ?",
            (str(row["id"]), occurrence_date)
        ).fetchone() is not None;
    }
    return _to_view(row, occurrence_date, done);
}

def _sort_day(tasks: list[TaskView]) {
    tasks.sort(key=lambda (task: TaskView) {
        (task.start_time == "", task.start_time, _priority_rank(task.priority),
         task.title.casefold(), task.id);
    });
}

def:pub add_task(
    title: str, due_date: str = "", priority: str = "medium",
    start_time: str = "", duration_minutes: str | int = 0, recurrence: str = "none"
) -> TaskView {
    clean_title = _clean_title(title);
    clean_date = _clean_due_date(due_date);
    clean_priority = _clean_priority(priority);
    clean_time = _clean_time(start_time);
    clean_duration = _clean_duration(duration_minutes);
    clean_recurrence = _clean_recurrence(recurrence);
    if not clean_date and (clean_time or clean_recurrence != "none") {
        raise ValueError("Choose a date for a start time or recurring task");
    }
    task_id = uuid.uuid4().hex;
    conn = _connect();
    try {
        conn.execute("BEGIN IMMEDIATE");
        conn.execute(
            "INSERT INTO tasks (id, title, due_date, priority, done, start_time, "
            "duration_minutes, recurrence) VALUES (?, ?, ?, ?, 0, ?, ?, ?)",
            (task_id, clean_title, clean_date, clean_priority,
             clean_time, clean_duration, clean_recurrence)
        );
        conn.commit();
    } finally { conn.close(); }
    occurrence = clean_date;
    if clean_recurrence != "none" {
        occurrence = _next_occurrence(clean_date, clean_recurrence, clean_date);
    }
    return TaskView(
        id=task_id, title=clean_title, due_date=clean_date,
        priority=clean_priority, done=False, start_time=clean_time,
        duration_minutes=clean_duration, recurrence=clean_recurrence,
        occurrence_date=occurrence
    );
}

def:pub list_tasks(plan_date: str = "") -> list[TaskView] {
    selected = _plan_date(plan_date);
    conn = _connect();
    tasks: list[TaskView] = [];
    try {
        for row in conn.execute("SELECT * FROM tasks").fetchall() {
            occurrence = str(row["due_date"]);
            if str(row["recurrence"]) != "none" {
                occurrence = _next_occurrence(occurrence, str(row["recurrence"]), selected);
                if not occurrence { continue; }
            }
            tasks.append(_project(conn, row, occurrence));
        }
    } finally { conn.close(); }
    tasks.sort(key=lambda (task: TaskView) {
        (task.done, task.occurrence_date == "", task.occurrence_date,
         task.start_time == "", task.start_time, _priority_rank(task.priority),
         task.title.casefold(), task.id);
    });
    return tasks;
}

def:pub day_plan(plan_date: str = "") -> list[TaskView] {
    selected = _plan_date(plan_date);
    conn = _connect();
    tasks: list[TaskView] = [];
    try {
        for row in conn.execute("SELECT * FROM tasks").fetchall() {
            due = str(row["due_date"]);
            recurrence = str(row["recurrence"]);
            if recurrence == "none" {
                if due == "" or due == selected { tasks.append(_project(conn, row, due)); }
            } elif _next_occurrence(due, recurrence, selected) == selected {
                tasks.append(_project(conn, row, selected));
            }
        }
    } finally { conn.close(); }
    _sort_day(tasks);
    return tasks;
}

def:pub today_plan -> list[TaskView] {
    today = datetime.date.today().isoformat();
    tasks = [task for task in list_tasks(today)
             if not task.done and (task.occurrence_date == "" or task.occurrence_date <= today)];
    return tasks;
}

def:pub set_done(task_id: str, done: bool = True, occurrence_date: str = "") -> TaskView | None {
    normalized = str(done).strip().lower();
    if normalized not in ["true", "false", "1", "0"] {
        raise ValueError("Done must be true or false");
    }
    done_value = normalized in ["true", "1"];
    selected = _clean_due_date(occurrence_date);
    conn = _connect();
    try {
        conn.execute("BEGIN IMMEDIATE");
        row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone();
        if row is None { conn.commit(); return None; }
        recurrence = str(row["recurrence"]);
        due = str(row["due_date"]);
        if recurrence == "none" {
            if selected and selected != due {
                raise ValueError("Occurrence date does not match this task's date");
            }
            selected = due;
            conn.execute("UPDATE tasks SET done = ? WHERE id = ?", (int(done_value), task_id));
        } else {
            if not selected {
                selected = _next_occurrence(due, recurrence, datetime.date.today().isoformat());
            }
            if not selected or _next_occurrence(due, recurrence, selected) != selected {
                raise ValueError("This recurring task is not scheduled on that date");
            }
            if done_value {
                conn.execute(
                    "INSERT OR IGNORE INTO task_completions (task_id, occurrence_date) VALUES (?, ?)",
                    (task_id, selected)
                );
            } else {
                conn.execute("DELETE FROM task_completions WHERE task_id = ? AND occurrence_date = ?",
                             (task_id, selected));
            }
        }
        conn.commit();
        return _to_view(row, selected, done_value);
    } finally { conn.close(); }
}

def:pub delete_task(task_id: str) -> bool {
    conn = _connect();
    try {
        conn.execute("BEGIN IMMEDIATE");
        deleted = conn.execute("DELETE FROM tasks WHERE id = ?", (task_id,)).rowcount > 0;
        conn.commit();
        return deleted;
    } finally { conn.close(); }
}
