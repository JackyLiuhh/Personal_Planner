"""Mobile planner backed by the shared Jac planning service."""

import from "@jac/mobui" { View, StatusBar }
import from "@jac/runtime" { BridgeError }
import from server.main {
    TaskView,
    add_task,
    list_tasks,
    day_plan,
    deadline_reminders,
    set_done
}
import from .theme { C, styles }
import from .screens.Home { HomeScreen }

def localDate(value: any) -> str {
    return str(value.getFullYear()).zfill(4) + "-" +
        str(value.getMonth() + 1).zfill(2) + "-" + str(value.getDate()).zfill(2);
}

def todayDate -> str {
    return localDate(new(Date));
}

def validDate(value: str) -> bool {
    if len(value) != 10 {
        return False;
    }
    parsed = new(Date, value + "T12:00:00");
    return localDate(parsed) == value;
}

def:pub app -> JsxElement {
    has tasks: list[TaskView] = [],
        reminders: list[TaskView] = [],
        itemType: str = "task",
        view: str = "day",
        selectedDay: str = todayDate(),
        dayInput: str = todayDate(),
        draft: str = "",
        dueDate: str = todayDate(),
        priority: str = "medium",
        startTime: str = "",
        duration: str = "",
        recurrence: str = "none",
        loading: bool = True,
        working: bool = False,
        error: str = "",
        requestRef: Ref[int] = Ref(0),
        viewRef: Ref[str] = Ref("day"),
        dayRef: Ref[str] = Ref(todayDate()),
        workingRef: Ref[bool] = Ref(False);

    async def refresh {
        nextRequest = (requestRef.current or 0) + 1;
        requestRef.current = nextRequest;
        requestedDay = dayRef.current or todayDate();
        requestedView = viewRef.current or "day";
        loading = True;
        tasks = [];
        error = "";
        try {
            result = await day_plan(requestedDay) if requestedView == "day"
                else await list_tasks(requestedDay);
            freshReminders = await deadline_reminders();
            if requestRef.current == nextRequest {
                tasks = result;
                reminders = freshReminders;
            }
        } except BridgeError as e {
            if requestRef.current == nextRequest {
                error = f"Could not load your plan. {str(e)}";
            }
        } except Exception {
            if requestRef.current == nextRequest {
                error = "Could not load your plan. Please try again.";
            }
        }
        if requestRef.current == nextRequest {
            loading = False;
        }
    }

    async can with entry {
        await refresh();
    }

    async def chooseView(nextView: str) {
        if view != nextView {
            view = nextView;
            viewRef.current = nextView;
            await refresh();
        }
    }

    async def chooseDay(value: str) -> None {
        clean = value.strip();
        if not validDate(clean) {
            error = "Enter a valid day as YYYY-MM-DD.";
            return;
        }
        previousDay = dayRef.current or selectedDay;
        if dueDate == previousDay {
            dueDate = clean;
        }
        selectedDay = clean;
        dayInput = clean;
        dayRef.current = clean;
        await refresh();
    }

    async def shiftDay(offset: int) -> None {
        date = new(Date, (dayRef.current or todayDate()) + "T12:00:00");
        date.setDate(date.getDate() + offset);
        await chooseDay(localDate(date));
    }

    async def addTask -> None {
        if workingRef.current or not draft.strip() {
            return;
        }
        minutes = 0;
        if duration.strip() and itemType == "task" {
            if not duration.strip().isdigit() {
                error = "Expected duration must be a whole number of minutes.";
                return;
            }
            minutes = int(duration.strip());
            if minutes < 1 or minutes > 1440 {
                error = "Expected duration must be between 1 and 1440 minutes.";
                return;
            }
        }
        if (itemType == "deadline" or recurrence != "none" or startTime.strip()) and not dueDate.strip() {
            error = "Choose a date for a start time or a recurring task.";
            return;
        }
        workingRef.current = True;
        working = True;
        error = "";
        submittedDay = dayRef.current;
        try {
            created = await add_task(draft.strip(), dueDate.strip(), priority,
                startTime.strip() if itemType == "task" else "", minutes,
                recurrence if itemType == "task" else "none", itemType,
                startTime.strip() if itemType == "deadline" else "");
            draft = "";
            dueDate = dayRef.current or todayDate();
            priority = "medium";
            startTime = "";
            duration = "";
            recurrence = "none";
            createdDay = created.occurrence_date or created.due_date;
            if createdDay and dayRef.current == submittedDay {
                await chooseDay(createdDay);
            } else {
                await refresh();
            }
        } except BridgeError as e {
            error = f"Could not add the task. {str(e)}";
        } except Exception {
            error = "Could not add the task. Check the date and 24-hour time, then try again.";
        }
        workingRef.current = False;
        working = False;
    }

    async def toggleTask(taskId: str, done: bool, occurrenceDate: str) -> None {
        if workingRef.current {
            return;
        }
        workingRef.current = True;
        working = True;
        error = "";
        try {
            await set_done(taskId, not done, occurrenceDate);
            await refresh();
        } except BridgeError as e {
            error = f"Could not update the task. {str(e)}";
        } except Exception {
            error = "Could not update the task. Please try again.";
        }
        workingRef.current = False;
        working = False;
    }

    <View style={styles.screen}>
        <StatusBar barStyle="light-content" backgroundColor={C.bg}/>
        <HomeScreen
            tasks={tasks}
            reminders={reminders}
            itemType={itemType}
            onItemType={lambda (value: str) { itemType = value; }}
            view={view}
            selectedDay={selectedDay}
            dayInput={dayInput}
            draft={draft}
            dueDate={dueDate}
            priority={priority}
            startTime={startTime}
            duration={duration}
            recurrence={recurrence}
            loading={loading}
            working={working}
            error={error}
            onView={chooseView}
            onDayInput={lambda (value: str) { dayInput = value; }}
            onApplyDay={lambda { chooseDay(dayInput); }}
            onPreviousDay={lambda { shiftDay(-1); }}
            onNextDay={lambda { shiftDay(1); }}
            onToday={lambda { chooseDay(todayDate()); }}
            onDraft={lambda (value: str) { draft = value; }}
            onDueDate={lambda (value: str) { dueDate = value; }}
            onPriority={lambda (value: str) { priority = value; }}
            onStartTime={lambda (value: str) { startTime = value; }}
            onDuration={lambda (value: str) { duration = value; }}
            onRecurrence={lambda (value: str) { recurrence = value; }}
            onAdd={addTask}
            onToggle={toggleTask}
            onRefresh={refresh}
        />
    </View>
}
