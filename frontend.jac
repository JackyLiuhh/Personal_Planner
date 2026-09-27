"""Browser interface for the personal planner."""

import from server.main { TaskView, add_task, list_tasks, today_plan, set_done, delete_task }

def:pub app -> JsxElement {
    has tasks: list[TaskView] = [],
        today_tasks: list[TaskView] = [],
        title: str = "",
        due_date: str = "",
        priority: str = "medium",
        view: str = "today",
        busy: bool = False,
        loaded: bool = False,
        error: str = "";

    async can with entry {
        await refresh();
    }

    async def refresh -> None;
    async def submitTask(e: FormEvent) -> None;
    async def toggleTask(task_id: str, done: bool) -> None;
    async def removeTask(task_id: str) -> None;

    open_count = len([task for task in tasks if not task.done]);
    done_count = len(tasks) - open_count;
    shown: list[TaskView] = (
        today_tasks if view == "today" else
        [task for task in tasks if task.done] if view == "completed" else tasks
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
                    <p className="hero-copy">Capture the next step, give it a date, and keep your day in view.</p>
                    <div className="stats">
                        <div className="stat"><strong>{str(len(today_tasks))}</strong><span>in your plan</span></div>
                        <div className="stat"><strong>{str(open_count)}</strong><span>open tasks</span></div>
                        <div className="stat"><strong>{str(done_count)}</strong><span>completed</span></div>
                    </div>
                </section>

                <section className="list-card">
                    <div className="list-head">
                        <div>
                            <p className="eyebrow">YOUR TASKS</p>
                            <h2>{"Today" if view == "today" else "Completed" if view == "completed" else "All tasks"}</h2>
                        </div>
                        <button type="button" className="refresh-button" onClick={refresh} disabled={busy}>Refresh</button>
                    </div>

                    <nav className="tabs" aria-label="Task views">
                        <button type="button" data-active={view == "today"} onClick={lambda { view = "today"; }}>Today</button>
                        <button type="button" data-active={view == "all"} onClick={lambda { view = "all"; }}>All tasks</button>
                        <button type="button" data-active={view == "completed"} onClick={lambda { view = "completed"; }}>Completed</button>
                    </nav>

                    {(
                        <div className="empty-state">
                            <div className="empty-icon">✓</div>
                            <h3>{"Loading your plan…" if not loaded else "Nothing here yet"}</h3>
                            <p>{"Your tasks will appear here shortly." if not loaded else "Add a task to get started, or switch to another view."}</p>
                        </div>
                    ) if not shown else (
                        <div className="task-list">
                            {[
                                <article className="task-row" key={task.id} data-done={task.done}>
                                    <button
                                        type="button"
                                        className="check-button"
                                        aria-label={"Reopen " + task.title if task.done else "Complete " + task.title}
                                        onClick={lambda { toggleTask(task.id, task.done); }}
                                        disabled={busy}
                                    >{"✓" if task.done else ""}</button>
                                    <div className="task-main">
                                        <div className="task-title">{task.title}</div>
                                        <div className="task-meta">
                                            <span className="priority" data-priority={task.priority}>{task.priority}</span>
                                            <span>{"No date · Inbox" if not task.due_date else "Due " + task.due_date}</span>
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        className="delete-button"
                                        aria-label={"Delete " + task.title}
                                        title="Delete task"
                                        onClick={lambda { removeTask(task.id); }}
                                        disabled={busy}
                                    >×</button>
                                </article>
                                for task in shown
                            ]}
                        </div>
                    )}
                </section>
            </div>

            <aside className="side-column">
                <section className="form-card">
                    <div className="form-icon">＋</div>
                    <p className="eyebrow">CLEAR YOUR MIND</p>
                    <h2>Add a task</h2>
                    <p className="form-intro">Start with one concrete action. Leave the date open to keep it in your Today inbox.</p>
                    <form onSubmit={submitTask}>
                        <label htmlFor="task-title">Task</label>
                        <input
                            id="task-title"
                            type="text"
                            maxLength={160}
                            placeholder="e.g. Review lecture notes"
                            value={title}
                            onChange={lambda (e: ChangeEvent) { title = e.target.value; }}
                            required={True}
                        />
                        <div className="form-pair">
                            <div>
                                <label htmlFor="task-date">Due date</label>
                                <input
                                    id="task-date"
                                    type="date"
                                    value={due_date}
                                    onChange={lambda (e: ChangeEvent) { due_date = e.target.value; }}
                                />
                            </div>
                            <div>
                                <label htmlFor="task-priority">Priority</label>
                                <select id="task-priority" value={priority} onChange={lambda (e: ChangeEvent) { priority = e.target.value; }}>
                                    <option value="high">High</option>
                                    <option value="medium">Medium</option>
                                    <option value="low">Low</option>
                                </select>
                            </div>
                        </div>
                        <button type="submit" className="submit-button" disabled={busy or not title.strip()}>
                            {"Adding…" if busy else "Add to plan"}
                        </button>
                    </form>
                </section>
                {(
                    <div className="error-card" role="alert">
                        <strong>Could not update your plan</strong>
                        <p>{error}</p>
                        <button type="button" onClick={refresh}>Try again</button>
                    </div>
                ) if error else None}
                <div className="tip-card">
                    <span className="tip-spark">✦</span>
                    <p><strong>Keep it doable.</strong> Today includes tasks due now or earlier, plus undated tasks in your inbox.</p>
                </div>
            </aside>
        </main>
    </div>
}
