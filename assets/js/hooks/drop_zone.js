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
    this.dragCounter--

    if (this.dragCounter === 0) {
      this.resetStyles()
    }
  },

  handleDragOver(e) {
    e.preventDefault()
  },

  handleDrop(e) {
    e.preventDefault()
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
