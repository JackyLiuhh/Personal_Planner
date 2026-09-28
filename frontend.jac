"""Browser agenda with recurring occurrences, times, and daily estimates."""

import from server.main { TaskView, add_task, list_tasks, day_plan, set_done, delete_task }

def:pub app -> JsxElement {
    has tasks: list[TaskView] = [], day_tasks: list[TaskView] = [],
        selected_date: str = "", title: str = "", due_date: str = "",
        start_time: str = "", duration: str = "", recurrence: str = "none",
        priority: str = "medium", view: str = "day", busy: bool = False,
        loading: bool = True, requestRef: Ref[int] = Ref(0), error: str = "";

    def dateString(value: any) -> str {
        month = value.getMonth() + 1;
        day = value.getDate();
        return str(value.getFullYear()) + "-" + ("0" if month < 10 else "") + str(month)
            + "-" + ("0" if day < 10 else "") + str(day);
    }
    def currentDay -> str { return dateString(new(Date)); }
    def shiftDay(offset: int) -> str {
        value = new(Date, selected_date + "T12:00:00");
        value.setDate(value.getDate() + offset);
        return dateString(value);
    }
    def dayLabel -> str {
        if not selected_date { return "Your day"; }
        return new(Date, selected_date + "T12:00:00").toLocaleDateString(
            "en-US", {"weekday": "long", "month": "short", "day": "numeric"}
        );
    }
    def repeatLabel(value: str) -> str {
        if value == "weekdays" { return "Weekdays"; }
        if value == "daily" { return "Daily"; }
        if value == "weekly" { return "Weekly"; }
        if value == "monthly" { return "Monthly"; }
        return "Does not repeat";
    }
    def endTime(task: TaskView) -> str {
        if not task.start_time or not task.duration_minutes { return ""; }
        parts = task.start_time.split(":");
        total = int(parts[0]) * 60 + int(parts[1]) + task.duration_minutes;
        hour = (total // 60) % 24;
        minute = total % 60;
        return ("0" if hour < 10 else "") + str(hour) + ":"
            + ("0" if minute < 10 else "") + str(minute)
            + (" +1 day" if total >= 1440 else "");
    }

    async can with entry {
        selected_date = currentDay();
        due_date = selected_date;
        await refresh();
    }
    async def refresh -> None;
    async def chooseDay(value: str) -> None;
    async def submitTask(e: FormEvent) -> None;
    async def toggleTask(task_id: str, done: bool, occurrence_date: str) -> None;
    async def removeTask(task_id: str, repeating: bool) -> None;

    scheduled = [task for task in day_tasks if task.occurrence_date == selected_date];
    planned_minutes = sum([task.duration_minutes for task in scheduled]);
    remaining_minutes = sum([task.duration_minutes for task in scheduled if not task.done]);
    done_count = len([task for task in scheduled if task.done]);
    shown: list[TaskView] = (
        [task for task in day_tasks if task.done] if view == "completed" else
        tasks if view == "all" else day_tasks
    );

    <div className="app-shell">
        <header className="topbar">
            <div className="brand"><span className="brand-mark">P</span><span>pace</span></div>
            <span className="topbar-note">A little clarity for each day</span>
        </header>
        <main className="main-grid">
            <div className="content-column">
                <section className="hero">
                    <p className="eyebrow">PERSONAL PLANNER</p>
                    <h1>Make room for what matters.</h1>
                    <p className="hero-copy">Give your tasks a time, build a routine, and see how your day adds up.</p>
                    <div className="stats" aria-label="Selected day summary">
                        <div className="stat"><strong>{str(len(scheduled))}</strong><span>scheduled tasks</span></div>
                        <div className="stat"><strong>{str(planned_minutes)}<small> min</small></strong><span>expected time</span></div>
                        <div className="stat"><strong>{str(done_count)}</strong><span>completed</span></div>
                    </div>
                </section>
                <section className="list-card">
                    <div className="list-head">
                        <div><p className="eyebrow">YOUR DAILY BREAKDOWN</p><h2>{dayLabel()}</h2></div>
                        <button type="button" className="refresh-button" onClick={refresh} disabled={busy or loading}>Refresh</button>
                    </div>
                    <div className="day-nav">
                        <button type="button" aria-label="Previous day" onClick={lambda { chooseDay(shiftDay(-1)); }} disabled={busy}>‹</button>
                        <input id="plan-date" type="date" aria-label="Plan date" value={selected_date}
                            onChange={lambda (e: ChangeEvent) { chooseDay(e.target.value); }} disabled={busy}/>
                        <button type="button" aria-label="Next day" onClick={lambda { chooseDay(shiftDay(1)); }} disabled={busy}>›</button>
                        <button type="button" className="today-button" onClick={lambda { chooseDay(currentDay()); }} disabled={busy}>Today</button>
                    </div>
                    <nav className="tabs" aria-label="Task views">
                        <button type="button" data-active={view == "day"} onClick={lambda { view = "day"; }}>Day plan</button>
                        <button type="button" data-active={view == "all"} onClick={lambda { view = "all"; }}>All tasks</button>
                        <button type="button" data-active={view == "completed"} onClick={lambda { view = "completed"; }}>Completed</button>
                    </nav>
                    <p className="agenda-caption">{
                        "Repeating tasks show their next occurrence on or after this date." if view == "all" else
                        "Completed on this day, plus completed inbox tasks." if view == "completed" else
                        str(remaining_minutes) + " min remaining · Undated tasks stay in your inbox."
                    }</p>
                    {(<div className="empty-state" aria-live="polite">
                        <div className="empty-icon">✓</div>
                        <h3>{"Loading your plan…" if loading else "Room in your day"}</h3>
                        <p>{"Your tasks will appear here shortly." if loading else "Add a task for this date, or choose another day."}</p>
                    </div>) if loading or not shown else (
                        <div className="task-list">{[
                            <article className="task-row" key={task.id + task.occurrence_date} data-done={task.done}>
                                <div className="task-time">
                                    <strong>{task.start_time if task.start_time else "Flexible" if task.occurrence_date else "Inbox"}</strong>
                                    {(<span>{endTime(task)}</span>) if task.start_time and task.duration_minutes else None}
                                </div>
                                <button type="button" className="check-button"
                                    aria-label={"Reopen " + task.title if task.done else "Complete " + task.title}
                                    onClick={lambda { toggleTask(task.id, task.done, task.occurrence_date); }}
                                    disabled={busy or loading}>{"✓" if task.done else ""}</button>
                                <div className="task-main">
                                    <div className="task-title">{task.title}</div>
                                    <div className="task-meta">
                                        <span className="priority" data-priority={task.priority}>{task.priority}</span>
                                        {(<span>{str(task.duration_minutes) + " min"}</span>) if task.duration_minutes else None}
                                        {(<span className="repeat-badge">{"↻ " + repeatLabel(task.recurrence)}</span>) if task.recurrence != "none" else None}
                                        {(<span>{task.occurrence_date}</span>) if view == "all" and task.occurrence_date else None}
                                    </div>
                                </div>
                                <button type="button" className="delete-button"
                                    aria-label={("Delete series " if task.recurrence != "none" else "Delete ") + task.title}
                                    title={"Delete recurring series" if task.recurrence != "none" else "Delete task"}
                                    onClick={lambda { removeTask(task.id, task.recurrence != "none"); }} disabled={busy}>×</button>
                            </article> for task in shown
                        ]}</div>
                    )}
                </section>
            </div>
            <aside className="side-column">
                <section className="form-card">
                    <div className="form-icon">＋</div><p className="eyebrow">CLEAR YOUR MIND</p><h2>Add a task</h2>
                    <p className="form-intro">Plan one action or start a routine. Add an estimate to see the time you need.</p>
                    <form onSubmit={submitTask}>
                        <label htmlFor="task-title">Task</label>
                        <input id="task-title" type="text" maxLength={160} placeholder="e.g. Review lecture notes"
                            value={title} onChange={lambda (e: ChangeEvent) { title = e.target.value; }} required={True}/>
                        <div className="form-pair">
                            <div><label htmlFor="task-date">{"First date" if recurrence != "none" else "Date"}</label>
                                <input id="task-date" type="date" value={due_date} required={recurrence != "none" or bool(start_time)}
                                    onChange={lambda (e: ChangeEvent) { due_date = e.target.value; }}/></div>
                            <div><label htmlFor="task-priority">Priority</label>
                                <select id="task-priority" value={priority} onChange={lambda (e: ChangeEvent) { priority = e.target.value; }}>
                                    <option value="high">High</option><option value="medium">Medium</option><option value="low">Low</option>
                                </select></div>
                        </div>
                        <div className="form-pair">
                            <div><label htmlFor="task-time">Start time</label>
                                <input id="task-time" type="time" value={start_time}
                                    onChange={lambda (e: ChangeEvent) { start_time = e.target.value; }}/></div>
                            <div><label htmlFor="task-duration">Expected minutes</label>
                                <input id="task-duration" type="number" min="1" max="1440" step="1" placeholder="e.g. 45"
                                    value={duration} onChange={lambda (e: ChangeEvent) { duration = e.target.value; }}/></div>
                        </div>
                        <label htmlFor="task-repeat">Repeat</label>
                        <select id="task-repeat" value={recurrence} onChange={lambda (e: ChangeEvent) { recurrence = e.target.value; }}>
                            <option value="none">Does not repeat</option><option value="daily">Every day</option>
                            <option value="weekdays">Weekdays (Mon–Fri)</option><option value="weekly">Every week</option><option value="monthly">Every month</option>
                        </select>
                        <p className="form-help">{"Each date has its own completion status. Monthly repeats use the last day when needed." if recurrence != "none" else "Time and estimate are optional. Clear the date to keep a task in your inbox."}</p>
                        <button type="submit" className="submit-button" disabled={busy or not title.strip()}>{"Saving…" if busy else "Add to plan"}</button>
                    </form>
                </section>
                {(<div className="error-card" role="alert"><strong>Could not update your plan</strong><p>{error}</p>
                    <button type="button" onClick={refresh}>Try again</button></div>) if error else None}
                <div className="tip-card"><span className="tip-spark">✦</span>
                    <p><strong>Make time visible.</strong> Start times use your local clock. Estimates count toward the day a task starts; you can schedule overlapping tasks.</p>
                </div>
            </aside>
        </main>
    </div>
}
