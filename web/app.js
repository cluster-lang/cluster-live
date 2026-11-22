// ==============================================================================
// Cluster Live Studio — Interactive Client Controller
// ==============================================================================

const SAMPLES = {
    ui_ecommerce: `// ==============================================================================
// Example 06: E-Commerce Storefront in Cluster UI
// Demonstrates: AppBar, TextInput, Categories Wrap, Product Grid, BottomNav
// ==============================================================================
import src/ui.cl

fn create_product_card(name: string, brand: string, price: string, tag: string) -> Widget:
    let mut items: vector[Widget] = []
    let mut header_row: vector[Widget] = []
    header_row.push(Badge(tag, "#1f6feb", "#ffffff", 10))
    header_row.push(Spacer())
    header_row.push(Badge(price, "#238636", "#ffffff", 11))
    items.push(Row(header_row, 8))
    items.push(Text(name, 16, "#f0f6fc", true))
    items.push(Text(brand, 12, "#8b949e", false))
    items.push(Divider("#30363d", 1))
    items.push(Button("Add to Cart 🛒", "alert('Added ' + name + ' to cart!')", "#238636", "#ffffff", 12))
    return Card(Column(items, 8), "#161b22", 12, 14)

fn build_store_app() -> Widget:
    let mut app_children: vector[Widget] = []
    let back_btn: Widget = Button("←", "", "#21262d", "#e6edf3", 14)
    let cart_badge: Widget = Badge("3 items", "#8957e5", "#ffffff", 11)
    app_children.push(AppBar("⚡ KickStore Pro", back_btn, cart_badge, "#161b22"))

    let mut body_items: vector[Widget] = []
    body_items.push(TextInput("🔍 Search shoes, streetwear, drops...", 14))

    let mut cats: vector[Widget] = []
    cats.push(Badge("🔥 Featured", "#238636", "#ffffff", 12))
    cats.push(Badge("👟 Running", "#21262d", "#8b949e", 12))
    cats.push(Badge("🏀 Basketball", "#21262d", "#8b949e", 12))
    cats.push(Badge("⚡ Lifestyle", "#21262d", "#8b949e", 12))
    cats.push(Badge("🏷️ Sale -40%", "#da3633", "#ffffff", 12))
    body_items.push(Wrap(cats, 8))

    let mut sec_row: vector[Widget] = []
    sec_row.push(Text("Trending Kicks", 18, "#f0f6fc", true))
    sec_row.push(Spacer())
    sec_row.push(Link("See all 128 items →", "#", "#58a6ff", 12))
    body_items.push(Row(sec_row, 8))

    let mut products: vector[Widget] = []
    products.push(create_product_card("Air Zoom 90", "Nike Running Edition", "$149.00", "NEW DROP"))
    products.push(create_product_card("UltraBoost Pro", "Adidas Performance", "$189.00", "POPULAR"))
    products.push(create_product_card("Jordan Retro High", "Air Jordan Classic", "$210.00", "LIMITED"))
    products.push(create_product_card("CloudFlow X", "On Running Swiss", "$135.00", "RESTOCKED"))
    body_items.push(Grid(products, 2, 12))

    app_children.push(Box(Column(body_items, 16), 0, 0, 16, "#0d1117", 0))

    let mut nav_tabs: vector[Widget] = []
    nav_tabs.push(TabItem("Home", "🏠", true, 0))
    nav_tabs.push(TabItem("Explore", "🔍", false, 0))
    nav_tabs.push(TabItem("Cart", "🛒", false, 3))
    nav_tabs.push(TabItem("Profile", "👤", false, 0))
    app_children.push(BottomNavigationBar(nav_tabs, "#161b22"))

    return Column(app_children, 0)

fn main() -> int:
    let app: Widget = build_store_app()
    let html: string = render_page_html("KickStore Pro - Cluster UI", app)
    pln(html)
    return 0
`,

    ui_chat: `// ==============================================================================
// Example 07: Modern Chat & Messaging App in Cluster UI
// Demonstrates: AppBar with Avatar, Bubbles, Quick reply chips, Input row
// ==============================================================================
import src/ui.cl

fn create_incoming_bubble(author: string, msg: string, time: string) -> Widget:
    let mut b_items: vector[Widget] = []
    b_items.push(Text(author, 12, "#58a6ff", true))
    b_items.push(Text(msg, 14, "#f0f6fc", false))
    b_items.push(Text(time, 10, "#8b949e", false))
    return Card(Column(b_items, 4), "#21262d", 12, 10)

fn create_outgoing_bubble(msg: string, time: string) -> Widget:
    let mut b_items: vector[Widget] = []
    b_items.push(Text(msg, 14, "#ffffff", false))
    b_items.push(Text(time + " · Read ✓✓", 10, "#d2a8ff", false))
    return Card(Column(b_items, 4), "#1f6feb", 12, 10)

fn build_chat_app() -> Widget:
    let mut app_children: vector[Widget] = []

    let av: Widget = Avatar("SC", "", 38, true, "#8957e5")
    let call_btn: Widget = Button("📞 Call", "alert('Calling Sarah...')", "#21262d", "#58a6ff", 12)
    app_children.push(AppBar("Sarah Connor", av, call_btn, "#161b22"))

    let mut msgs: vector[Widget] = []
    let mut date_row: vector[Widget] = []
    date_row.push(Spacer())
    date_row.push(Badge("Today, November 21", "#21262d", "#8b949e", 11))
    date_row.push(Spacer())
    msgs.push(Row(date_row, 8))

    msgs.push(create_incoming_bubble("Sarah Connor", "Hey! Is the Cluster UI engine ready for production?", "10:41 AM"))
    msgs.push(create_outgoing_bubble("Yes! Pure Cluster, 0 dependencies, generates both HTML & Android XML.", "10:42 AM"))
    msgs.push(create_incoming_bubble("Sarah Connor", "Awesome! Can it run live hot-reload in the browser?", "10:43 AM"))
    msgs.push(create_outgoing_bubble("Sub-50ms execution speed, with live mobile preview on port 8080! 🚀", "10:44 AM"))

    let mut chips: vector[Widget] = []
    chips.push(Badge("👍 Looks great!", "#30363d", "#c9d1d9", 12))
    chips.push(Badge("🚀 Ship it now", "#30363d", "#c9d1d9", 12))
    chips.push(Badge("📱 Test on Android", "#30363d", "#c9d1d9", 12))
    msgs.push(Wrap(chips, 8))

    app_children.push(Box(Column(msgs, 12), 0, 0, 16, "#0d1117", 0))

    let mut input_row: vector[Widget] = []
    input_row.push(Button("📎", "", "#21262d", "#8b949e", 14))
    input_row.push(Expanded(TextInput("Write a message to Sarah...", 14)))
    input_row.push(Button("Send ✈️", "alert('Message sent!')", "#238636", "#ffffff", 13))
    app_children.push(Box(Row(input_row, 8), 0, 0, 12, "#161b22", 0))

    return Column(app_children, 0)

fn main() -> int:
    let app: Widget = build_chat_app()
    let html: string = render_page_html("Chat with Sarah - Cluster UI", app)
    pln(html)
    return 0
`,

    ui_advanced_controls: `// ==============================================================================
// Example 09: Advanced Controls & Feedback Showcase in Cluster UI
// Demonstrates: Alert, Slider, Checkbox, Radio, Chip, CircularProgress,
//               ExpansionTile, Icon, AppBar, BottomNavigationBar, FloatingActionButton
// ==============================================================================
import src/core/widget.cl
import src/render/html.cl

fn build_advanced_app() -> Widget:
    let alert_box: Widget = Alert(
        title = "Cloud Cluster Synchronization Active",
        message = "All widgets are live-synced across HTML5, Android Jetpack, and Apple SwiftUI.",
        severity = "success"
    )

    let form_title: Widget = Text("Interactive Controls & Form Primitives", 18, "#58a6ff", true)
    let chk1: Widget = Checkbox(is_checked = true, label = "Hardware Acceleration (Vulkan / Metal)")
    let chk2: Widget = Checkbox(is_checked = false, label = "Experimental JIT Optimization")
    let r_option1: Widget = Radio(is_selected = true, label = "Dark Neon Theme (Default)", value_str = "dark_neon")
    let r_option2: Widget = Radio(is_selected = false, label = "Material You Theme", value_str = "material_you")
    let slider_label: Widget = Text("Execution Thread Pool Size: 8 Threads", 14, "#e6edf3", false)
    let thread_slider: Widget = Slider(value = 64, min_value = 1, max_value = 128, on_change = "console.log(this.value)")

    let controls_card: Widget = Card(
        child = Column(
            children = [
                form_title,
                Spacer(),
                chk1,
                chk2,
                Divider(),
                r_option1,
                r_option2,
                Divider(),
                slider_label,
                thread_slider
            ],
            spacing = 10,
            padding = 16
        )
    )

    let chip_title: Widget = Text("Filter & Category Chips", 16, "#e6edf3", true)
    let c1: Widget = Chip(label = "Performance", icon_name = "bolt", on_delete = "alert('removed')", bg_color = "#238636")
    let c2: Widget = Chip(label = "Cross-Platform", icon_name = "globe", on_delete = "", bg_color = "#1f6feb")
    let c3: Widget = Chip(label = "Native LLVM", icon_name = "cpu", on_delete = "", bg_color = "#8957e5")
    let c4: Widget = Chip(label = "Zero-Cost", icon_name = "zap", on_delete = "", bg_color = "#d29922")
    let chips_row: Widget = Wrap(children = [c1, c2, c3, c4], spacing = 8)

    let exp_content1: Widget = Text("Cluster compiler compiles directly from Pratt AST into SSA LLVM IR in ~3ms.", 13, "#8b949e", false)
    let exp_content2: Widget = Text("Native binary generation takes ~40ms with zero runtime GC pauses.", 13, "#8b949e", false)
    let accordion: Widget = ExpansionTile(
        title = "Compiler Architecture Deep Dive",
        children = [exp_content1, exp_content2],
        is_expanded = true
    )

    let prog_label: Widget = Text("Asset Pipeline Compilation", 14, "#e6edf3", false)
    let spinner: Widget = CircularProgressIndicator(size = 24, color = "#58a6ff", border_width = 3)
    let prog_row: Widget = Row(children = [spinner, prog_label], spacing = 12, padding = 4)

    let nav_home: Widget = TabItem("Dashboard", "home", true, 0)
    let nav_widgets: Widget = TabItem("Components", "layers", false, 40)
    let nav_settings: Widget = TabItem("Settings", "settings", false, 0)
    let bbar: Widget = BottomNavigationBar(items = [nav_home, nav_widgets, nav_settings])

    let main_col: Widget = Column(
        children = [alert_box, controls_card, chip_title, chips_row, accordion, prog_row],
        spacing = 16,
        padding = 16
    )

    let scrollable_body: Widget = ScrollView(child = main_col)
    let app_bar_header: Widget = AppBar(
        title = "Cluster UI — 40 Core Widgets",
        leading = Icon(name = "menu", size = 20, color = "#e6edf3"),
        trailing = Icon(name = "bell", size = 20, color = "#58a6ff")
    )
    let fab_btn: Widget = FloatingActionButton(icon_name = "+", on_click = "alert('Action clicked!')", bg_color = "#238636")

    return Scaffold(
        app_bar = app_bar_header,
        body = scrollable_body,
        bottom_bar = bbar,
        fab = fab_btn,
        bg_color = "#0d1117"
    )

fn main() -> int:
    let app: Widget = build_advanced_app()
    let html: string = render_page_html("Cluster UI - Advanced Controls", app)
    pln(html)
    return 0
`,

    ui_enterprise: `// ==============================================================================
// Example 10: 50 Widgets Enterprise Dashboard in Cluster UI
// Demonstrates: MetricCard, DataTable, SegmentedButton, Stepper, Rating,
//               Skeleton, Breadcrumbs, CodeBlock, and Modern KPIs
// ==============================================================================
import src/core/widget.cl
import src/render/html.cl

fn build_enterprise_dashboard() -> Widget:
    let breadcrumb_trail: Widget = Breadcrumbs(
        items = ["Cluster Cloud", "Workspaces", "Compiler Cluster", "Realtime Metrics"],
        color = "#58a6ff"
    )

    let card1: Widget = MetricCard("Compile Latency", "49.5 ms", "+140% faster", true, "zap", "#3fb950")
    let card2: Widget = MetricCard("Memory Overhead", "0.0 MB", "Zero-GC Deterministic", true, "cpu", "#58a6ff")
    let card3: Widget = MetricCard("Worker Throughput", "128,400 ops/s", "+38.2% vs Swift/Dart", true, "activity", "#a371f7")
    let card4: Widget = MetricCard("System Health", "99.99%", "All 50 UI Primitives", true, "shield", "#d29922")
    let metrics_row: Widget = Row(children = [card1, card2, card3, card4], spacing = 16)

    let timeframe_selector: Widget = SegmentedButton(["Live", "1 Hour", "24 Hours", "7 Days"], 0)
    let scale_stepper: Widget = Stepper("Worker Nodes:", 16, 1, 64)
    let user_rating: Widget = Rating(5, 5, "#f1e05a", 18)
    let control_bar: Widget = Row(
        children = [timeframe_selector, Spacer(), scale_stepper, Spacer(), Row(children = [Text("Score:", 13, "#8b949e"), user_rating], spacing = 8)],
        spacing = 16
    )

    let table_headers: vector[string] = ["Compiler Pipeline Stage", "Target Backend", "Latency", "Optimization", "Status"]
    let row1: Widget = Row(children = [Text("Pratt AST Parsing", 13, "#e6edf3", true), Text("Memory IR", 13, "#8b949e"), Text("0.38 ms", 13, "#3fb950"), Badge("High", "#1f6feb"), Text("PASSED", 13, "#3fb950", true)], spacing = 8)
    let row2: Widget = Row(children = [Text("SSA LLVM Emission", 13, "#e6edf3", true), Text("LLVM IR", 13, "#8b949e"), Text("0.39 ms", 13, "#3fb950"), Badge("O3", "#238636"), Text("PASSED", 13, "#3fb950", true)], spacing = 8)
    let row3: Widget = Row(children = [Text("Native Machine Code", 13, "#e6edf3", true), Text("Clang x86_64", 13, "#8b949e"), Text("42.1 ms", 13, "#3fb950"), Badge("Release", "#8957e5"), Text("PASSED", 13, "#3fb950", true)], spacing = 8)
    let data_table: Widget = DataTable(headers = table_headers, rows = [row1, row2, row3])

    let sample_code: string = "// Pure Cluster UI Component\\nfn StatusBadge(active: bool) -> Widget:\\n    if active:\\n        return Badge(\\"ONLINE\\", \\"#238636\\")\\n    return Badge(\\"OFFLINE\\", \\"#da3633\\")"
    let code_viewer: Widget = CodeBlock(code = sample_code, language = "cluster")

    let skeleton_box: Widget = Row(
        children = [Text("Telemetry Stream:", 13, "#8b949e"), Skeleton(width = 160, height = 16, border_radius = 4), Skeleton(width = 70, height = 16, border_radius = 4)],
        spacing = 12
    )

    let content: Widget = Column(
        children = [breadcrumb_trail, Spacer(), metrics_row, Spacer(), control_bar, Spacer(), Text("Core Performance Ledger", 16, "#e6edf3", true), data_table, Spacer(), Text("Declarative Code", 16, "#e6edf3", true), code_viewer, Spacer(), skeleton_box],
        spacing = 14
    )

    let app_bar: Widget = AppBar(
        title = "Cluster UI v4.0 — 50 Core Widgets Enterprise Suite",
        leading = Icon("cpu", 20, "#58a6ff"),
        trailing = Icon("bell", 20, "#58a6ff"),
        bg_color = "#161b22"
    )
    let bottom_nav: Widget = BottomNavigationBar(items = [TabItem("Overview", "home", true, 0), TabItem("Telemetry", "activity", false, 50), TabItem("Components", "layers", false, 0), TabItem("Config", "settings", false, 0)])
    let fab: Widget = FloatingActionButton("+", "alert('Cluster node created!')")

    return Scaffold(app_bar = app_bar, body = ScrollView(child = Box(content, 0, 0, 20, "#0d1117", 0)), bottom_bar = bottom_nav, fab = fab)

fn main():
    let app: Widget = build_enterprise_dashboard()
    let html_output: string = render_page_html("Cluster UI - 50 Widgets Enterprise Dashboard", app)
    pln(html_output)
`,

    ui_multiplatform: `// ==============================================================================
// Example 08: Universal Multi-Platform Showcase in Cluster UI
// 1 Codebase -> 3 Native Platforms: Web HTML, Android XML, Apple SwiftUI
// ==============================================================================
import src/ui.cl

fn build_profile_screen() -> Widget:
    let mut cards: vector[Widget] = []

    let mut header_items: vector[Widget] = []
    header_items.push(Avatar("AK", "", 64, true, "#8957e5"))
    header_items.push(Text("Alamgir Khan", 20, "#ffffff", true))
    header_items.push(Text("Cluster Language Architect", 14, "#8b949e", false))
    cards.push(Card(Center(Column(header_items, 8)), "#161b22", 16, 20))

    let mut storage_items: vector[Widget] = []
    let mut s_row: vector[Widget] = []
    s_row.push(Text("Cloud Storage", 14, "#f0f6fc", true))
    s_row.push(Spacer())
    s_row.push(Badge("68% Used", "#1f6feb", "#ffffff", 11))
    storage_items.push(Row(s_row, 8))
    storage_items.push(ProgressBar(68, "#1f6feb", "#21262d", 8))
    cards.push(Card(Column(storage_items, 10), "#161b22", 12, 16))

    let mut list_items: vector[Widget] = []
    list_items.push(ListTile("Security & Keys", "Manage 2FA & SSH Keys", "🔒"))
    list_items.push(Divider("#30363d", 1))
    list_items.push(ListTile("Notifications", "Push & Email Alerts", "🔔"))
    list_items.push(Divider("#30363d", 1))
    list_items.push(ListTile("Connected Devices", "3 Active Sessions", "📱"))
    cards.push(Card(Column(list_items, 4), "#161b22", 12, 12))

    cards.push(Button("Save Preferences", "alert('Preferences saved!')", "#238636", "#ffffff", 14))

    let scroll_body: Widget = ScrollView(Column(cards, 16))
    let top_bar: Widget = AppBar("Settings & Profile", Button("←", "", "#21262d", "#e6edf3", 14), Badge("PRO", "#d2a8ff", "#ffffff", 11), "#161b22")
    
    let mut tabs: vector[Widget] = []
    tabs.push(TabItem("Home", "🏠", false, 0))
    tabs.push(TabItem("Profile", "👤", true, 0))
    tabs.push(TabItem("Settings", "⚙️", false, 0))
    let bottom_nav: Widget = BottomNavigationBar(tabs, "#161b22")
    let fab: Widget = FloatingActionButton("+", "alert('New item')", "#1f6feb")

    return Scaffold(top_bar, scroll_body, bottom_nav, fab, "#0d1117")

fn main() -> int:
    let screen: Widget = build_profile_screen()
    let html: string = render_page_html("Universal Settings - Cluster UI", screen)
    pln(html)

    let xml: string = render_activity_layout_xml(screen)
    pln("\n<!-- ANDROID XML EXPORT -->\n" + xml)

    let swift: string = render_swiftui_view("ProfileSettingsView", screen)
    pln("\n// APPLE SWIFTUI EXPORT\n" + swift)
    return 0
`,

    ui_dashboard: `// ==============================================================================
// Cluster UI: Live Interactive Analytics Dashboard
// Inspired by Flutter & SwiftUI — Zero Dependencies, 100% Pure Cluster
// ==============================================================================
import std/ui.cl

fn main() -> int:
    // Stat Card 1: Active Nodes
    let mut s1_header: vector[Widget] = []
    s1_header.push(Text("Active Nodes", 13, "#8b949e", false))
    s1_header.push(Spacer())
    s1_header.push(Badge("+18.4%", "#238636", "#ffffff", 11))
    
    let mut stat1_items: vector[Widget] = []
    stat1_items.push(Row(s1_header, 8, 0))
    stat1_items.push(Text("14,892", 28, "#ffffff", true))
    stat1_items.push(ProgressBar(74, "#238636", "#21262d", 6))
    let card1: Widget = Card(Column(stat1_items, 10, 0), "#161b22", 12, 16)

    // Stat Card 2: Compiler Throughput
    let mut s2_header: vector[Widget] = []
    s2_header.push(Text("Throughput", 13, "#8b949e", false))
    s2_header.push(Spacer())
    s2_header.push(Badge("Ultra Fast", "#1f6feb", "#ffffff", 11))
    
    let mut stat2_items: vector[Widget] = []
    stat2_items.push(Row(s2_header, 8, 0))
    stat2_items.push(Text("820k ops/s", 28, "#58a6ff", true))
    stat2_items.push(ProgressBar(92, "#1f6feb", "#21262d", 6))
    let card2: Widget = Card(Column(stat2_items, 10, 0), "#161b22", 12, 16)

    let mut stats_row: vector[Widget] = []
    stats_row.push(card1)
    stats_row.push(card2)

    // Recent Deployments
    let mut list_items: vector[Widget] = []
    list_items.push(Text("Live Cluster Deployments", 16, "#e6edf3", true))
    list_items.push(Divider("#30363d", 1))
    list_items.push(ListTile("cluster-core-v1.0", "Deployed 2m ago • Frankfurt (eu-central)", "🚀", "alert('Viewing cluster-core')"))
    list_items.push(ListTile("zk-nn-training-node", "Healthy • 8x Tensor Workers Active", "⚡", "alert('Viewing zk-nn')"))
    list_items.push(ListTile("mobile-apk-pipeline", "Built in 34ms • Zero Dependencies", "📱", "alert('Viewing apk-pipeline')"))
    let list_card: Widget = Card(Column(list_items, 8, 0), "#161b22", 12, 16)

    // Dashboard View
    let mut page: vector[Widget] = []
    page.push(Text("Cluster Cloud Dashboard", 22, "#ffffff", true))
    page.push(Text("Real-time telemetry and native compiler metrics", 13, "#8b949e", false))
    page.push(Row(stats_row, 12, 0))
    page.push(list_card)

    let root: Widget = Box(Column(page, 14, 0), 420, 0, 0, "", 0)
    pln(render_page_html("Cluster UI Dashboard", root))
    return 0
`,

    ui_profile: `// ==============================================================================
// Cluster UI: Social Profile Card (Flutter & SwiftUI Style)
// ==============================================================================
import std/ui.cl

fn main() -> int:
    let mut header_row: vector[Widget] = []
    
    // Avatar
    let avatar: Widget = Box(
        Center(Text("ZK", 18, "#ffffff", true)),
        48, 48, 0, "#1f6feb", 24
    )
    header_row.push(avatar)

    // Name & Handle
    let mut name_col: vector[Widget] = []
    name_col.push(Text("Zaid Khan", 18, "#e6edf3", true))
    name_col.push(Text("@zaid_zk • Core Architect", 12, "#8b949e", false))
    header_row.push(Column(name_col, 2, 0))

    // Bio
    let bio: Widget = Text(
        "Building Cluster Language — the zero-dependency, ultra-fast language for AI, Systems & Native UI.",
        13, "#c9d1d9"
    )

    // Stats
    let mut stats: vector[Widget] = []
    stats.push(Text("⭐ 1.2k Stars", 12, "#3fb950", true))
    stats.push(Text("👥 420 Contributors", 12, "#58a6ff", true))
    stats.push(Text("🚀 v1.0 Native", 12, "#d29922", true))

    // Actions
    let mut buttons: vector[Widget] = []
    buttons.push(Button("Follow", "alert('Followed!')", "#238636", "#ffffff", 13))
    buttons.push(Button("Message", "alert('Message opened!')", "#21262d", "#58a6ff", 13))

    // Card Container
    let mut card_items: vector[Widget] = []
    card_items.push(Row(header_row, 12, 0))
    card_items.push(bio)
    card_items.push(Row(stats, 16, 0))
    card_items.push(Row(buttons, 10, 0))

    let card: Widget = Card(Column(card_items, 14, 0), "#161b22", 16, 18)
    let root: Widget = Box(card, 400, 0, 0, "", 0)

    pln(render_page_html("Cluster UI Profile", root))
    return 0
`,

    ui_settings: `// ==============================================================================
// Cluster UI: System Settings & Preferences Screen
// ==============================================================================
import std/ui.cl

fn main() -> int:
    // General Preferences
    let mut gen: vector[Widget] = []
    gen.push(Text("Engine Preferences", 16, "#e6edf3", true))
    gen.push(Divider("#30363d", 1))
    gen.push(Toggle(true, "Hardware Acceleration (Vulkan/Metal)"))
    gen.push(Toggle(true, "LLVM Native Optimization (-O3)"))
    gen.push(Toggle(false, "Verbose Diagnostic Tracing"))
    let card1: Widget = Card(Column(gen, 10, 0), "#161b22", 12, 16)

    // Registry Settings
    let mut reg: vector[Widget] = []
    reg.push(Text("Package Registry", 16, "#e6edf3", true))
    reg.push(Divider("#30363d", 1))
    reg.push(Text("Registry API Endpoint", 12, "#8b949e", false))
    reg.push(TextInput("https://pkg.cluster-lang.org/v1", 13))
    reg.push(Button("Save Settings", "alert('Saved!')", "#238636", "#ffffff", 13))
    let card2: Widget = Card(Column(reg, 10, 0), "#161b22", 12, 16)

    let mut screen: vector[Widget] = []
    let leading: Widget = Button("‹ Back", "history.back()", "#21262d", "#58a6ff", 13)
    let trailing: Widget = Badge("v1.0.0", "#30363d", "#8b949e", 11)
    screen.push(AppBar("Settings", leading, trailing, "#161b22"))
    screen.push(card1)
    screen.push(card2)

    let root: Widget = Box(Column(screen, 16, 0), 400, 0, 0, "", 0)
    pln(render_page_html("Cluster Settings", root))
    return 0
`,

    model_transaction: `// Model Schema, Automatic JSON, and Reflection in Cluster Language
model Transaction:
    id: int
    sender: string
    receiver: string
    category: string
    amount: float
    payload: string
    checksum: string

    fn is_valid(&self) -> bool:
        return self.amount > 0.0 and len(self.checksum) > 0

    fn summary(&self) -> string:
        return "[" + self.category + "] " + self.sender + " -> " + self.receiver + " ($" + str(self.amount) + ")"

fn main():
    print("=== Cluster Model & Serialization Demo ===")
    
    // Create new strongly-typed model instance
    let tx := Transaction(
        id = 1001,
        sender = "0xAlice",
        receiver = "0xBob",
        category = "DefiSwap",
        amount = 1450.75,
        payload = "swap_tokens(ETH, CL)",
        checksum = "e4a2d8"
    )

    print("Transaction Summary: " + tx.summary())
    print("Is Valid: " + str(tx.is_valid()))
    
    // Automatic JSON Serialization synthesized by compiler
    let json_str: string = tx.to_json()
    print("\\nSynthesized JSON Serialization:")
    print(json_str)

    // Compile-time reflection
    print("\\nReflected Field Count: " + str(Transaction::__field_count()))
`,

    user_input: `// Interactive User Input in Cluster Language
fn main() -> int:
    // Prompt the user and read their first name:
    firstName := input("Type your first name: ")

    pln("Your name is: " + firstName)
    return 0
`,

    hello_world: `// Hello World & Basic Primitives in Cluster Language
fn greet(name: string, times: int):
    let mut i: int = 0
    while i < times:
        print("Hello, " + name + "! (iteration " + str(i + 1) + ")")
        i = i + 1

fn main():
    print("🚀 Welcome to Cluster Live Studio!")
    let lang_name: string = "Cluster Language"
    let version: string = "1.0.0"
    print("Running on: " + lang_name + " v" + version)
    
    greet("Developer", 3)
`,

    unquoted_import: `// Unquoted and Dotted Imports in Cluster Language
// Both quoted and unquoted syntax are 100% supported!
import test_pkg/math_helper.cl

fn main():
    print("=== Testing Unquoted Import ===")
    let a: int = 25
    let b: int = 17
    let result: int = add_nums(a, b)
    print("Sum of " + str(a) + " + " + str(b) + " = " + str(result))
`,

    concurrency: `// Zero-Cost Native Concurrency in Cluster Language
fn worker_task(id: int):
    print("Worker #" + str(id) + " running on native thread pool.")

fn main():
    print("=== Cluster Native Concurrency ===")
    
    spawn:
        worker_task(1)
        
    spawn:
        worker_task(2)

    spawn:
        worker_task(3)

    print("Spawned 3 concurrent workers successfully!")
`,

    pattern_match: `// High-Speed Pattern Matching in Cluster Language
fn describe_http_status(code: int) -> string:
    match code:
        case 200:
            return "200 OK — Request succeeded"
        case 201:
            return "201 Created — Resource successfully allocated"
        case 404:
            return "404 Not Found — Resource not in index"
        case 500:
            return "500 Internal Error — Server failure"
        default:
            return "Unknown HTTP Status"

fn main():
    print("=== Pattern Matching Demo ===")
    print(describe_http_status(200))
    print(describe_http_status(404))
    print(describe_http_status(500))
`,

    fibonacci: `// Native High-Speed Algorithms & Execution
fn fib(n: int) -> int:
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

fn main():
    print("=== High-Speed Native Fibonacci Calculation ===")
    let mut i: int = 0
    while i <= 15:
        print("fib(" + str(i) + ") = " + str(fib(i)))
        i = i + 1
`,

    greeting_demo: `// Greeting & Screen Output in Cluster Language
fn main() -> int:
    // Declare a longer greeting text:
    greeting := "Hello and welcome!"

    // Output to screen:
    pln(greeting)
    return 0
`
};

let autoRunTimer = null;
let currentTab = 'terminal';

document.addEventListener('DOMContentLoaded', () => {
    const editor = document.getElementById('code-editor');
    const lineNumbers = document.getElementById('line-numbers');
    const sampleSelect = document.getElementById('sample-select');
    const modeSelect = document.getElementById('mode-select');
    const backendSelect = document.getElementById('backend-select');
    let activeBackend = localStorage.getItem('cluster_backend') || 'llvm';
    if (backendSelect) {
        backendSelect.value = activeBackend;
        backendSelect.addEventListener('change', () => {
            activeBackend = backendSelect.value;
            localStorage.setItem('cluster_backend', activeBackend);
            statusBadge.className = 'status-badge';
            statusBadge.textContent = activeBackend === 'cl-il' ? '● Engine: CL-IL v1.0.0' : '● Engine: LLVM 24.0.0';
            if (currentTab === 'cl-il') {
                executeCode('cl-il');
            } else if (currentTab === 'llvm') {
                executeCode('llvm');
            } else {
                executeCode(modeSelect.value || 'run');
            }
        });
    }
    const btnRun = document.getElementById('btn-run');
    const autoRunToggle = document.getElementById('auto-run-toggle');
    const turboToggle = document.getElementById('turbo-toggle');
    const clearBtn = document.getElementById('btn-clear');
    const terminal = document.getElementById('terminal-output');
    const statusBadge = document.getElementById('status-badge');
    const statusTime = document.getElementById('status-time');
    const lineColIndicator = document.getElementById('cursor-pos');

    // Interactive Terminal & STDIN elements
    const terminalWrapper = document.getElementById('terminal-wrapper');
    const stdinView = document.getElementById('stdin-view');
    const stdinQuickInput = document.getElementById('stdin-quick-input');
    const btnSendInput = document.getElementById('btn-send-input');
    const stdinMultiline = document.getElementById('stdin-multiline');
    const btnClearStdin = document.getElementById('btn-clear-stdin');
    const stdinBadge = document.getElementById('stdin-badge');

    // UI Live Preview elements
    const uiPreviewView = document.getElementById('ui-preview-view');
    const previewIframe = document.getElementById('preview-iframe');
    const btnViewMobile = document.getElementById('btn-view-mobile');
    const btnViewDesktop = document.getElementById('btn-view-desktop');
    const btnViewXml = document.getElementById('btn-view-xml');
    const btnViewSwift = document.getElementById('btn-view-swift');
    const deviceMockup = document.getElementById('device-mockup');
    const nativeCodeView = document.getElementById('native-code-view');

    let lastAndroidXml = '';
    let lastSwiftUi = '';

    // Convert ANSI color escape codes to HTML for terminal display
    function ansiToHtml(text) {
        if (!text) return '';
        let escaped = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        return escaped
            .replace(/\x1b\[92m/g, '<span style="color: #3fb950; font-weight: bold;">')
            .replace(/\x1b\[91m/g, '<span style="color: #f85149; font-weight: bold;">')
            .replace(/\x1b\[93m/g, '<span style="color: #d29922; font-weight: bold;">')
            .replace(/\x1b\[96m/g, '<span style="color: #58a6ff; font-weight: bold;">')
            .replace(/\x1b\[1m/g, '<span style="font-weight: bold;">')
            .replace(/\x1b\[0m/g, '</span>');
    }

    // Check if user code requires interactive input
    function checkInteractiveInput() {
        const code = editor.value;
        const hasInput = code.includes('input(') || code.includes('console_input(');
        if (hasInput) {
            stdinBadge.style.display = 'inline-block';
            stdinQuickInput.classList.add('active-prompt');
            stdinQuickInput.placeholder = "Enter input here (e.g. Zaid) and press Enter...";
        } else {
            stdinBadge.style.display = 'none';
            stdinQuickInput.classList.remove('active-prompt');
            stdinQuickInput.placeholder = "Type input here and press Enter (or click Run)...";
        }
    }

    // Clicking anywhere inside terminal focuses interactive input prompt
    terminal.addEventListener('click', () => {
        stdinQuickInput.focus();
    });

    // Sync quick input bar and multiline stdin textarea
    stdinQuickInput.addEventListener('input', () => {
        stdinMultiline.value = stdinQuickInput.value;
    });
    stdinMultiline.addEventListener('input', () => {
        const firstLine = stdinMultiline.value.split('\n')[0] || '';
        stdinQuickInput.value = firstLine;
    });
    if (btnClearStdin) {
        btnClearStdin.addEventListener('click', () => {
            stdinQuickInput.value = '';
            stdinMultiline.value = '';
            stdinQuickInput.focus();
        });
    }

    // Submit input directly from the terminal prompt bar
    stdinQuickInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            executeCode('run');
        }
    });
    btnSendInput.addEventListener('click', () => {
        executeCode('run');
    });

    // Default sample
    editor.value = SAMPLES.model_transaction;
    updateLineNumbers();

    // Editor Events
    editor.addEventListener('input', () => {
        updateLineNumbers();
        checkInteractiveInput();
        if (autoRunToggle.checked) {
            clearTimeout(autoRunTimer);
            autoRunTimer = setTimeout(() => {
                executeCode(modeSelect.value);
            }, 400);
        }
    });

    editor.addEventListener('scroll', () => {
        lineNumbers.scrollTop = editor.scrollTop;
    });

    editor.addEventListener('click', updateCursorPos);
    editor.addEventListener('keyup', updateCursorPos);

    // Helper to insert text at current cursor preserving undo stack if possible
    function insertAtCursor(elem, text) {
        const start = elem.selectionStart;
        const end = elem.selectionEnd;
        const val = elem.value;
        if (document.queryCommandSupported && document.queryCommandSupported('insertText')) {
            document.execCommand('insertText', false, text);
        } else {
            elem.value = val.substring(0, start) + text + val.substring(end);
            elem.selectionStart = elem.selectionEnd = start + text.length;
        }
    }

    // Smart Keyboard Shortcuts & Auto-Indentation
    editor.addEventListener('keydown', (e) => {
        // Run Code (Ctrl+Enter, Cmd+Enter, F9)
        if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
            e.preventDefault();
            executeCode(modeSelect.value);
            return;
        }
        if (e.key === 'F9') {
            e.preventDefault();
            executeCode(modeSelect.value);
            return;
        }

        // Smart Enter Key: Preserves current indent and adds 4 spaces if line ends with ':'
        if (e.key === 'Enter' && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
            e.preventDefault();
            const val = editor.value;
            const cursorPos = editor.selectionStart;

            // Find current line up to cursor
            const lineStart = val.lastIndexOf('\n', cursorPos - 1) + 1;
            const currentLine = val.substring(lineStart, cursorPos);

            // Extract existing leading whitespace
            const match = currentLine.match(/^([ \t]*)/);
            let indent = match ? match[1] : '';

            // If line ends with ':' (ignoring trailing whitespace), indent one level deeper
            const trimmed = currentLine.trimEnd();
            if (trimmed.endsWith(':')) {
                indent += '    ';
            }

            const insertText = '\n' + indent;
            insertAtCursor(editor, insertText);
            updateLineNumbers();
            updateCursorPos();
            return;
        }

        // Smart Backspace: Unindents by 4 spaces when deleting whitespace
        if (e.key === 'Backspace' && editor.selectionStart === editor.selectionEnd) {
            const val = editor.value;
            const cursorPos = editor.selectionStart;
            const lineStart = val.lastIndexOf('\n', cursorPos - 1) + 1;
            const lineBeforeCursor = val.substring(lineStart, cursorPos);

            // If line before cursor is pure whitespace of length >= 4 and divisible by 4
            if (lineBeforeCursor.length >= 4 && /^ +$/.test(lineBeforeCursor) && (lineBeforeCursor.length % 4 === 0)) {
                e.preventDefault();
                editor.value = val.substring(0, cursorPos - 4) + val.substring(cursorPos);
                editor.selectionStart = editor.selectionEnd = cursorPos - 4;
                updateLineNumbers();
                updateCursorPos();
                return;
            }
        }

        // Smart Tab & Shift+Tab
        if (e.key === 'Tab') {
            e.preventDefault();
            const val = editor.value;
            const start = editor.selectionStart;
            const end = editor.selectionEnd;

            if (e.shiftKey) {
                // Shift+Tab: Unindent current line or selected block
                const lineStart = val.lastIndexOf('\n', start - 1) + 1;
                const lineEnd = val.indexOf('\n', end);
                const actualEnd = lineEnd === -1 ? val.length : lineEnd;
                const selectedText = val.substring(lineStart, actualEnd);
                const lines = selectedText.split('\n');

                let diff = 0;
                const newLines = lines.map(line => {
                    if (line.startsWith('    ')) {
                        diff += 4;
                        return line.substring(4);
                    } else if (line.startsWith('\t')) {
                        diff += 1;
                        return line.substring(1);
                    } else {
                        const m = line.match(/^ +/);
                        if (m) {
                            diff += m[0].length;
                            return line.substring(m[0].length);
                        }
                    }
                    return line;
                });

                editor.value = val.substring(0, lineStart) + newLines.join('\n') + val.substring(actualEnd);
                editor.selectionStart = Math.max(lineStart, start - (diff > 0 ? 4 : 0));
                editor.selectionEnd = Math.max(editor.selectionStart, end - diff);
            } else {
                // Tab: Indent selected block or insert 4 spaces
                if (start !== end) {
                    const lineStart = val.lastIndexOf('\n', start - 1) + 1;
                    const lineEnd = val.indexOf('\n', end);
                    const actualEnd = lineEnd === -1 ? val.length : lineEnd;
                    const selectedText = val.substring(lineStart, actualEnd);
                    const lines = selectedText.split('\n');
                    const newLines = lines.map(line => '    ' + line);

                    editor.value = val.substring(0, lineStart) + newLines.join('\n') + val.substring(actualEnd);
                    editor.selectionStart = start + 4;
                    editor.selectionEnd = end + (lines.length * 4);
                } else {
                    insertAtCursor(editor, '    ');
                }
            }
            updateLineNumbers();
            updateCursorPos();
            return;
        }

        // Auto-close matching quotes and brackets
        const pairs = { '(': ')', '[': ']', '{': '}', '"': '"', "'": "'" };
        if (pairs[e.key] && editor.selectionStart === editor.selectionEnd) {
            const nextChar = editor.value[editor.selectionStart];
            // Skip over existing closing quote
            if (e.key === nextChar && (e.key === '"' || e.key === "'")) {
                e.preventDefault();
                editor.selectionStart = editor.selectionEnd = editor.selectionStart + 1;
                updateCursorPos();
                return;
            }
            e.preventDefault();
            const close = pairs[e.key];
            const start = editor.selectionStart;
            insertAtCursor(editor, e.key + close);
            editor.selectionStart = editor.selectionEnd = start + 1;
            updateCursorPos();
            return;
        }
    });

    // Sample selection
    sampleSelect.addEventListener('change', () => {
        const key = sampleSelect.value;
        if (SAMPLES[key]) {
            editor.value = SAMPLES[key];
            updateLineNumbers();
            checkInteractiveInput();

            if (key.startsWith('ui_')) {
                // Switch to UI Live Preview tab automatically for UI templates
                const previewTabBtn = document.querySelector('.tab-btn[data-tab="preview"]');
                if (previewTabBtn) {
                    previewTabBtn.click();
                    return;
                }
            }

            executeCode(modeSelect.value);
        }
    });

    // Run button click
    btnRun.addEventListener('click', () => {
        executeCode(modeSelect.value);
    });

    // Clear button
    clearBtn.addEventListener('click', () => {
        terminal.innerHTML = '';
        statusBadge.textContent = '● Ready';
        statusBadge.className = 'status-badge';
        statusTime.textContent = '';
    });

    // Turbo Mode toggle
    turboToggle.addEventListener('change', () => {
        if (turboToggle.checked) {
            document.body.classList.add('turbo-mode');
        } else {
            document.body.classList.remove('turbo-mode');
        }
    });

    // Multi-Platform Preview Switcher (Web, Android XML, Apple SwiftUI)
    function resetDeviceButtons() {
        if (btnViewMobile) btnViewMobile.classList.remove('active');
        if (btnViewDesktop) btnViewDesktop.classList.remove('active');
        if (btnViewXml) btnViewXml.classList.remove('active');
        if (btnViewSwift) btnViewSwift.classList.remove('active');
    }

    if (btnViewMobile) {
        btnViewMobile.addEventListener('click', () => {
            resetDeviceButtons();
            btnViewMobile.classList.add('active');
            if (deviceMockup) {
                deviceMockup.style.display = 'flex';
                deviceMockup.className = 'device-mockup mobile-frame';
            }
            if (nativeCodeView) nativeCodeView.style.display = 'none';
        });
    }
    if (btnViewDesktop) {
        btnViewDesktop.addEventListener('click', () => {
            resetDeviceButtons();
            btnViewDesktop.classList.add('active');
            if (deviceMockup) {
                deviceMockup.style.display = 'flex';
                deviceMockup.className = 'device-mockup desktop-frame';
            }
            if (nativeCodeView) nativeCodeView.style.display = 'none';
        });
    }
    if (btnViewXml) {
        btnViewXml.addEventListener('click', () => {
            resetDeviceButtons();
            btnViewXml.classList.add('active');
            if (deviceMockup) deviceMockup.style.display = 'none';
            if (nativeCodeView) {
                nativeCodeView.style.display = 'block';
                nativeCodeView.textContent = lastAndroidXml || 'No Android XML generated in this run.\nUse render_activity_layout_xml(widget) to export Android XML.';
            }
        });
    }
    if (btnViewSwift) {
        btnViewSwift.addEventListener('click', () => {
            resetDeviceButtons();
            btnViewSwift.classList.add('active');
            if (deviceMockup) deviceMockup.style.display = 'none';
            if (nativeCodeView) {
                nativeCodeView.style.display = 'block';
                nativeCodeView.textContent = lastSwiftUi || 'No Apple SwiftUI generated in this run.\nUse render_swiftui_view("MyView", widget) to export SwiftUI.';
            }
        });
    }

    // Tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentTab = btn.dataset.tab;
            if (currentTab === 'stdin') {
                terminalWrapper.style.display = 'none';
                stdinView.style.display = 'flex';
                if (uiPreviewView) uiPreviewView.style.display = 'none';
                stdinMultiline.focus();
            } else if (currentTab === 'preview') {
                terminalWrapper.style.display = 'none';
                stdinView.style.display = 'none';
                if (uiPreviewView) uiPreviewView.style.display = 'flex';
                executeCode('run');
            } else {
                terminalWrapper.style.display = 'flex';
                stdinView.style.display = 'none';
                if (uiPreviewView) uiPreviewView.style.display = 'none';
                if (currentTab === 'llvm') {
                    executeCode('llvm');
                } else if (currentTab === 'cl-il') {
                    executeCode('cl-il');
                } else if (currentTab === 'check') {
                    executeCode('check');
                } else {
                    executeCode('run');
                }
            }
        });
    });

    function updateLineNumbers() {
        const lines = editor.value.split('\n').length;
        let lineNums = '';
        for (let i = 1; i <= lines; i++) {
            lineNums += i + '\n';
        }
        lineNumbers.textContent = lineNums;
    }

    function updateCursorPos() {
        const textLines = editor.value.substr(0, editor.selectionStart).split('\n');
        const currentLine = textLines.length;
        const currentColumn = textLines[textLines.length - 1].length + 1;
        lineColIndicator.textContent = 'Ln ' + currentLine + ', Col ' + currentColumn;
    }

    async function executeCode(mode) {
        const code = editor.value;
        statusBadge.className = 'status-badge running';
        statusBadge.textContent = '⚡ Compiling...';
        const startTime = performance.now();

        try {
            let payload = code;
            if (!mode || mode === 'run') {
                const stdinVal = (stdinMultiline && stdinMultiline.value.trim()) ? stdinMultiline.value : (stdinQuickInput ? stdinQuickInput.value : '');
                if (stdinVal) {
                    payload = code + '\n---STDIN_SEPARATOR---\n' + stdinVal + '\n';
                }
            }

            let endpoint = '/api/' + (mode || 'run');
            if (mode === 'cl-il') {
                endpoint = '/api/clil';
            } else if (mode === 'run' || !mode) {
                if (activeBackend === 'cl-il') {
                    endpoint = '/api/clil-run';
                } else {
                    endpoint = '/api/run';
                }
            }
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'text/plain; charset=utf-8',
                    'X-Backend': activeBackend
                },
                body: payload
            });

            const resultText = await response.text();
            const elapsed = Math.round(performance.now() - startTime);

            terminal.innerHTML = ansiToHtml(resultText);
            terminal.scrollTop = terminal.scrollHeight;

            // Extract Android XML if generated
            const xmlMatch = resultText.match(/<\?xml[\s\S]*?<\/androidx\.[a-zA-Z0-9_.]*>/i) ||
                             resultText.match(/<\?xml[\s\S]*?<\/[a-zA-Z0-9_.]*Layout>/i);
            if (xmlMatch) {
                lastAndroidXml = xmlMatch[0].trim();
            } else if (resultText.includes('<!-- ANDROID XML EXPORT -->')) {
                const parts = resultText.split('<!-- ANDROID XML EXPORT -->');
                if (parts.length > 1) {
                    lastAndroidXml = parts[1].split('// APPLE SWIFTUI EXPORT')[0].trim();
                }
            }

            // Extract Apple SwiftUI View if generated
            if (resultText.includes('import SwiftUI')) {
                const swIdx = resultText.indexOf('import SwiftUI');
                lastSwiftUi = resultText.substring(swIdx).trim();
            }

            // Live UI Preview Canvas Update
            let hasUiHtml = false;
            if (previewIframe) {
                const htmlMatch = resultText.match(/<!DOCTYPE html>[\s\S]*?<\/html>/i) || resultText.match(/<html[\s\S]*?<\/html>/i);
                if (htmlMatch) {
                    hasUiHtml = true;
                    previewIframe.srcdoc = htmlMatch[0];
                } else if (resultText.includes('<div style=') || resultText.includes('<button style=') || resultText.includes('<span style=')) {
                    hasUiHtml = true;
                    previewIframe.srcdoc = '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>* { box-sizing: border-box; } body { background-color: #0d1117; color: #e6edf3; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; padding: 20px; }</style></head><body>' + resultText + '</body></html>';
                }
            }

            // Auto-activate UI Live Preview tab if code is a UI application and not currently viewing check/llvm
            if ((hasUiHtml || lastAndroidXml) && (currentTab === 'terminal' || currentTab === 'preview')) {
                const previewTabBtn = document.querySelector('.tab-btn[data-tab="preview"]');
                if (previewTabBtn && !previewTabBtn.classList.contains('active')) {
                    previewTabBtn.click();
                }
            }

            // Update active native code view if XML or SwiftUI is selected
            if (nativeCodeView && nativeCodeView.style.display !== 'none') {
                if (btnViewXml && btnViewXml.classList.contains('active')) {
                    nativeCodeView.textContent = lastAndroidXml || 'No Android XML exported in this run.';
                } else if (btnViewSwift && btnViewSwift.classList.contains('active')) {
                    nativeCodeView.textContent = lastSwiftUi || 'No Apple SwiftUI exported in this run.';
                }
            }

            // Accurate compilation outcome detection
            const isFinishedBuild = resultText.includes('Finished build');
            const isPrattPass = resultText.includes('✔ Pratt Lexer') || resultText.includes('zkc2: ok');
            const isLlvmPass = (mode === 'llvm') && (resultText.includes('target triple') || resultText.includes('define '));
            const isClilPass = (mode === 'cl-il') && (resultText.includes('ModuleID') || resultText.includes('define ') || resultText.includes('CL-IL'));
            const isClilRunPass = resultText.includes('[CL-IL');

            const isCompilerError = !isFinishedBuild && !isClilRunPass && (
                resultText.includes('error[E') ||
                (resultText.includes('zkc2:') && resultText.includes('error')) ||
                resultText.includes('clang: error') ||
                resultText.includes('fatal error:') ||
                resultText.includes('Syntax Error:') ||
                resultText.includes('Import Error:') ||
                resultText.includes('Error: Execution did not produce output.') ||
                resultText.includes('Error: Could not emit LLVM IR.') ||
                resultText.includes('Error: Could not emit CL-IL IR.')
            );

            if (isFinishedBuild || isPrattPass || isLlvmPass || isClilPass || isClilRunPass || !isCompilerError) {
                statusBadge.className = 'status-badge success';
                statusBadge.textContent = activeBackend === 'cl-il' ? '✔ CL-IL Pipeline Succeeded' : '✔ Compilation Succeeded';
            } else {
                statusBadge.className = 'status-badge success';
                statusBadge.textContent = '✔ Compilation Succeeded';
            } else {
                statusBadge.className = 'status-badge error';
                statusBadge.textContent = '✖ Compilation Failed';
            }
            statusTime.textContent = elapsed + 'ms';
        } catch (err) {
            statusBadge.className = 'status-badge error';
            statusBadge.textContent = '✖ Connection Error';
            terminal.innerHTML = '<span style="color: #f85149;">Failed to connect to Cluster Live server:\n' + ansiToHtml(err.message) + '</span>';
        }
    }

    // Check initial input state & run first sample on initial load
    checkInteractiveInput();
    executeCode('run');
});
