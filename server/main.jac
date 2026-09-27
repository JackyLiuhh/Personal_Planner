"""Planning API backed by one SQLite database shared across app processes."""

import datetime;
import os;
import sqlite3;
import uuid;

obj TaskView {
    has id: str,
        title: str,
        due_date: str,
        priority: str,
        done: bool;
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
    conn.execute("PRAGMA busy_timeout = 10000");
    conn.execute("PRAGMA journal_mode = WAL");
    conn.execute(
        "CREATE TABLE IF NOT EXISTS tasks ("
        "id TEXT PRIMARY KEY, "
        "title TEXT NOT NULL, "
        "due_date TEXT NOT NULL DEFAULT '', "
        "priority TEXT NOT NULL CHECK (priority IN ('high', 'medium', 'low')), "
        "done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1))"
        ")"
    );
    return conn;
}

def _to_view(row: sqlite3.Row) -> TaskView {
    return TaskView(
        id=str(row["id"]),
        title=str(row["title"]),
        due_date=str(row["due_date"]),
        priority=str(row["priority"]),
        done=bool(row["done"])
    );
}

def _clean_title(title: str) -> str {
    cleaned = title.strip();
    if not cleaned {
        raise ValueError("Task title cannot be empty");
    }
    return cleaned;
}

def _clean_due_date(due_date: str) -> str {
    cleaned = due_date.strip();
    if cleaned {
        try {
            parsed = datetime.date.fromisoformat(cleaned);
        } except ValueError {
            raise ValueError("Due date must be YYYY-MM-DD");
        }
        if parsed.isoformat() != cleaned {
            raise ValueError("Due date must be YYYY-MM-DD");
        }
    }
    return cleaned;
}

def _clean_priority(priority: str) -> str {
    cleaned = priority.strip().lower();
    if cleaned not in ["high", "medium", "low"] {
        raise ValueError("Priority must be high, medium, or low");
    }
    return cleaned;
}

def _priority_rank(priority: str) -> int {
    if priority == "high" {
        return 0;
    }
    if priority == "medium" {
        return 1;
    }
    return 2;
}

def:pub add_task(
    title: str, due_date: str = "", priority: str = "medium"
) -> TaskView {
    clean_title = _clean_title(title);
    clean_date = _clean_due_date(due_date);
    clean_priority = _clean_priority(priority);
    task_id = uuid.uuid4().hex;
    conn = _connect();
    try {
        conn.execute("BEGIN IMMEDIATE");
        conn.execute(
            "INSERT INTO tasks (id, title, due_date, priority, done) "
            "VALUES (?, ?, ?, ?, 0)",
            (task_id, clean_title, clean_date, clean_priority)
        );
        conn.commit();
    } finally {
        conn.close();
    }
    return TaskView(
        id=task_id, title=clean_title, due_date=clean_date,
        priority=clean_priority, done=False
    );
}

def:pub list_tasks -> list[TaskView] {
    conn = _connect();
    try {
        tasks = [
            _to_view(row)
            for row in conn.execute(
                "SELECT id, title, due_date, priority, done FROM tasks"
            ).fetchall()
        ];
    } finally {
        conn.close();
    }
    tasks.sort(
        key=lambda (task: TaskView) {
            (
                task.done,
                task.due_date == "",
                task.due_date,
                _priority_rank(task.priority),
                task.title.casefold(),
                task.id
            );
        }
    );
    return tasks;
}

def:pub today_plan -> list[TaskView] {
    today = datetime.date.today().isoformat();
    conn = _connect();
    try {
        tasks = [
            _to_view(row)
            for row in conn.execute(
                "SELECT id, title, due_date, priority, done FROM tasks "
                "WHERE done = 0 AND (due_date = '' OR due_date <= ?)",
                (today,)
            ).fetchall()
        ];
    } finally {
        conn.close();
    }
    tasks.sort(
        key=lambda (task: TaskView) {
            (
                task.due_date == "",
                task.due_date,
                _priority_rank(task.priority),
                task.title.casefold(),
                task.id
            );
        }
    );
    return tasks;
}

def:pub set_done(task_id: str, done: bool = True) -> TaskView | None {
    normalized = str(done).strip().lower();
    if normalized not in ["true", "false", "1", "0"] {
        raise ValueError("Done must be true or false");
    }
    done_value = 1 if normalized in ["true", "1"] else 0;
    conn = _connect();
    try {
        conn.execute("BEGIN IMMEDIATE");
        conn.execute(
            "UPDATE tasks SET done = ? WHERE id = ?", (done_value, task_id)
        );
        row = conn.execute(
            "SELECT id, title, due_date, priority, done FROM tasks WHERE id = ?",
            (task_id,)
        ).fetchone();
        conn.commit();
        return _to_view(row) if row is not None else None;
    } finally {
        conn.close();
    }
}

def:pub delete_task(task_id: str) -> bool {
    conn = _connect();
    try {
        conn.execute("BEGIN IMMEDIATE");
        deleted = conn.execute(
            "DELETE FROM tasks WHERE id = ?", (task_id,)
        ).rowcount > 0;
        conn.commit();
        return deleted;
    } finally {
        conn.close();
    }
}
