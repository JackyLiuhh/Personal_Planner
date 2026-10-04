# GoPlanner
Student: Zhanhao Liu / zhanhaol

UMID: 13899561

Course: EECS 449 / CSE449-F26 — Assignment 1

GoPlanner is a personal planner built with **Jac**, with a web interface, a mobile app, and a command-line interface backed by the same planning service and SQLite database. Organize one-time tasks, build recurring routines, estimate your daily workload, and keep deadlines and goals in sight.

## Included features

- **Tasks and priorities:** Create tasks with a title, an optional date, and low, medium, or high priority. Leave a task undated to keep it in your inbox. Complete and reopen tasks; delete tasks or entire recurring series through the web app or CLI.
- **Daily planning:** Browse previous/next days, choose a specific date, or jump to Today. The day plan includes tasks scheduled for that date and undated inbox items, with timed tasks shown first. Completed items remain available to reopen.
- **Time estimates:** Add an optional 24-hour start time and expected duration of 1–1440 minutes. Web and mobile show calculated time ranges, including ranges that cross midnight, and planned/remaining minutes. Daily totals exclude undated inbox estimates.
- **Recurring routines:** Repeat tasks daily, on weekdays, weekly, or monthly. Complete or reopen each occurrence independently without changing future occurrences. Monthly schedules use the last day of a shorter month when necessary.
- **Deadlines and goals:** Track a required due date and optional due time separately from scheduled work. Open reminders appear across all dates, earliest due first; web and mobile label them Upcoming, Due today, or Overdue. They stay in reminders until completed and do not add to planned minutes.
- **Task views:** Web offers Day plan, All tasks, and Completed views; mobile offers Day plan and All tasks. All tasks shows each recurring series' next occurrence on or after the selected date. The web Completed view shows completed items for the selected day plus completed inbox tasks.
- **CLI workflows:** Add tasks and deadlines, list by completion status, inspect a day's plan or today's open backlog, review reminders, complete/reopen occurrences, and delete tasks. Commands accept full task IDs or unique ID prefixes.
- **Persistent data and validation:** Tasks and occurrence completions survive restarts. The server validates titles, dates, times, priorities, durations, and recurrence rules, and migrates older task schemas automatically. Web and mobile include refresh, loading, and error states, and ignore stale responses when switching days.

Times use the local 24-hour clock (`HH:MM`, including `24:00` for end of day). A start time or repeat schedule requires a task date. Deadlines use a due time and do not have a duration or repeat schedule. Reminders are displayed inside the app.

## Project structure

| Component | Files | Role |
| --- | --- | --- |
| Web | `main.jac`, `frontend.jac`, `frontend.impl.jac`, `styles.css` | Browser agenda, task entry, time summaries, and reminders |
| Mobile | `mobile/` | Native mobile interface and mobile browser preview |
| CLI | `cli/main.jac` | Terminal commands that call the planning service |
| Server | `server/main.jac` | Shared validation, recurrence, completion tracking, and SQLite storage |
| Tests | `server/main.test.jac` | Server behavior, persistence, migration, and input validation |

By default, data is stored in `.jac/data/planner.sqlite3`. Set `PLANNER_DB_PATH` on the server to use a different database file. Apps running from this project share the same database; refresh a view to load changes made through another interface.

## Getting started

Run these commands from the `planner/` directory using **Jac 0.37.23** (the version pinned in `jac.toml`):

```sh
jac --version
jac install
jac run --dev planner
```

Open the **App** URL printed by Jac. The **API** URL is used by the CLI and mobile bridge. Ports may vary if the usual ones are occupied.

If your shell cannot find Jac, add its local installation to your path:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### Command-line usage

Keep the web/server process running. In another terminal, set the server route using the printed **API** URL; replace `8002` below with its port:

```sh
export JAC_APP_SERVER_URL="http://127.0.0.1:8002/api/server"

# Add a scheduled task, a recurring routine, and a deadline.
jac run cli -- add "Review lecture notes" --due 2026-10-05 --time 09:00 --duration 45 --priority high
jac run cli -- add "Daily reading" --due 2026-10-05 --duration 30 --repeat daily
jac run cli -- add "Submit project" --deadline --due 2026-10-09 --time 17:00

# Review your plan and reminders.
jac run cli -- day 2026-10-05
jac run cli -- today
jac run cli -- list --status open --date 2026-10-05
jac run cli -- reminders

# Use an ID (or unique prefix) shown by list.
jac run cli -- done TASK_ID
jac run cli -- reopen TASK_ID
jac run cli -- done RECURRING_TASK_ID --date 2026-10-05
jac run cli -- delete TASK_ID
```

`day` shows the selected date's tasks, including completed items and the undated inbox. `today` shows open tasks due today or earlier plus open inbox tasks; its backlog total includes inbox estimates. For recurring tasks, pass `--date` to complete or reopen a specific occurrence; otherwise the next occurrence on or after today is used. `delete` removes the entire recurring series.

### Mobile app

For a mobile browser preview, stop the web preview and run:

```sh
jac run --dev --platform web mobile
```

For an Android or iOS device/simulator:

```sh
jac run --dev mobile
```

Jac sets up Expo on first native use. Android requires JDK 21 and the Android SDK; iOS requires Xcode on macOS. See [mobile/README.md](mobile/README.md) for mobile details. Run one preview at a time. The mobile preview starts its own local API process using the same server module and database.

## Validation

```sh
jac check --nowarn
jac test server/main.test.jac
jac build --as client planner
jac build --platform web mobile
```

Server tests use temporary databases and leave saved planning data untouched. They cover task lifecycle, shared persistence, invalid input, time boundaries, schema migration, recurrence (including month ends and leap years), independent occurrence completion, and deadline reminders.

The current service exposes task functions publicly for local use. Add authentication before deploying it for other users.

## Local environment troubleshooting

The installed Jac binary's bundled Python fails while creating a project virtual environment. This workspace already has a working environment in `.jac/venv`. If you remove that venv, recreate it with the existing project Python before running `jac install`:

```sh
./.jac/python314/bin/python -m venv .jac/venv
jac install
```

If `.jac/python314` is also missing, create it first with `conda create -p .jac/python314 python=3.14 -y`.

The `.jac/` directory contains dependencies and planning data and is ignored by Git. Keep it if you want your saved tasks and local runtime to remain available.

