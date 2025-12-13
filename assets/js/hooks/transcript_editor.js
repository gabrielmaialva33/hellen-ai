/**
 * TranscriptEditor Hook
 * Provides text selection, annotation, and citation scroll functionality for transcriptions
 * Inspired by Google NotebookLM's source-grounded citations
 */
export const TranscriptEditor = {
  mounted() {
    this.container = this.el.querySelector('[data-transcript-text]')
    this.tooltip = this.el.querySelector('[data-annotation-tooltip]')
    this.currentSelection = null

    if (this.container) {
      this.container.addEventListener('mouseup', this.handleSelection.bind(this))
      document.addEventListener('mousedown', this.handleClickOutside.bind(this))
    }

    // Handle click on highlighted annotations
    this.el.addEventListener('click', (e) => {
      const mark = e.target.closest('mark[data-annotation-id]')
      if (mark) {
        const annotationId = mark.dataset.annotationId
        this.pushEvent('show_annotation', { id: annotationId })
      }
    })

    // Handle add comment button click
    const addCommentBtn = this.el.querySelector('[data-add-comment]')
    if (addCommentBtn) {
      addCommentBtn.addEventListener('click', () => this.addComment())
    }

    // Listen for citation scroll events from LiveView (NotebookLM-style)
    this.handleEvent("scroll-to-evidence", ({ text }) => {
      this.scrollToEvidence(text)
    })
  },

  destroyed() {
    document.removeEventListener('mousedown', this.handleClickOutside.bind(this))
  },

  handleSelection(e) {
    const selection = window.getSelection()

    if (selection.rangeCount === 0 || selection.isCollapsed) {
      this.hideTooltip()
      return
    }

    const range = selection.getRangeAt(0)
    const text = selection.toString().trim()

    if (!text || text.length < 3) {
      this.hideTooltip()
      return
    }

    // Calculate offsets relative to container
    const preCaretRange = range.cloneRange()
    preCaretRange.selectNodeContents(this.container)
    preCaretRange.setEnd(range.startContainer, range.startOffset)
    const start = preCaretRange.toString().length
    const end = start + text.length

    this.showTooltip(e, { start, end, text })
  },

  handleClickOutside(e) {
    if (!this.tooltip) return

    const isTooltipClick = this.tooltip.contains(e.target)
    const isContainerClick = this.container && this.container.contains(e.target)

    if (!isTooltipClick && !isContainerClick) {
      this.hideTooltip()
    }
  },

  showTooltip(e, selection) {
    if (!this.tooltip) return

    this.currentSelection = selection

    // Position tooltip near the selection
    const rect = this.container.getBoundingClientRect()
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop
    const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft

    // Calculate position relative to viewport then add scroll offset
    let left = e.clientX + scrollLeft - 60
    let top = e.clientY + scrollTop - 50

    // Keep tooltip within viewport bounds
    const tooltipWidth = 180
    const viewportWidth = window.innerWidth
    if (left + tooltipWidth > viewportWidth + scrollLeft) {
      left = viewportWidth + scrollLeft - tooltipWidth - 10
    }
    if (left < scrollLeft + 10) {
      left = scrollLeft + 10
    }

    this.tooltip.style.display = 'block'
    this.tooltip.style.position = 'absolute'
    this.tooltip.style.left = `${left}px`
    this.tooltip.style.top = `${top}px`
  },

  hideTooltip() {
    if (this.tooltip) {
      this.tooltip.style.display = 'none'
    }
    this.currentSelection = null
  },

  addComment() {
    if (!this.currentSelection) return

    this.pushEvent('open_annotation_modal', {
      start: this.currentSelection.start,
      end: this.currentSelection.end,
      text: this.currentSelection.text
    })

    this.hideTooltip()
    window.getSelection().removeAllRanges()
  },

  /**
   * Scroll to and highlight evidence text in the transcript (NotebookLM-style citation)
   * @param {string} searchText - The text to find and highlight
   */
  scrollToEvidence(searchText) {
    if (!this.container || !searchText) return

    // Remove any existing temporary highlight
    const existingHighlight = document.getElementById('temp-citation-highlight')
    if (existingHighlight && existingHighlight.parentNode) {
      const text = document.createTextNode(existingHighlight.textContent)
      existingHighlight.parentNode.replaceChild(text, existingHighlight)
      existingHighlight.parentNode.normalize()
    }

    const fullText = this.container.textContent
    const textIndex = fullText.indexOf(searchText)

    if (textIndex === -1) {
      // Fallback: scroll to container if text not found
      this.container.scrollIntoView({ behavior: 'smooth', block: 'center' })
      return
    }

    // Find the text node at the given index
    const result = this.findTextNodeAtIndex(this.container, textIndex, searchText.length)
    if (!result) {
      this.container.scrollIntoView({ behavior: 'smooth', block: 'center' })
      return
    }

    const { node, offset } = result

    try {
      // Create range for the text
      const range = document.createRange()
      range.setStart(node, offset)

      // Calculate end position, potentially spanning multiple text nodes
      let remainingLength = searchText.length
      let currentNode = node
      let currentOffset = offset

      while (remainingLength > 0 && currentNode) {
        const availableLength = currentNode.textContent.length - currentOffset
        if (availableLength >= remainingLength) {
          range.setEnd(currentNode, currentOffset + remainingLength)
          remainingLength = 0
        } else {
          remainingLength -= availableLength
          // Move to next text node
          const walker = document.createTreeWalker(this.container, NodeFilter.SHOW_TEXT)
          walker.currentNode = currentNode
          currentNode = walker.nextNode()
          currentOffset = 0
        }
      }

      // Create temporary highlight element
      const tempMark = document.createElement('mark')
      tempMark.className = 'bg-teal-300 dark:bg-teal-700 transition-all duration-500 rounded px-0.5 ring-2 ring-teal-400 dark:ring-teal-500'
      tempMark.id = 'temp-citation-highlight'

      range.surroundContents(tempMark)
      tempMark.scrollIntoView({ behavior: 'smooth', block: 'center' })

      // Remove highlight after 3 seconds with fade effect
      setTimeout(() => {
        const mark = document.getElementById('temp-citation-highlight')
        if (mark && mark.parentNode) {
          mark.classList.add('opacity-0')
          setTimeout(() => {
            if (mark.parentNode) {
              const textNode = document.createTextNode(mark.textContent)
              mark.parentNode.replaceChild(textNode, mark)
              mark.parentNode.normalize()
            }
          }, 300)
        }
      }, 2700)
    } catch (e) {
      console.warn('Citation highlight failed:', e)
      // Fallback: just scroll to container
      this.container.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  },

  /**
   * Find the text node containing the character at targetIndex
   * @param {Element} element - The container element
   * @param {number} targetIndex - The character index to find
   * @returns {{ node: Text, offset: number } | null}
   */
  findTextNodeAtIndex(element, targetIndex) {
    let currentIndex = 0
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT)

    while (walker.nextNode()) {
      const node = walker.currentNode
      const nodeLength = node.textContent.length

      if (currentIndex + nodeLength > targetIndex) {
        return { node, offset: targetIndex - currentIndex }
      }
      currentIndex += nodeLength
    }
    return null
  }
}
