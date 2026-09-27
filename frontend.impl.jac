"""Planner browser actions."""

impl app.refresh -> None {
    try {
        fresh_tasks = await list_tasks();
        fresh_today_tasks = await today_plan();
        tasks = fresh_tasks;
        today_tasks = fresh_today_tasks;
        error = "";
    } except Exception as exc {
        error = str(exc);
    }
    loaded = True;
}

impl app.submitTask(e: FormEvent) -> None {
    e.preventDefault();
    if not title.strip() or busy {
        return;
    }
    busy = True;
    try {
        await add_task(title=title.strip(), due_date=due_date, priority=priority);
        title = "";
        due_date = "";
        priority = "medium";
        await refresh();
    } except Exception as exc {
        error = str(exc);
    }
    busy = False;
}

impl app.toggleTask(task_id: str, done: bool) -> None {
    if busy { return; }
    busy = True;
    try {
        await set_done(task_id=task_id, done=not done);
        await refresh();
    } except Exception as exc {
        error = str(exc);
    }
    busy = False;
}

impl app.removeTask(task_id: str) -> None {
    if busy { return; }
    busy = True;
    try {
        await delete_task(task_id=task_id);
        await refresh();
    } except Exception as exc {
        error = str(exc);
    }
    busy = False;
}
