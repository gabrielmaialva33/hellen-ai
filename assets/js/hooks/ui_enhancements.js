/**
 * UI Enhancement Hooks for LiveView
 * Micro-interactions, animated counters, drag-drop, and ripple effects
 */

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

/**
 * DropZone Hook
 * Enhanced drag-and-drop file upload with visual feedback
 */
export const DropZone = {
  mounted() {
    this.el.addEventListener("dragenter", this.handleDragEnter.bind(this))
    this.el.addEventListener("dragleave", this.handleDragLeave.bind(this))
    this.el.addEventListener("dragover", this.handleDragOver.bind(this))
    this.el.addEventListener("drop", this.handleDrop.bind(this))

    // Click to open file dialog
    this.el.addEventListener("click", (e) => {
      if (e.target.tagName !== "INPUT") {
        const input = this.el.querySelector("input[type='file']")
        if (input) input.click()
      }
    })

    this.dragCounter = 0
  },

  handleDragEnter(e) {
    e.preventDefault()
    e.stopPropagation()
    this.dragCounter++

    if (this.dragCounter === 1) {
      this.el.classList.add(
        "border-teal-500",
        "bg-teal-50",
        "dark:bg-teal-900/20",
        "scale-[1.02]"
      )
      this.el.classList.remove(
        "border-slate-300",
        "dark:border-slate-600"
      )
    }
  },

  handleDragLeave(e) {
    e.preventDefault()
    e.stopPropagation()
    this.dragCounter--

    if (this.dragCounter === 0) {
      this.resetStyles()
    }
  },

  handleDragOver(e) {
    e.preventDefault()
    e.stopPropagation()
  },

  handleDrop(e) {
    e.preventDefault()
    e.stopPropagation()
    this.dragCounter = 0
    this.resetStyles()

    // Add drop animation
    this.el.classList.add("animate-bounce-subtle")
    setTimeout(() => {
      this.el.classList.remove("animate-bounce-subtle")
    }, 500)
  },

  resetStyles() {
    this.el.classList.remove(
      "border-teal-500",
      "bg-teal-50",
      "dark:bg-teal-900/20",
      "scale-[1.02]"
    )
    this.el.classList.add(
      "border-slate-300",
      "dark:border-slate-600"
    )
  },

  destroyed() {
    this.el.removeEventListener("dragenter", this.handleDragEnter)
    this.el.removeEventListener("dragleave", this.handleDragLeave)
    this.el.removeEventListener("dragover", this.handleDragOver)
    this.el.removeEventListener("drop", this.handleDrop)
  }
}

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

/**
 * TypeWriter Hook
 * Types text character by character
 */
export const TypeWriter = {
  mounted() {
    this.text = this.el.dataset.text || this.el.textContent
    this.speed = parseInt(this.el.dataset.speed) || 50
    this.delay = parseInt(this.el.dataset.delay) || 0

    this.el.textContent = ""

    setTimeout(() => {
      this.typeText()
    }, this.delay)
  },

  typeText() {
    let i = 0
    const type = () => {
      if (i < this.text.length) {
        this.el.textContent += this.text.charAt(i)
        i++
        setTimeout(type, this.speed)
      }
    }
    type()
  }
}

/**
 * IntersectionObserver Hook
 * Triggers animations when element enters viewport
 */
export const AnimateOnScroll = {
  mounted() {
    const animation = this.el.dataset.animation || "fade-in-up"
    const delay = this.el.dataset.delay || "0"
    const threshold = parseFloat(this.el.dataset.threshold) || 0.1

    // Initially hide
    this.el.style.opacity = "0"

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          setTimeout(() => {
            this.el.style.opacity = "1"
            this.el.classList.add(`animate-${animation}`)
          }, parseInt(delay))
          observer.unobserve(this.el)
        }
      })
    }, { threshold })

    observer.observe(this.el)
    this.observer = observer
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

/**
 * Parallax Hook
 * Simple parallax scrolling effect
 */
export const Parallax = {
  mounted() {
    this.speed = parseFloat(this.el.dataset.speed) || 0.5
    this.handleScroll = this.handleScroll.bind(this)

    window.addEventListener("scroll", this.handleScroll, { passive: true })
    this.handleScroll()
  },

  handleScroll() {
    const scrolled = window.pageYOffset
    const rect = this.el.getBoundingClientRect()
    const offset = (rect.top + scrolled) - scrolled

    if (rect.top < window.innerHeight && rect.bottom > 0) {
      const yPos = -((scrolled - offset) * this.speed)
      this.el.style.transform = `translateY(${yPos}px)`
    }
  },

  destroyed() {
    window.removeEventListener("scroll", this.handleScroll)
  }
}

/**
 * ProgressiveImage Hook
 * Loads low-res placeholder then high-res image
 */
export const ProgressiveImage = {
  mounted() {
    const fullSrc = this.el.dataset.src
    const placeholder = this.el.dataset.placeholder

    if (placeholder) {
      this.el.src = placeholder
      this.el.classList.add("blur-sm", "scale-105")
    }

    const fullImage = new Image()
    fullImage.src = fullSrc

    fullImage.onload = () => {
      this.el.src = fullSrc
      this.el.classList.remove("blur-sm", "scale-105")
      this.el.classList.add("transition-all", "duration-500")
    }
  }
}

/**
 * CopyToClipboard Hook
 * Copies text to clipboard with visual feedback
 */
export const CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", this.handleCopy.bind(this))
  },

  handleCopy() {
    const text = this.el.dataset.copyText || this.el.textContent

    navigator.clipboard.writeText(text).then(() => {
      // Visual feedback
      const originalContent = this.el.innerHTML
      const originalTitle = this.el.title

      this.el.classList.add("text-emerald-500")
      this.el.title = "Copiado!"

      // Add check icon temporarily
      const checkIcon = document.createElement("span")
      checkIcon.innerHTML = "&#10003;"
      checkIcon.classList.add("ml-1")
      this.el.appendChild(checkIcon)

      setTimeout(() => {
        this.el.classList.remove("text-emerald-500")
        this.el.title = originalTitle
        checkIcon.remove()
      }, 2000)
    })
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleCopy)
  }
}
