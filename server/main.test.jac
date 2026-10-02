"""Planner endpoint behavior and storage across server sessions."""

import datetime;
import os;
import tempfile;
import sqlite3;
import from concurrent.futures { ThreadPoolExecutor }
import from jaclang.testing.testing { JacTestClient }

glob SERVER: str = os.path.join(os.path.dirname(__file__), "main.jac");

def _migration_probe -> int {
    conn = _connect();
    try { return int(conn.execute("SELECT count(*) FROM tasks").fetchone()[0]); }
    finally { conn.close(); }
}

test "today includes overdue and undated work, and mutations use stable IDs" {
    os.environ["PLANNER_DB_PATH"] = os.path.join(
        tempfile.mkdtemp(), "planner.sqlite3"
    );
    client = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        today = datetime.date.today();
        yesterday = (today - datetime.timedelta(days=1)).isoformat();
        tomorrow = (today + datetime.timedelta(days=1)).isoformat();
        overdue = client.post(
            "/function/add_task",
            json={"title": "Overdue", "due_date": yesterday, "priority": "low"}
        ).data["result"];
        client.post(
            "/function/add_task",
            json={"title": "Today low", "due_date": today.isoformat(), "priority": "low"}
        );
        client.post(
            "/function/add_task",
            json={"title": "Today high", "due_date": today.isoformat(), "priority": "high"}
        );
        inbox = client.post(
            "/function/add_task", json={"title": "Inbox", "priority": "high"}
        ).data["result"];
        client.post(
            "/function/add_task", json={"title": "Future", "due_date": tomorrow}
        );

        plan = client.post("/function/today_plan", json={}).data["result"];
        assert [task["title"] for task in plan] == [
            "Overdue", "Today high", "Today low", "Inbox"
        ];
        updated = client.post(
            "/function/set_done", json={"task_id": overdue["id"]}
        ).data["result"];
        assert updated["done"] is True, str(updated);
        assert [task["title"] for task in client.post(
            "/function/today_plan", json={}
        ).data["result"]] == ["Today high", "Today low", "Inbox"];

        removed = client.post(
            "/function/delete_task", json={"task_id": inbox["id"]}
        );
        assert removed.data["result"] is True;
        assert client.post(
            "/function/delete_task", json={"task_id": inbox["id"]}
        ).data["result"] is False;
        all_tasks = client.post("/function/list_tasks", json={}).data["result"];
        assert [task["title"] for task in all_tasks] == [
            "Today high", "Today low", "Future", "Overdue"
        ];
        reopened = client.post(
            "/function/set_done",
            json={"task_id": overdue["id"], "done": False}
        ).data["result"];
        assert reopened["done"] is False;
        assert client.post("/function/today_plan", json={}).data["result"][0]["id"] == overdue["id"];
    } finally {
        client.close();
    }
}

test "independent server contexts share the same SQLite task file" {
    os.environ["PLANNER_DB_PATH"] = os.path.join(
        tempfile.mkdtemp(), "planner.sqlite3"
    );
    first = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        created = first.post(
            "/function/add_task", json={"title": "Persist me"}
        ).data["result"];
        assert created["id"];
    } finally {
        first.close();
    }

    second = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        tasks = second.post("/function/list_tasks", json={}).data["result"];
        assert [(task["id"], task["title"]) for task in tasks] == [
            (created["id"], "Persist me")
        ];
    } finally {
        second.close();
    }
}

test "invalid task input does not create stored work" {
    os.environ["PLANNER_DB_PATH"] = os.path.join(
        tempfile.mkdtemp(), "planner.sqlite3"
    );
    client = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        bad_requests = [
            {"title": "   "},
            {"title": "Bad date", "due_date": "2026-02-30"},
            {"title": "Bad priority", "priority": "urgent"},
            {"title": "Bad time", "due_date": "2026-10-01", "start_time": "9:00"},
            {"title": "Bad time", "due_date": "2026-10-01", "start_time": "24:01"},
            {"title": "Bad time", "due_date": "2026-10-01", "start_time": "25:00"},
            {"title": "Bad time", "due_date": "2026-10-01", "start_time": "10:60"},
            {"title": "No time date", "start_time": "09:00"},
            {"title": "No repeat date", "recurrence": "daily"},
            {"title": "Bad repeat", "due_date": "2026-10-01", "recurrence": "yearly"},
            {"title": "Negative minutes", "duration_minutes": -1},
            {"title": "Too long", "duration_minutes": 1441},
            {"title": "Fraction", "duration_minutes": 1.5},
            {"title": "Fraction string", "duration_minutes": "1.5"},
            {"title": "Boolean", "duration_minutes": True},
            {"title": "Text", "duration_minutes": "tomorrow"}
        ];
        for body in bad_requests {
            assert not client.post("/function/add_task", json=body).ok, str(body);
        }
        assert client.post("/function/list_tasks", json={}).data["result"] == [];
        assert not client.post("/function/day_plan", json={"plan_date": "2026-02-30"}).ok;
        assert not client.post("/function/list_tasks", json={"plan_date": "20260201"}).ok;
    } finally {
        client.close();
    }
}

test "start times preserve the inclusive day boundaries in order" {
    os.environ["PLANNER_DB_PATH"] = os.path.join(tempfile.mkdtemp(), "planner.sqlite3");
    client = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        for time in ["24:00", "00:00", "23:59", "09:07"] {
            response = client.post("/function/add_task", json={
                "title": "At " + time, "due_date": "2026-10-01", "start_time": time
            });
            assert response.ok;
            assert response.data["result"]["start_time"] == time;
        }
        tasks = client.post("/function/day_plan", json={"plan_date": "2026-10-01"}).data["result"];
        assert [task["start_time"] for task in tasks] == ["00:00", "09:07", "23:59", "24:00"];
    } finally {
        client.close();
    }
}

test "migration preserves existing task IDs and completion without duplicate columns" {
    path = os.path.join(tempfile.mkdtemp(), "legacy.sqlite3");
    os.environ["PLANNER_DB_PATH"] = path;
    conn = sqlite3.connect(path);
    conn.execute("CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, "
                 "due_date TEXT NOT NULL DEFAULT '', priority TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0)");
    conn.execute("INSERT INTO tasks VALUES ('legacy-id', 'Existing task', '2026-10-01', 'high', 1)");
    conn.commit();
    conn.close();
    client = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        for repeat in range(2) {
            tasks = client.post("/function/list_tasks", json={}).data["result"];
            assert len(tasks) == 1;
            task = tasks[0];
            assert task["id"] == "legacy-id" and task["title"] == "Existing task";
            assert task["done"] is True and task["due_date"] == "2026-10-01";
            assert task["recurrence"] == "none" and task["occurrence_date"] == "2026-10-01";
            assert task["start_time"] == "" and task["duration_minutes"] == 0;
            assert task["item_type"] == "task" and task["due_time"] == "";
        }
        created = client.post("/function/add_task", json={
            "title": "New task", "due_date": "2026-10-02", "start_time": "09:30",
            "duration_minutes": "45", "recurrence": "daily"
        });
        assert created.ok, str(created.data);
        assert created.data["result"]["duration_minutes"] == 45;
        assert len(client.post("/function/list_tasks", json={}).data["result"]) == 2;
    } finally { client.close(); }
}

test "calendar recurrence projects anchors weekends and month ends" {
    os.environ["PLANNER_DB_PATH"] = os.path.join(tempfile.mkdtemp(), "planner.sqlite3");
    client = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        cases = [
            ("daily", "2026-09-28", "2026-09-27", "2026-09-28"),
            ("daily", "2026-09-28", "2026-10-03", "2026-10-03"),
            ("weekdays", "2026-09-26", "2026-09-26", "2026-09-28"),
            ("weekdays", "2026-09-28", "2026-10-03", "2026-10-05"),
            ("weekly", "2026-09-28", "2026-10-04", "2026-10-05"),
            ("weekly", "2026-09-28", "2026-10-05", "2026-10-05"),
            ("monthly", "2026-01-31", "2026-02-01", "2026-02-28"),
            ("monthly", "2026-01-31", "2026-03-01", "2026-03-31"),
            ("monthly", "2028-01-31", "2028-02-01", "2028-02-29"),
            ("monthly", "2028-02-29", "2029-02-01", "2029-02-28"),
            ("monthly", "2026-01-30", "2026-04-01", "2026-04-30"),
            ("monthly", "2026-01-31", "2026-12-31", "2026-12-31"),
            ("monthly", "2026-01-31", "2027-01-01", "2027-01-31")
        ];
        for (recurrence, anchor, selected, expected) in cases {
            created = client.post("/function/add_task", json={
                "title": "Calendar task", "due_date": anchor, "recurrence": recurrence
            }).data["result"];
            projected = client.post("/function/list_tasks", json={"plan_date": selected}).data["result"];
            assert len(projected) == 1;
            assert projected[0]["due_date"] == anchor;
            assert projected[0]["occurrence_date"] == expected, str((recurrence, anchor, selected, projected));
            on_day = client.post("/function/day_plan", json={"plan_date": expected}).data["result"];
            assert len(on_day) == 1 and on_day[0]["id"] == created["id"];
            if selected != expected {
                assert client.post("/function/day_plan", json={"plan_date": selected}).data["result"] == [];
            }
            assert client.post("/function/delete_task", json={"task_id": created["id"]}).data["result"];
        }
    } finally { client.close(); }
}

test "simultaneous app connections serialize the legacy migration" {
    path = os.path.join(tempfile.mkdtemp(), "legacy.sqlite3");
    os.environ["PLANNER_DB_PATH"] = path;
    conn = sqlite3.connect(path);
    conn.execute("CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, "
                 "due_date TEXT NOT NULL DEFAULT '', priority TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0)");
    conn.execute("INSERT INTO tasks VALUES ('legacy-id', 'Existing task', '', 'medium', 0)");
    conn.commit();
    conn.close();
    with ThreadPoolExecutor(max_workers=4) as executor {
        pending = [executor.submit(_migration_probe) for iteration in range(4)];
        assert [future.result() for future in pending] == [1, 1, 1, 1];
    }
    conn = sqlite3.connect(path);
    try {
        columns = [row[1] for row in conn.execute("PRAGMA table_info(tasks)")];
        assert columns == ["id", "title", "due_date", "priority", "done", "start_time", "duration_minutes", "recurrence", "item_type", "due_time"];
    } finally { conn.close(); }
}

test "day breakdown keeps completed timed tasks in order and includes inbox" {
    os.environ["PLANNER_DB_PATH"] = os.path.join(tempfile.mkdtemp(), "planner.sqlite3");
    client = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        early = client.post("/function/add_task", json={
            "title": "Morning", "due_date": "2026-10-01", "start_time": "09:00", "duration_minutes": 60
        }).data["result"];
        client.post("/function/set_done", json={"task_id": early["id"]});
        client.post("/function/add_task", json={
            "title": "Afternoon", "due_date": "2026-10-01", "start_time": "14:30", "duration_minutes": "90"
        });
        client.post("/function/add_task", json={"title": "Anytime", "due_date": "2026-10-01", "priority": "low"});
        client.post("/function/add_task", json={"title": "Inbox", "priority": "high", "duration_minutes": 1440});
        client.post("/function/add_task", json={"title": "Yesterday", "due_date": "2026-09-30"});
        client.post("/function/add_task", json={"title": "Tomorrow", "due_date": "2026-10-02"});
        plan = client.post("/function/day_plan", json={"plan_date": "2026-10-01"}).data["result"];
        assert [task["title"] for task in plan] == ["Morning", "Afternoon", "Inbox", "Anytime"];
        assert plan[0]["done"] is True;
        assert plan[0]["start_time"] == "09:00" and plan[0]["duration_minutes"] == 60;
        assert plan[1]["duration_minutes"] == 90 and plan[2]["duration_minutes"] == 1440;
        assert [task["title"] for task in client.post(
            "/function/day_plan", json={"plan_date": "2026-10-02"}
        ).data["result"]] == ["Inbox", "Tomorrow"];
    } finally { client.close(); }
}

test "occurrence completion persists independently and deleting series cleans completions" {
    path = os.path.join(tempfile.mkdtemp(), "planner.sqlite3");
    os.environ["PLANNER_DB_PATH"] = path;
    first = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        created = first.post("/function/add_task", json={
            "title": "Weekly study", "due_date": "2026-09-28", "recurrence": "weekly"
        }).data["result"];
        task_id = created["id"];
        assert first.post("/function/set_done", json={
            "task_id": task_id, "occurrence_date": "2026-09-28"
        }).data["result"]["done"] is True;
        assert not first.post("/function/set_done", json={
            "task_id": task_id, "occurrence_date": "2026-09-29"
        }).ok;
        assert not first.post("/function/set_done", json={
            "task_id": task_id, "occurrence_date": "2026-09-21"
        }).ok;
    } finally { first.close(); }
    second = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        first_day = second.post("/function/day_plan", json={"plan_date": "2026-09-28"}).data["result"];
        second_day = second.post("/function/day_plan", json={"plan_date": "2026-10-05"}).data["result"];
        assert first_day[0]["done"] is True;
        assert second_day[0]["done"] is False;
        assert first_day[0]["id"] == second_day[0]["id"];
        assert second.post("/function/set_done", json={
            "task_id": task_id, "occurrence_date": "2026-10-05"
        }).data["result"]["done"] is True;
        assert second.post("/function/set_done", json={
            "task_id": task_id, "occurrence_date": "2026-09-28", "done": False
        }).data["result"]["done"] is False;
        assert second.post("/function/day_plan", json={"plan_date": "2026-10-05"}).data["result"][0]["done"] is True;
        assert second.post("/function/list_tasks", json={"plan_date": "2026-10-05"}).data["result"][0]["done"] is True;
        assert second.post("/function/delete_task", json={"task_id": task_id}).data["result"] is True;
        assert second.post("/function/day_plan", json={"plan_date": "2026-10-05"}).data["result"] == [];
        conn = sqlite3.connect(path);
        try { assert conn.execute("SELECT count(*) FROM task_completions").fetchone()[0] == 0; }
        finally { conn.close(); }
    } finally { second.close(); }
}

test "today returns one current recurring occurrence and completion defaults to that day" {
    os.environ["PLANNER_DB_PATH"] = os.path.join(tempfile.mkdtemp(), "planner.sqlite3");
    client = JacTestClient.from_file(SERVER, base_path=tempfile.mkdtemp());
    try {
        today = datetime.date.today();
        anchor = (today - datetime.timedelta(days=30)).isoformat();
        created = client.post("/function/add_task", json={
            "title": "Daily habit", "due_date": anchor, "recurrence": "daily"
        }).data["result"];
        plan = client.post("/function/today_plan", json={}).data["result"];
        assert len(plan) == 1 and plan[0]["occurrence_date"] == today.isoformat();
        completed = client.post("/function/set_done", json={"task_id": created["id"]}).data["result"];
        assert completed["occurrence_date"] == today.isoformat() and completed["done"] is True;
        assert client.post("/function/today_plan", json={}).data["result"] == [];
        assert client.post("/function/day_plan", json={}).data["result"][0]["done"] is True;
        tomorrow = (today + datetime.timedelta(days=1)).isoformat();
        assert client.post("/function/day_plan", json={"plan_date": tomorrow}).data["result"][0]["done"] is False;
    } finally { client.close(); }
}

test "deadlines persist and reminders retain overdue goals until completion" {
    os.environ["PLANNER_DB_PATH"] = os.path.join(tempfile.mkdtemp(), "planner.sqlite3");
    task = add_task("Study", "2026-10-01", duration_minutes=45);
    late = add_task("Submit project", "2026-10-03", item_type="deadline", due_time="17:00");
    all_day = add_task("Finish reading", "2026-10-01", item_type="deadline");
    early = add_task("Upload assignment", "2026-10-01", item_type="deadline", due_time="09:30");
    assert early.start_time == "" and early.duration_minutes == 0;
    assert early.due_time == "09:30" and early.item_type == "deadline";
    assert [item.id for item in deadline_reminders()] == [early.id, all_day.id, late.id];
    assert sum(item.duration_minutes for item in day_plan("2026-10-01")) == 45;
    # Each call reopens the database; fields and completion survive connection changes.
    restored = [item for item in list_tasks("2027-01-01") if item.id == early.id][0];
    assert restored.due_time == "09:30" and restored.item_type == "deadline";
    assert len(deadline_reminders()) == 3;
    set_done(early.id, True, "2026-10-01");
    assert [item.id for item in deadline_reminders()] == [all_day.id, late.id];
    set_done(early.id, False, "2026-10-01");
    assert deadline_reminders()[0].id == early.id;
    assert delete_task(early.id);
    assert [item.id for item in deadline_reminders()] == [all_day.id, late.id];
    assert task.id not in [item.id for item in deadline_reminders()];
}

test "deadline validation rejects missing dates and scheduled work fields" {
    os.environ["PLANNER_DB_PATH"] = os.path.join(tempfile.mkdtemp(), "planner.sqlite3");
    for fields in [
        {"item_type": "deadline"},
        {"item_type": "unknown", "due_date": "2026-10-01"},
        {"item_type": "deadline", "due_date": "2026-10-01", "due_time": "24:01"},
        {"item_type": "deadline", "due_date": "2026-10-01", "start_time": "09:00"},
        {"item_type": "deadline", "due_date": "2026-10-01", "duration_minutes": 30},
        {"item_type": "deadline", "due_date": "2026-10-01", "recurrence": "daily"},
        {"due_date": "2026-10-01", "due_time": "17:00"}
    ] {
        rejected = False;
        try { add_task("Invalid", **fields); }
        except ValueError { rejected = True; }
        assert rejected, str(fields);
    }
    assert list_tasks() == [];
    midnight = add_task("End of day", "2026-10-01", item_type="deadline", due_time="24:00");
    assert deadline_reminders()[0].due_time == midnight.due_time == "24:00";
}
