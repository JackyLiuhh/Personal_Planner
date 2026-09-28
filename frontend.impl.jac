"""Planner browser actions, with request ordering when changing days."""

impl app.refresh -> None {
    current_request = (requestRef.current or 0) + 1;
    requestRef.current = current_request;
    requested_date = selected_date;
    loading = True;
    try {
        fresh_tasks = await list_tasks(plan_date=requested_date);
        fresh_day_tasks = await day_plan(plan_date=requested_date);
        if current_request == requestRef.current {
            tasks = fresh_tasks;
            day_tasks = fresh_day_tasks;
            error = "";
        }
    } except Exception as exc {
        if current_request == requestRef.current { error = str(exc); }
    } finally {
        if current_request == requestRef.current { loading = False; }
    }
}

impl app.chooseDay(value: str) -> None {
    if not value or busy { return; }
    if due_date == selected_date { due_date = value; }
    selected_date = value;
    view = "day";
    day_tasks = [];
    await refresh();
}

impl app.submitTask(e: FormEvent) -> None {
    e.preventDefault();
    if not title.strip() or busy { return; }
    busy = True;
    try {
        created = await add_task(title=title.strip(), due_date=due_date, priority=priority,
            start_time=start_time, duration_minutes=duration if duration else 0, recurrence=recurrence);
        selected_date = created.occurrence_date if created.occurrence_date else selected_date;
        title = "";
        due_date = selected_date;
        start_time = "";
        duration = "";
        priority = "medium";
        recurrence = "none";
        view = "day";
        await refresh();
    } except Exception as exc {
        error = str(exc);
    } finally { busy = False; }
}

impl app.toggleTask(task_id: str, done: bool, occurrence_date: str) -> None {
    if busy or loading { return; }
    busy = True;
    try {
        await set_done(task_id=task_id, done=not done, occurrence_date=occurrence_date);
        await refresh();
    } except Exception as exc {
        error = str(exc);
    } finally { busy = False; }
}

impl app.removeTask(task_id: str, repeating: bool) -> None {
    if busy { return; }
    if repeating and not window.confirm("Delete this recurring task and all of its occurrences?") { return; }
    busy = True;
    try {
        await delete_task(task_id=task_id);
        await refresh();
    } except Exception as exc {
        error = str(exc);
    } finally { busy = False; }
}
