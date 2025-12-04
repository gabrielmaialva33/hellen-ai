/**
 * ChartHook - ApexCharts integration for Phoenix LiveView
 *
 * Handles chart rendering, updates, and theme changes.
 */
const ChartHook = {
  mounted() {
    this.chart = null
    this.initChart()

    // Handle data updates from server
    this.handleEvent("chart-update", ({ series }) => {
      if (this.chart) {
        this.chart.updateSeries(series)
      }
    })

    // Handle options updates
    this.handleEvent("chart-options", ({ options }) => {
      if (this.chart) {
        this.chart.updateOptions(options)
      }
    })

    // Listen for theme changes (if theme switching is implemented)
    window.addEventListener("theme-changed", (e) => {
      this.updateTheme(e.detail.theme)
    })
  },

  updated() {
    // Re-render if data attribute changed
    const newOptions = this.el.dataset.chartOptions
    if (newOptions !== this.currentOptions) {
      this.currentOptions = newOptions
      this.initChart()
    }
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  initChart() {
    if (this.chart) {
      this.chart.destroy()
    }

    const optionsStr = this.el.dataset.chartOptions
    if (!optionsStr) return

    try {
      const options = JSON.parse(optionsStr)
      this.currentOptions = optionsStr

      // Apply theme-aware defaults
      const isDark = document.documentElement.classList.contains("dark")
      const themedOptions = this.applyTheme(options, isDark)

      this.chart = new ApexCharts(this.el, themedOptions)
      this.chart.render()
    } catch (e) {
      console.error("ChartHook: Failed to parse options", e)
    }
  },

  updateTheme(theme) {
    if (!this.chart) return

    const isDark = theme === "dark"
    this.chart.updateOptions({
      theme: { mode: isDark ? 'dark' : 'light' },
      chart: {
        background: 'transparent',
        foreColor: isDark ? '#e2e8f0' : '#334155'
      },
      grid: {
        borderColor: isDark ? '#334155' : '#e2e8f0'
      }
    })
  },

  applyTheme(options, isDark) {
    return {
      ...options,
      theme: { mode: isDark ? 'dark' : 'light' },
      chart: {
        ...options.chart,
        background: 'transparent',
        foreColor: isDark ? '#e2e8f0' : '#334155',
        toolbar: {
          show: options.chart?.toolbar?.show ?? false
        },
        fontFamily: 'Inter, system-ui, sans-serif'
      },
      grid: {
        ...options.grid,
        borderColor: isDark ? '#334155' : '#e2e8f0'
      }
    }
  }
}

export default ChartHook
