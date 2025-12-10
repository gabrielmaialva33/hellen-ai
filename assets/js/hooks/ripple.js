/**
 * Ripple Hook
 * Material-style ripple effect on click
 */
export const Ripple = {
  mounted() {
    this.el.style.position = "relative"
    this.el.style.overflow = "hidden"

    this.el.addEventListener("click", this.createRipple.bind(this))
  },

  createRipple(e) {
    const button = this.el
    const circle = document.createElement("span")
    const diameter = Math.max(button.clientWidth, button.clientHeight)
    const radius = diameter / 2

    const rect = button.getBoundingClientRect()

    circle.style.width = circle.style.height = `${diameter}px`
    circle.style.left = `${e.clientX - rect.left - radius}px`
    circle.style.top = `${e.clientY - rect.top - radius}px`
    circle.classList.add("ripple")

    // Add ripple styles if not already in document
    if (!document.getElementById("ripple-styles")) {
      const style = document.createElement("style")
      style.id = "ripple-styles"
      style.textContent = `
        .ripple {
          position: absolute;
          border-radius: 50%;
          transform: scale(0);
          animation: ripple-animation 0.6s ease-out;
          background-color: rgba(255, 255, 255, 0.3);
          pointer-events: none;
        }

        @keyframes ripple-animation {
          to {
            transform: scale(4);
            opacity: 0;
            opacity: 0;
          }
        }
      `
      document.head.appendChild(style)
    }

    const existingRipple = button.querySelector(".ripple")
    if (existingRipple) {
      existingRipple.remove()
    }

    button.appendChild(circle)

    // Remove ripple after animation
    setTimeout(() => {
      circle.remove()
    }, 600)
  },

  destroyed() {
    this.el.removeEventListener("click", this.createRipple)
  }
}
