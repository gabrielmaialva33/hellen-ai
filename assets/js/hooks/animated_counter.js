/**
 * AnimatedCounter Hook
 * Animates a number from 0 to target value with easing
 */
export const AnimatedCounter = {
  mounted() {
    this.animateCounter()
    this.handleEvent("update_counter", ({ value }) => {
      this.el.dataset.target = value
      this.animateCounter()
    })
  },

  animateCounter() {
    const target = parseFloat(this.el.dataset.target) || 0
    const duration = parseInt(this.el.dataset.duration) || 1500
    const prefix = this.el.dataset.prefix || ""
    const suffix = this.el.dataset.suffix || ""
    const counterEl = this.el.querySelector(".counter-value")

    if (!counterEl) return

    const isFloat = target % 1 !== 0
    const decimals = isFloat ? 1 : 0
    let startTime = null
    const startValue = parseFloat(counterEl.textContent) || 0

    const easeOutQuart = (t) => 1 - Math.pow(1 - t, 4)

    const animate = (currentTime) => {
      if (!startTime) startTime = currentTime
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      const easedProgress = easeOutQuart(progress)

      const currentValue = startValue + (target - startValue) * easedProgress
      counterEl.textContent = currentValue.toFixed(decimals)

      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }

    requestAnimationFrame(animate)
  }
}
