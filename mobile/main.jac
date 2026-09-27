"""Mobile planner backed by the shared Jac planning service."""

import from "@jac/mobui" { View, StatusBar }
import from "@jac/runtime" { BridgeError }
import from server.main {
    TaskView,
    add_task,
    list_tasks,
    today_plan,
    set_done
}
import from .theme { C, styles }
import from .screens.Home { HomeScreen }

def:pub app -> JsxElement {
    has tasks: list[TaskView] = [],
        view: str = "today",
        draft: str = "",
        dueDate: str = "",
        priority: str = "medium",
        loading: bool = True,
        working: bool = False,
        error: str = "";

    async def refresh {
        loading = True;
        error = "";
        try {
            tasks = await today_plan() if view == "today" else await list_tasks();
        } except BridgeError as e {
            error = f"Could not load your plan. {str(e)}";
        } except Exception {
            error = "Could not load your plan. Please try again.";
        }
        loading = False;
    }

    async can with entry {
        await refresh();
    }

    async def chooseView(nextView: str) {
        if view != nextView {
            view = nextView;
            await refresh();
        }
    }

    async def addTask -> None {
        if working or not draft.strip() {
            return;
        }
        working = True;
        error = "";
        try {
            await add_task(draft.strip(), dueDate.strip(), priority);
            draft = "";
            dueDate = "";
            priority = "medium";
            await refresh();
        } except BridgeError as e {
            error = f"Could not add the task. {str(e)}";
        } except Exception {
            error = "Could not add the task. Check the date and try again.";
        }
        working = False;
    }

    async def toggleTask(taskId: str, done: bool) -> None {
        if working {
            return;
        }
        working = True;
        error = "";
        try {
            await set_done(taskId, not done);
            await refresh();
        } except BridgeError as e {
            error = f"Could not update the task. {str(e)}";
        } except Exception {
            error = "Could not update the task. Please try again.";
        }
        working = False;
    }

    <View style={styles.screen}>
        <StatusBar barStyle="light-content" backgroundColor={C.bg}/>
        <HomeScreen
            tasks={tasks}
            view={view}
            draft={draft}
            dueDate={dueDate}
            priority={priority}
            loading={loading}
            working={working}
            error={error}
            onView={chooseView}
            onDraft={lambda (value: str) { draft = value; }}
            onDueDate={lambda (value: str) { dueDate = value; }}
            onPriority={lambda (value: str) { priority = value; }}
            onAdd={addTask}
            onToggle={toggleTask}
            onRefresh={refresh}
        />
    </View>
}
