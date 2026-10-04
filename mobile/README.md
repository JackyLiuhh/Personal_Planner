# GoPlanner mobile app

The Jac mobile app uses `@jac/mobui` native views and calls public functions in
`server.main`. Tasks created or completed on mobile are the same persistent tasks
shown by the web app and CLI.

The mobile screen supports:

- A daily breakdown with previous/next day buttons, a `YYYY-MM-DD` date field,
  and a Today shortcut. Dated tasks appear on their scheduled day; undated inbox
  tasks stay visible. Completed occurrences remain visible so they can be reopened.
- Task entry with an optional `HH:MM` start time, expected duration in minutes,
  and priority. Start times use the local 24-hour clock. A start time needs a date;
  durations may be 1–1440 minutes, or left blank.
- Recurrence choices: daily, weekdays, weekly, and monthly. The task date anchors
  the series, and completing an occurrence leaves future occurrences open.
  Monthly tasks fall on the last day of shorter months when needed.
- Time ranges and total planned/remaining minutes. Day totals exclude undated
  inbox estimates; All tasks totals include every displayed task.
- An All tasks view with each recurring task's next occurrence on or after the
  selected date, plus complete, reopen, and refresh actions.
- Deadlines and goals with a required due date and optional due time. Open reminders
  stay visible across dates, ordered by due date/time, with Upcoming, Due today,
  and Overdue labels. Complete a deadline directly from its reminder.
- Loading and connection errors, with stale responses ignored when switching days.

## Run

From the `planner/` directory, use Jac 0.37.23:

```sh
jac install
jac run --dev planner                    # browser interface
jac run --dev --platform web mobile       # mobile screen in a browser
```

Run one preview at a time. Both use the same planning data stored in this project.
For a device or simulator, use
`jac run --dev mobile` instead of the browser preview; Jac provisions Expo on the
first native run. Android needs JDK 21 and Android SDK. iOS needs Xcode on macOS.

Validate the mobile app with `jac check --app mobile`. A native production build
uses `jac build --platform android mobile` or `jac build --platform ios mobile`.
