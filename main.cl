import std/io.cl
import src/ui.cl

fn main() -> int:
    let card = Card(
        child = Column([
            Text("⚡ Welcome to Cluster IDE", 20, "#58a6ff", true),
            Text("Self-Hosting IDE in Pure Cluster Language & UI", 13, "#8b949e"),
            Row([
                Button("Run Tests", "alert('All 310 Tests Passing!')"),
                Button("Docs", "alert('Documentation loaded')", "#21262d", "#58a6ff")
            ], 8)
        ], 14),
        bg_color = "#161b22"
    )
    pln(render_page_html("Cluster IDE App", card))
    return 0