// Phoenix LiveView JavaScript
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// LiveView Hooks
let Hooks = {}

// Landing page hooks
import { ScrollAnimation, ThemeHook, ThemeToggle } from "./hooks/scroll_animation"
Hooks.ScrollAnimation = ScrollAnimation
Hooks.ThemeHook = ThemeHook
Hooks.ThemeToggle = ThemeToggle

// Chart hooks
import { ScoreChart, BnccHeatmap, AlertsChart, CoordinatorBarChart, AnalyticsChart } from "./hooks/charts"
Hooks.ScoreChart = ScoreChart
Hooks.BnccHeatmap = BnccHeatmap
Hooks.AlertsChart = AlertsChart
Hooks.CoordinatorBarChart = CoordinatorBarChart
Hooks.AnalyticsChart = AnalyticsChart

// PWA hooks
import { registerServiceWorker, InstallPrompt, OfflineIndicator, UpdateAvailable } from "./hooks/pwa"
Hooks.InstallPrompt = InstallPrompt
Hooks.OfflineIndicator = OfflineIndicator
Hooks.UpdateAvailable = UpdateAvailable
registerServiceWorker()

// Firebase Authentication hooks
import { GoogleSignIn } from "./hooks/firebase"
Hooks.GoogleSignIn = GoogleSignIn

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#4f46e5"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Expose liveSocket on window for debugging
window.liveSocket = liveSocket
