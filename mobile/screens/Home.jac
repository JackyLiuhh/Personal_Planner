"""Daily schedule and recurring task entry for the native planner."""

import from "@jac/mobui" {
    View,
    Text,
    TextInput,
    Pressable,
    ScrollView,
    ActivityIndicator
}
import from server.main { TaskView }
import from ..theme { C, styles }
import from ..components.Button { Button }

def repeatLabel(value: str) -> str {
    if value == "none" { return "Does not repeat"; }
    if value == "weekdays" { return "Weekdays"; }
    if value == "daily" { return "Daily"; }
    if value == "weekly" { return "Weekly"; }
    return "Monthly";
}

def timeLabel(task: TaskView) -> str {
    if not task.start_time { return "Any time"; }
    if not task.duration_minutes { return task.start_time; }
    parts = task.start_time.split(":");
    endMinutes = int(parts[0]) * 60 + int(parts[1]) + task.duration_minutes;
    endHour = (endMinutes // 60) % 24;
    endMinute = endMinutes % 60;
    return task.start_time + "–" + str(endHour).zfill(2) + ":" +
        str(endMinute).zfill(2) + (" (+1 day)" if endMinutes >= 1440 else "");
}

def:pub HomeScreen(
    tasks: list[TaskView],
    view: str,
    selectedDay: str,
    dayInput: str,
    draft: str,
    dueDate: str,
    priority: str,
    startTime: str,
    duration: str,
    recurrence: str,
    loading: bool,
    working: bool,
    error: str,
    onView: Callable[[str], None],
    onDayInput: Callable[[str], None],
    onApplyDay: Callable[[], None],
    onPreviousDay: Callable[[], None],
    onNextDay: Callable[[], None],
    onToday: Callable[[], None],
    onDraft: Callable[[str], None],
    onDueDate: Callable[[str], None],
    onPriority: Callable[[str], None],
    onStartTime: Callable[[str], None],
    onDuration: Callable[[str], None],
    onRecurrence: Callable[[str], None],
    onAdd: Callable[[], None],
    onToggle: Callable[[str, bool, str], None],
    onRefresh: Callable[[], None]
) -> JsxElement {
    openCount = len([task for task in tasks if not task.done]);
    expectedMinutes = 0;
    remainingMinutes = 0;
    for task in tasks {
        if view == "all" or task.due_date {
            expectedMinutes += task.duration_minutes;
            if not task.done {
                remainingMinutes += task.duration_minutes;
            }
        }
    }

    <ScrollView
        style={styles.screen}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
    >
        <View style={styles.header}>
            <Text style={styles.eyebrow}>YOUR PERSONAL PLANNER</Text>
            <Text style={styles.title}>Pace</Text>
            <Text style={styles.subtitle}>
                A clear place for what matters next.
            </Text>
        </View>

        <View style={styles.tabs}>
            <Pressable
                accessibilityRole="button"
                style={[styles.tab, styles.tabActive if view == "day" else None]}
                onPress={lambda { onView("day"); }}
            >
                <Text style={styles.tabText}>Day plan</Text>
            </Pressable>
            <Pressable
                accessibilityRole="button"
                style={[styles.tab, styles.tabActive if view == "all" else None]}
                onPress={lambda { onView("all"); }}
            >
                <Text style={styles.tabText}>All tasks</Text>
            </Pressable>
        </View>

        <View style={styles.dayCard}>
            <View style={styles.listHeader}>
                <Text style={styles.sectionLabel}>BROWSE DAYS</Text>
                <Pressable accessibilityRole="button" onPress={onToday}>
                    <Text style={styles.refreshText}>Today</Text>
                </Pressable>
            </View>
            <View style={styles.dayNavigation}>
                <Pressable
                    accessibilityRole="button"
                    accessibilityLabel="Previous day"
                    style={styles.dayArrow}
                    onPress={onPreviousDay}
                >
                    <Text style={styles.tabText}>‹</Text>
                </Pressable>
                <TextInput
                    style={[styles.input, styles.dayInput]}
                    accessibilityLabel="Day to view (YYYY-MM-DD)"
                    value={dayInput}
                    placeholder="YYYY-MM-DD"
                    placeholderTextColor={C.muted}
                    onChangeText={onDayInput}
                    onSubmitEditing={onApplyDay}
                    autoCapitalize="none"
                    maxLength={10}
                    returnKeyType="go"
                />
                <Pressable
                    accessibilityRole="button"
                    accessibilityLabel="Next day"
                    style={styles.dayArrow}
                    onPress={onNextDay}
                >
                    <Text style={styles.tabText}>›</Text>
                </Pressable>
                <Pressable
                    accessibilityRole="button"
                    style={styles.dayArrow}
                    onPress={onApplyDay}
                >
                    <Text style={styles.refreshText}>Go</Text>
                </Pressable>
            </View>
            <Text style={styles.hint}>
                {"A timed breakdown for the selected day, including your inbox."
                    if view == "day" else "Recurring tasks show their next occurrence on or after this day."}
            </Text>
        </View>

        <View style={styles.composerCard}>
            <Text style={styles.sectionLabel}>ADD A TASK</Text>
            <TextInput
                style={styles.input}
                accessibilityLabel="Task title"
                value={draft}
                placeholder="What do you need to do?"
                placeholderTextColor={C.muted}
                onChangeText={onDraft}
                onSubmitEditing={onAdd}
                returnKeyType="done"
            />
            <Text style={styles.fieldLabel}>Date / first occurrence</Text>
            <TextInput
                style={styles.input}
                accessibilityLabel="Task date or first occurrence"
                value={dueDate}
                placeholder="Due date: YYYY-MM-DD (optional)"
                placeholderTextColor={C.muted}
                onChangeText={onDueDate}
                autoCapitalize="none"
                maxLength={10}
            />
            <View style={styles.scheduleFields}>
                <View style={styles.scheduleField}>
                    <Text style={styles.fieldLabel}>Start time (24-hour)</Text>
                    <TextInput
                        style={styles.input}
                        accessibilityLabel="Start time (HH:MM)"
                        value={startTime}
                        placeholder="HH:MM (optional)"
                        placeholderTextColor={C.muted}
                        onChangeText={onStartTime}
                        autoCapitalize="none"
                        maxLength={5}
                    />
                </View>
                <View style={styles.scheduleField}>
                    <Text style={styles.fieldLabel}>Duration (minutes)</Text>
                    <TextInput
                        style={styles.input}
                        accessibilityLabel="Expected duration in minutes"
                        value={duration}
                        placeholder="e.g. 45"
                        placeholderTextColor={C.muted}
                        onChangeText={onDuration}
                        keyboardType="number-pad"
                        maxLength={4}
                    />
                </View>
            </View>
            <Text style={styles.fieldLabel}>Repeat</Text>
            <View style={styles.priorityRow}>
                {for option in ["none", "daily", "weekdays", "weekly", "monthly"] {
                    <Pressable
                        key={option}
                        accessibilityRole="button"
                        accessibilityState={{"selected": recurrence == option}}
                        style={[
                            styles.priorityChoice,
                            styles.prioritySelected if recurrence == option else None
                        ]}
                        onPress={lambda { onRecurrence(option); }}
                    >
                        <Text style={styles.priorityChoiceText}>{repeatLabel(option)}</Text>
                    </Pressable>
                }}
            </View>
            {if recurrence != "none" {
                <Text style={styles.hint}>
                    Complete each occurrence separately. The next one stays on your plan.
                </Text>
            }}
            <View style={styles.priorityRow}>
                <Text style={styles.priorityLabel}>Priority</Text>
                {for level in ["low", "medium", "high"] {
                    <Pressable
                        key={level}
                        accessibilityRole="button"
                        style={[
                            styles.priorityChoice,
                            styles.prioritySelected if priority == level else None
                        ]}
                        onPress={lambda { onPriority(level); }}
                    >
                        <Text style={styles.priorityChoiceText}>{level}</Text>
                    </Pressable>
                }}
            </View>
            <Button
                label={"Adding…" if working else "Add task"}
                onPress={onAdd}
                disabled={working or not draft.strip()}
            />
        </View>

        {if error {
            <View style={styles.errorCard}>
                <Text style={styles.errorText}>{error}</Text>
                <Pressable accessibilityRole="button" onPress={onRefresh}>
                    <Text style={styles.errorAction}>Try again</Text>
                </Pressable>
            </View>
        }}

        <View style={styles.listHeader}>
            <View>
                <Text style={styles.sectionTitle}>
                    {selectedDay if view == "day" else "All tasks"}
                </Text>
                <Text style={styles.listSummary}>
                    {str(openCount) + " to do · " + str(len(tasks) - openCount) + " complete"}
                </Text>
                <Text style={styles.listSummary}>
                    {str(expectedMinutes) + " min planned · " + str(remainingMinutes) + " min remaining"}
                </Text>
            </View>
            <Pressable accessibilityRole="button" onPress={onRefresh}>
                <Text style={styles.refreshText}>Refresh</Text>
            </Pressable>
        </View>

        {if view == "day" {
            <Text style={styles.hint}>Day totals exclude undated inbox estimates.</Text>
        }}

        {if loading {
            <View style={styles.empty}>
                <ActivityIndicator size="large" color={C.accent}/>
                <Text style={styles.emptyText}>Loading your plan…</Text>
            </View>
        } elif not tasks {
            <View style={styles.empty}>
                <Text style={styles.emptyTitle}>Room to breathe</Text>
                <Text style={styles.emptyText}>
                    {"Nothing planned for this day. Add a task above."
                        if view == "day"
                        else "No tasks yet. Add your first one above."}
                </Text>
            </View>
        } else {
            <View style={styles.list}>
                {for task in tasks {
                    <View key={task.id + task.occurrence_date} style={styles.row}>
                        <Pressable
                            accessibilityRole="button"
                            accessibilityLabel={"Reopen task" if task.done else "Complete task"}
                            style={[
                                styles.checkButton,
                                styles.checkButtonDone if task.done else None
                            ]}
                            disabled={working}
                            onPress={lambda { onToggle(task.id, task.done, task.occurrence_date); }}
                        >
                            <Text style={styles.checkText}>{"✓" if task.done else ""}</Text>
                        </Pressable>
                        <View style={styles.taskBody}>
                            <Text style={styles.taskTime}>{timeLabel(task)}</Text>
                            <Text style={[
                                styles.taskTitle,
                                styles.taskTitleDone if task.done else None
                            ]}>{task.title}</Text>
                            <Text style={styles.taskMeta}>
                                {(task.occurrence_date or task.due_date or "Inbox") + " · " + task.priority + " priority"}
                            </Text>
                            <Text style={styles.taskMeta}>
                                {(str(task.duration_minutes) + " min" if task.duration_minutes else "No duration") +
                                    (" · " + repeatLabel(task.recurrence) if task.recurrence != "none" else "")}
                            </Text>
                        </View>
                        <Pressable
                            accessibilityRole="button"
                            disabled={working}
                            onPress={lambda { onToggle(task.id, task.done, task.occurrence_date); }}
                        >
                            <Text style={styles.rowAction}>
                                {"Reopen" if task.done else "Done"}
                            </Text>
                        </Pressable>
                    </View>
                }}
            </View>
        }}
    </ScrollView>
}
