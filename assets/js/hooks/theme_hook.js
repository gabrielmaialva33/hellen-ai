export const ThemeHook = {
  mounted() {
    // Check saved preference or system preference
    const savedTheme = localStorage.getItem("theme")
    const systemDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    const theme = savedTheme || (systemDark ? "dark" : "light")

    this.applyTheme(theme)

    // Listen for click events to toggle theme
    this.el.addEventListener("click", (e) => {
      // Only toggle if clicking on the element itself or a button within it
      if (e.target === this.el || e.target.closest("button")) {
        const isDark = document.documentElement.classList.contains("dark")
        this.applyTheme(isDark ? "light" : "dark")
      }
    })

    // Listen for toggle events from server
    this.handleEvent("toggle-theme", () => {
      const isDark = document.documentElement.classList.contains("dark")
      this.applyTheme(isDark ? "light" : "dark")
    })

    // Listen for system preference changes
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
      if (!localStorage.getItem("theme")) {
        this.applyTheme(e.matches ? "dark" : "light")
      }
    })
  },

  applyTheme(theme) {
    document.documentElement.classList.toggle("dark", theme === "dark")
    localStorage.setItem("theme", theme)
    // Dispatch event for other components
    window.dispatchEvent(new CustomEvent("theme-changed", { detail: { theme } }))
  }
}
