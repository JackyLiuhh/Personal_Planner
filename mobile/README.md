# Pace mobile app

The Jac mobile app uses `@jac/mobui` native views and calls public functions in
`server.main`. Tasks created or completed on mobile are the same persistent tasks
shown by the web app and CLI.

The mobile screen supports:

- Today's open and overdue tasks, including undated tasks
- An all tasks view where completed tasks can be reopened
- Quick task entry with optional `YYYY-MM-DD` due date and priority
- Complete, reopen, and refresh actions with loading and connection errors

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
