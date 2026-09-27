"""Planner endpoint behavior and storage across server sessions."""

import datetime;
import os;
import tempfile;
import from jaclang.testing.testing { JacTestClient }

glob SERVER: str = os.path.join(os.path.dirname(__file__), "main.jac");

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
            {"title": "Bad priority", "priority": "urgent"}
        ];
        for body in bad_requests {
            assert not client.post("/function/add_task", json=body).ok;
        }
        assert client.post("/function/list_tasks", json={}).data["result"] == [];
    } finally {
        client.close();
    }
}
