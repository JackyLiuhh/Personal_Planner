"""Planner web app entry point."""

import "./styles.css";
import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    <ClientApp/>
}
