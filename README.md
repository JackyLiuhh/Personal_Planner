
# Pace

Pace is a personal task planner written in Jac. Its four apps use the same planning logic and project data:

| Component | What it does |
| --- | --- |
| Server | Validates tasks and saves them in `.jac/data/planner.sqlite3` |
| Web | Add dated or undated tasks, review Today/All/Completed, complete, reopen, and delete |
| Mobile | Review Today or All, quickly add a task, complete or reopen, and refresh |
| CLI | Add, list, view today, complete, reopen, and delete tasks |

Tasks have a title, optional `YYYY-MM-DD` due date, priority (`low`, `medium`, or `high`), and completion state. Today includes open tasks due today or earlier and undated inbox tasks.

## Run

From this folder, check that `jac --version` shows 0.37.23. If your shell says `jac: command not found`, run `export PATH="$HOME/.local/bin:$PATH"` first. Then run:

```sh
jac install
jac run --dev planner
```

Open the **App** URL printed by Jac. The **API** URL is for the CLI and mobile bridge. Jac may choose different ports if its usual ports are occupied.

In another terminal, point the CLI at the server app route. Replace `8002` with the port in the printed **API** URL:

```sh
export JAC_APP_SERVER_URL="http://127.0.0.1:8002/api/server"
jac run cli -- add "Review lecture notes" --due 2026-10-01 --priority high
jac run cli -- today
jac run cli -- list
jac run cli -- done TASK_ID
```

`TASK_ID` can be a unique starting part of an ID shown by `list`.

For a mobile browser preview, stop the web preview and run:

```sh
jac run --dev --platform web mobile
```

For an Android or iOS device/simulator, run `jac run --dev mobile`. Jac sets up Expo on first use. See [mobile/README.md](mobile/README.md) for platform prerequisites. The mobile preview starts its own local API process, but it uses the same Jac server module and SQLite file, so saved tasks remain in sync.

## Verify

```sh
jac check --nowarn
jac test server/main.test.jac
jac build --as client planner
jac build --platform web mobile
```

The server's tests use temporary databases and leave your plan untouched. This example exposes task functions publicly for local use. Add authentication before deploying it to other users.

## Jac 0.37.23 on this Mac

The installed Jac binary's bundled Python fails while creating a project virtual environment. This workspace already has a working environment in `.jac/venv`. If you remove that venv, recreate it with the existing project Python before running `jac install`:

```sh
./.jac/python314/bin/python -m venv .jac/venv
jac install
```

If `.jac/python314` is also missing, create it first with `conda create -p .jac/python314 python=3.14 -y`.

The `.jac/` directory contains dependencies and planning data and is ignored by Git. Keep it if you want your saved tasks and local runtime to remain available.

