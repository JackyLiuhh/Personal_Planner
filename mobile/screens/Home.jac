"""Today and all-task views for the native planner."""

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

def:pub HomeScreen(
    tasks: list[TaskView],
    view: str,
    draft: str,
    dueDate: str,
    priority: str,
    loading: bool,
    working: bool,
    error: str,
    onView: Callable[[str], None],
    onDraft: Callable[[str], None],
    onDueDate: Callable[[str], None],
    onPriority: Callable[[str], None],
    onAdd: Callable[[], None],
    onToggle: Callable[[str, bool], None],
    onRefresh: Callable[[], None]
) -> JsxElement {
    openCount = len([task for task in tasks if not task.done]);

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
                style={[styles.tab, styles.tabActive if view == "today" else None]}
                onPress={lambda { onView("today"); }}
            >
                <Text style={styles.tabText}>Today</Text>
            </Pressable>
            <Pressable
                accessibilityRole="button"
                style={[styles.tab, styles.tabActive if view == "all" else None]}
                onPress={lambda { onView("all"); }}
            >
                <Text style={styles.tabText}>All tasks</Text>
            </Pressable>
        </View>

        <View style={styles.composerCard}>
            <Text style={styles.sectionLabel}>QUICK ADD</Text>
            <TextInput
                style={styles.input}
                value={draft}
                placeholder="What do you need to do?"
                placeholderTextColor={C.muted}
                onChangeText={onDraft}
                onSubmitEditing={onAdd}
                returnKeyType="done"
            />
            <TextInput
                style={styles.input}
                value={dueDate}
                placeholder="Due date: YYYY-MM-DD (optional)"
                placeholderTextColor={C.muted}
                onChangeText={onDueDate}
                autoCapitalize="none"
                maxLength={10}
            />
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
                    {"Today's plan" if view == "today" else "All tasks"}
                </Text>
                <Text style={styles.listSummary}>
                    {str(openCount)} to do
                    {" · " + str(len(tasks) - openCount) + " complete" if view == "all" else ""}
                </Text>
            </View>
            <Pressable accessibilityRole="button" onPress={onRefresh}>
                <Text style={styles.refreshText}>Refresh</Text>
            </Pressable>
        </View>

        {if loading {
            <View style={styles.empty}>
                <ActivityIndicator size="large" color={C.accent}/>
                <Text style={styles.emptyText}>Loading your plan…</Text>
            </View>
        } elif not tasks {
            <View style={styles.empty}>
                <Text style={styles.emptyTitle}>Room to breathe</Text>
                <Text style={styles.emptyText}>
                    {"Nothing due today. Add a task to get started."
                        if view == "today"
                        else "No tasks yet. Add your first one above."}
                </Text>
            </View>
        } else {
            <View style={styles.list}>
                {for task in tasks {
                    <View key={task.id} style={styles.row}>
                        <Pressable
                            accessibilityRole="button"
                            accessibilityLabel={"Reopen task" if task.done else "Complete task"}
                            style={[
                                styles.checkButton,
                                styles.checkButtonDone if task.done else None
                            ]}
                            disabled={working}
                            onPress={lambda { onToggle(task.id, task.done); }}
                        >
                            <Text style={styles.checkText}>{"✓" if task.done else ""}</Text>
                        </Pressable>
                        <View style={styles.taskBody}>
                            <Text style={[
                                styles.taskTitle,
                                styles.taskTitleDone if task.done else None
                            ]}>{task.title}</Text>
                            <Text style={styles.taskMeta}>
                                {task.due_date if task.due_date else "No date"} · {task.priority} priority
                            </Text>
                        </View>
                        <Pressable
                            accessibilityRole="button"
                            disabled={working}
                            onPress={lambda { onToggle(task.id, task.done); }}
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
