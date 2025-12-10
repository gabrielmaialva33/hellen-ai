/**
 * UI Animation Hooks
 * Miscellaneous animation and interaction hooks
 */

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
