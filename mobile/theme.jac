"""Design tokens and React Native styles for the planner."""

import from "@jac/mobui" { StyleSheet }

obj Palette {
    has bg: str = "#0b1118",
        surface: str = "#15202b",
        border: str = "#293947",
        field: str = "#101a24",
        text: str = "#f1f5f7",
        muted: str = "#9caeb9",
        accent: str = "#52d0b5",
        onAccent: str = "#08221e",
        danger: str = "#ff908c";
}

obj Spacing {
    has xs: int = 4,
        sm: int = 8,
        md: int = 12,
        lg: int = 16,
        xl: int = 24;
}

obj Radius {
    has sm: int = 8,
        md: int = 12,
        lg: int = 16,
        pill: int = 999;
}

obj FontSize {
    has sm: int = 14,
        md: int = 16,
        lg: int = 20,
        xl: int = 28;
}

glob:pub C: Palette = Palette(),
     S: Spacing = Spacing(),
     R: Radius = Radius(),
     F: FontSize = FontSize();

glob:pub styles = StyleSheet.create(
         {
             "screen": {"flex": 1, "backgroundColor": C.bg},
             "content": {
                 "width": "100%",
                 "maxWidth": 560,
                 "alignSelf": "center",
                 "padding": S.lg,
                 "paddingBottom": 48,
                 "gap": S.lg
             },
             "header": {"gap": S.xs, "paddingTop": 32, "paddingBottom": S.sm},
             "eyebrow": {
                 "color": C.accent,
                 "fontSize": 11,
                 "fontWeight": "bold",
                 "letterSpacing": 1.6
             },
             "title": {"color": C.text, "fontSize": 34, "fontWeight": "bold"},
             "subtitle": {"color": C.muted, "fontSize": F.md},
             "tabs": {
                 "flexDirection": "row",
                 "gap": S.sm,
                 "backgroundColor": C.field,
                 "borderRadius": R.md,
                 "padding": S.xs
             },
             "tab": {
                 "flex": 1,
                 "borderRadius": R.sm,
                 "paddingVertical": S.md,
                 "alignItems": "center"
             },
             "tabActive": {"backgroundColor": C.surface},
             "tabText": {"color": C.text, "fontSize": F.sm, "fontWeight": "bold"},
             "composerCard": {
                 "backgroundColor": C.surface,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "borderRadius": R.lg,
                 "padding": S.lg,
                 "gap": S.md
             },
             "sectionLabel": {
                 "color": C.accent,
                 "fontSize": 11,
                 "fontWeight": "bold",
                 "letterSpacing": 1.4
             },
             "input": {
                 "color": C.text,
                 "fontSize": F.sm,
                 "backgroundColor": C.field,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "borderRadius": R.sm,
                 "paddingVertical": S.md,
                 "paddingHorizontal": S.lg
             },
             "priorityRow": {
                 "flexDirection": "row",
                 "alignItems": "center",
                 "gap": S.sm,
                 "flexWrap": "wrap"
             },
             "priorityLabel": {"color": C.muted, "fontSize": F.sm, "marginRight": S.xs},
             "priorityChoice": {
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "borderRadius": R.pill,
                 "paddingVertical": S.xs,
                 "paddingHorizontal": S.md
             },
             "prioritySelected": {"backgroundColor": C.field, "borderColor": C.accent},
             "priorityChoiceText": {"color": C.text, "fontSize": F.sm},
             "errorCard": {
                 "backgroundColor": C.surface,
                 "borderWidth": 1,
                 "borderColor": C.danger,
                 "borderRadius": R.md,
                 "padding": S.lg,
                 "gap": S.sm
             },
             "errorText": {"color": C.text, "fontSize": F.sm},
             "errorAction": {"color": C.danger, "fontSize": F.sm, "fontWeight": "bold"},
             "listHeader": {
                 "flexDirection": "row",
                 "alignItems": "center",
                 "justifyContent": "space-between"
             },
             "sectionTitle": {"color": C.text, "fontSize": F.lg, "fontWeight": "bold"},
             "listSummary": {"color": C.muted, "fontSize": F.sm, "marginTop": S.xs},
             "refreshText": {"color": C.accent, "fontSize": F.sm, "fontWeight": "bold"},
             "list": {"gap": S.sm},
             "row": {
                 "flexDirection": "row",
                 "alignItems": "center",
                 "gap": S.sm,
                 "backgroundColor": C.surface,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "borderRadius": R.lg,
                 "padding": S.md
             },
             "checkButton": {
                 "width": 28,
                 "height": 28,
                 "borderWidth": 2,
                 "borderColor": C.accent,
                 "borderRadius": R.pill,
                 "alignItems": "center",
                 "justifyContent": "center"
             },
             "checkButtonDone": {"backgroundColor": C.accent},
             "checkText": {"color": C.bg, "fontSize": F.sm, "fontWeight": "bold"},
             "taskBody": {"flex": 1, "gap": S.xs},
             "taskTitle": {"color": C.text, "fontSize": F.md, "fontWeight": "600"},
             "taskTitleDone": {"color": C.muted, "textDecorationLine": "line-through"},
             "taskMeta": {"color": C.muted, "fontSize": 12},
             "rowAction": {"color": C.accent, "fontSize": F.sm, "fontWeight": "bold"},
             "empty": {
                 "alignItems": "center",
                 "backgroundColor": C.surface,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "borderRadius": R.lg,
                 "gap": S.sm,
                 "padding": S.xl
             },
             "emptyTitle": {"color": C.text, "fontSize": F.lg, "fontWeight": "bold"},
             "emptyText": {"color": C.muted, "fontSize": F.sm, "textAlign": "center"}
         }
     );
