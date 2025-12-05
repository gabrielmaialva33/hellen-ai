/**
 * Sidebar Hook
 * Handles sidebar functionality:
 * - Collapse/expand state persistence
 * - Mobile drawer behavior with swipe gestures
 * - Keyboard shortcuts
 * - Smooth animations
 */
export const SidebarHook = {
  mounted() {
    this.sidebar = this.el
    this.overlay = document.getElementById('sidebar-overlay')
    this.collapsed = localStorage.getItem('sidebar-collapsed') === 'true'
    this.isMobile = window.innerWidth < 1024
    this.isOpen = false

    // Touch tracking for swipe gestures
    this.touchStartX = 0
    this.touchStartY = 0
    this.touchCurrentX = 0
    this.isDragging = false
    this.swipeThreshold = 100 // Minimum distance to trigger swipe

    // Apply saved state
    if (this.collapsed && !this.isMobile) {
      this.collapse()
    }

    // Handle resize events for responsive behavior
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener('resize', this.handleResize)

    // Handle escape key to close mobile sidebar
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.handleKeydown)

    // Setup swipe gestures for mobile
    this.setupSwipeGestures()
  },

  destroyed() {
    window.removeEventListener('resize', this.handleResize)
    document.removeEventListener('keydown', this.handleKeydown)
    this.removeSwipeGestures()
  },

  setupSwipeGestures() {
    // Swipe from left edge to open sidebar
    this.handleTouchStart = this.handleTouchStart.bind(this)
    this.handleTouchMove = this.handleTouchMove.bind(this)
    this.handleTouchEnd = this.handleTouchEnd.bind(this)

    document.addEventListener('touchstart', this.handleTouchStart, { passive: true })
    document.addEventListener('touchmove', this.handleTouchMove, { passive: false })
    document.addEventListener('touchend', this.handleTouchEnd, { passive: true })

    // Also handle swipe on sidebar itself to close
    this.sidebar.addEventListener('touchstart', this.handleSidebarTouchStart.bind(this), { passive: true })
    this.sidebar.addEventListener('touchmove', this.handleSidebarTouchMove.bind(this), { passive: false })
    this.sidebar.addEventListener('touchend', this.handleSidebarTouchEnd.bind(this), { passive: true })
  },

  removeSwipeGestures() {
    document.removeEventListener('touchstart', this.handleTouchStart)
    document.removeEventListener('touchmove', this.handleTouchMove)
    document.removeEventListener('touchend', this.handleTouchEnd)
  },

  handleTouchStart(e) {
    if (!this.isMobile) return

    const touch = e.touches[0]
    this.touchStartX = touch.clientX
    this.touchStartY = touch.clientY

    // Only trigger if starting from left edge (within 30px)
    if (touch.clientX <= 30 && !this.isOpen) {
      this.isDragging = true
      this.sidebar.style.transition = 'none'
    }
  },

  handleTouchMove(e) {
    if (!this.isDragging || !this.isMobile) return

    const touch = e.touches[0]
    this.touchCurrentX = touch.clientX
    const deltaX = this.touchCurrentX - this.touchStartX
    const deltaY = Math.abs(touch.clientY - this.touchStartY)

    // Only handle horizontal swipes
    if (deltaY > Math.abs(deltaX)) {
      this.isDragging = false
      return
    }

    e.preventDefault()

    // Calculate sidebar position (clamped between -256px and 0)
    const sidebarWidth = 256
    const translateX = Math.min(0, Math.max(-sidebarWidth, deltaX - sidebarWidth))

    this.sidebar.style.transform = `translateX(${translateX}px)`

    // Show overlay proportionally
    const progress = (translateX + sidebarWidth) / sidebarWidth
    if (this.overlay) {
      this.overlay.classList.remove('hidden')
      this.overlay.style.opacity = progress * 0.6
    }
  },

  handleTouchEnd(e) {
    if (!this.isDragging || !this.isMobile) return

    this.sidebar.style.transition = ''
    const deltaX = this.touchCurrentX - this.touchStartX

    if (deltaX >= this.swipeThreshold) {
      this.openMobile()
    } else {
      this.closeMobile()
    }

    this.isDragging = false
    this.sidebar.style.transform = ''
  },

  handleSidebarTouchStart(e) {
    if (!this.isMobile || !this.isOpen) return

    const touch = e.touches[0]
    this.sidebarTouchStartX = touch.clientX
  },

  handleSidebarTouchMove(e) {
    if (!this.isMobile || !this.isOpen) return

    const touch = e.touches[0]
    const deltaX = this.sidebarTouchStartX - touch.clientX

    if (deltaX > 0) {
      e.preventDefault()
      const sidebarWidth = 256
      const translateX = Math.max(-sidebarWidth, -deltaX)
      this.sidebar.style.transition = 'none'
      this.sidebar.style.transform = `translateX(${translateX}px)`

      // Fade overlay
      const progress = 1 - Math.abs(translateX) / sidebarWidth
      if (this.overlay) {
        this.overlay.style.opacity = progress * 0.6
      }
    }
  },

  handleSidebarTouchEnd(e) {
    if (!this.isMobile || !this.isOpen) return

    this.sidebar.style.transition = ''
    const rect = this.sidebar.getBoundingClientRect()

    if (rect.left < -100) {
      this.closeMobile()
    } else {
      this.sidebar.style.transform = ''
      if (this.overlay) {
        this.overlay.style.opacity = ''
      }
    }
  },

  openMobile() {
    this.sidebar.classList.remove('-translate-x-full')
    if (this.overlay) {
      this.overlay.classList.remove('hidden')
      this.overlay.style.opacity = ''
    }
    this.isOpen = true
    document.body.style.overflow = 'hidden'
  },

  closeMobile() {
    this.sidebar.classList.add('-translate-x-full')
    if (this.overlay) {
      this.overlay.classList.add('hidden')
      this.overlay.style.opacity = ''
    }
    this.isOpen = false
    document.body.style.overflow = ''
    this.sidebar.style.transform = ''
  },

  collapse() {
    this.sidebar.classList.add('sidebar-collapsed')
    document.body.classList.add('sidebar-collapsed')
    localStorage.setItem('sidebar-collapsed', 'true')
    this.collapsed = true
  },

  expand() {
    this.sidebar.classList.remove('sidebar-collapsed')
    document.body.classList.remove('sidebar-collapsed')
    localStorage.setItem('sidebar-collapsed', 'false')
    this.collapsed = false
  },

  toggle() {
    if (this.collapsed) {
      this.expand()
    } else {
      this.collapse()
    }
  },

  handleResize() {
    const wasMobile = this.isMobile
    this.isMobile = window.innerWidth < 1024

    // Transitioning from mobile to desktop
    if (wasMobile && !this.isMobile && this.isOpen) {
      this.closeMobile()
    }

    // Auto-collapse on tablet sizes
    if (window.innerWidth < 1024 && window.innerWidth >= 768) {
      if (!this.collapsed) {
        this.collapse()
      }
    }
  },

  handleKeydown(e) {
    // Escape key closes mobile sidebar
    if (e.key === 'Escape' && this.isOpen) {
      this.closeMobile()
    }
  }
}

/**
 * Search Modal Hook
 * Handles global search functionality:
 * - Cmd+K / Ctrl+K shortcut
 * - Escape to close
 * - Focus management
 * - Search as you type
 */
export const SearchModal = {
  mounted() {
    this.modal = this.el
    this.input = document.getElementById('search-input')
    this.results = document.getElementById('search-results')
    this.isOpen = false
    this.searchTimeout = null

    // Keyboard shortcut for opening search
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.handleKeydown)

    // Custom event for opening search from sidebar button
    this.handleOpenSearch = this.handleOpenSearch.bind(this)
    window.addEventListener('open-search', this.handleOpenSearch)

    // Input handling
    if (this.input) {
      this.input.addEventListener('input', (e) => this.handleSearch(e.target.value))
    }

    // Close on overlay click
    const overlay = this.modal.querySelector('[aria-hidden="true"]')
    if (overlay) {
      overlay.addEventListener('click', () => this.close())
    }
  },

  destroyed() {
    document.removeEventListener('keydown', this.handleKeydown)
    window.removeEventListener('open-search', this.handleOpenSearch)
  },

  handleKeydown(e) {
    // Cmd+K or Ctrl+K to open search
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault()
      this.toggle()
    }

    // Escape to close
    if (e.key === 'Escape' && this.isOpen) {
      e.preventDefault()
      this.close()
    }
  },

  handleOpenSearch() {
    this.open()
  },

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  },

  open() {
    this.modal.classList.remove('hidden')
    this.isOpen = true

    // Focus input after animation
    setTimeout(() => {
      if (this.input) {
        this.input.focus()
        this.input.select()
      }
    }, 100)

    // Add animation class
    this.modal.classList.add('animate-fade-in')

    // Prevent body scroll
    document.body.style.overflow = 'hidden'
  },

  close() {
    this.modal.classList.add('hidden')
    this.modal.classList.remove('animate-fade-in')
    this.isOpen = false

    // Clear input
    if (this.input) {
      this.input.value = ''
    }

    // Reset results
    this.resetResults()

    // Restore body scroll
    document.body.style.overflow = ''
  },

  handleSearch(query) {
    // Debounce search
    clearTimeout(this.searchTimeout)

    if (!query || query.length < 2) {
      this.resetResults()
      return
    }

    this.searchTimeout = setTimeout(() => {
      // Show loading state
      this.showLoading()

      // Push event to LiveView for server-side search
      this.pushEvent('global_search', { query }, (reply) => {
        this.renderResults(reply.results || [])
      })
    }, 300)
  },

  showLoading() {
    if (this.results) {
      this.results.innerHTML = `
        <div class="px-3 py-8 text-center">
          <div class="inline-flex items-center gap-2 text-slate-400">
            <svg class="h-5 w-5 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span class="text-sm">Buscando...</span>
          </div>
        </div>
      `
    }
  },

  resetResults() {
    if (this.results) {
      this.results.innerHTML = `
        <div class="px-3 py-8 text-center text-slate-400">
          <svg class="h-12 w-12 mx-auto mb-3 text-slate-300 dark:text-slate-600" fill="none" viewBox="0 0 24 24" stroke-width="1" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <p class="text-sm">Digite para buscar...</p>
        </div>
      `
    }
  },

  renderResults(results) {
    if (!this.results) return

    if (results.length === 0) {
      this.results.innerHTML = `
        <div class="px-3 py-8 text-center text-slate-400">
          <svg class="h-12 w-12 mx-auto mb-3 text-slate-300 dark:text-slate-600" fill="none" viewBox="0 0 24 24" stroke-width="1" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p class="text-sm">Nenhum resultado encontrado</p>
        </div>
      `
      return
    }

    const html = results.map(result => `
      <a
        href="${result.url}"
        class="flex items-center gap-3 px-3 py-3 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors group"
      >
        <div class="flex-shrink-0 w-10 h-10 rounded-lg ${this.getTypeColor(result.type)} flex items-center justify-center">
          ${this.getTypeIcon(result.type)}
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-slate-900 dark:text-white truncate group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">
            ${result.title}
          </p>
          <p class="text-xs text-slate-500 dark:text-slate-400 truncate">
            ${result.subtitle || ''}
          </p>
        </div>
        <svg class="h-4 w-4 text-slate-400 opacity-0 group-hover:opacity-100 transition-opacity" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
        </svg>
      </a>
    `).join('')

    this.results.innerHTML = html
  },

  getTypeColor(type) {
    const colors = {
      lesson: 'bg-teal-500/10 dark:bg-teal-500/20',
      analysis: 'bg-sage-500/10 dark:bg-sage-500/20',
      alert: 'bg-violet-500/10 dark:bg-violet-500/20',
      user: 'bg-ochre-500/10 dark:bg-ochre-500/20'
    }
    return colors[type] || 'bg-slate-100 dark:bg-slate-800'
  },

  getTypeIcon(type) {
    const icons = {
      lesson: `<svg class="h-5 w-5 text-teal-600 dark:text-teal-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.26 10.147a60.436 60.436 0 00-.491 6.347A48.627 48.627 0 0112 20.904a48.627 48.627 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.57 50.57 0 00-2.658-.813A59.905 59.905 0 0112 3.493a59.902 59.902 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.697 50.697 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5" />
      </svg>`,
      analysis: `<svg class="h-5 w-5 text-sage-600 dark:text-sage-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5M9 11.25v1.5M12 9v3.75m3-6v6" />
      </svg>`,
      alert: `<svg class="h-5 w-5 text-violet-600 dark:text-violet-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0" />
      </svg>`,
      user: `<svg class="h-5 w-5 text-ochre-600 dark:text-ochre-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
      </svg>`
    }
    return icons[type] || icons.lesson
  }
}
