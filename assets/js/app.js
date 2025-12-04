// Phoenix LiveView JavaScript
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// External Uploaders for direct S3/R2 uploads
let Uploaders = {}

// S3/R2 Direct Upload - uploads directly to storage without going through Phoenix
Uploaders.S3 = function(entries, onViewError) {
  console.log("S3 Uploader called with", entries.length, "entries")
  entries.forEach(entry => {
    console.log("Starting upload for:", entry.file.name, "URL:", entry.meta.url)
    let xhr = new XMLHttpRequest()
    onViewError(() => xhr.abort())

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        entry.progress(100)
      } else {
        console.error("Upload failed:", xhr.status, xhr.statusText)
        entry.error()
      }
    }

    xhr.onerror = () => {
      console.error("Upload error")
      entry.error()
    }

    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100)
        if (percent < 100) {
          entry.progress(percent)
        }
      }
    })

    // Use the presigned URL from the meta
    xhr.open("PUT", entry.meta.url, true)
    xhr.setRequestHeader("Content-Type", entry.file.type)
    xhr.send(entry.file)
  })
}

// LiveView Hooks
let Hooks = {}

// Upload progress hook
Hooks.UploadProgress = {
  mounted() {
    this.handleEvent("upload_progress", ({progress}) => {
      this.el.style.width = `${progress}%`
    })
  }
}

// Auto-scroll to bottom (for logs/transcriptions)
Hooks.AutoScroll = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight
  },
  updated() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

// Copy to clipboard
Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const text = this.el.dataset.copy
      navigator.clipboard.writeText(text).then(() => {
        this.pushEvent("copied", {})
      })
    })
  }
}

// File drop zone
Hooks.DropZone = {
  mounted() {
    this.el.addEventListener("dragover", (e) => {
      e.preventDefault()
      this.el.classList.add("dropzone-active")
    })

    this.el.addEventListener("dragleave", (e) => {
      e.preventDefault()
      this.el.classList.remove("dropzone-active")
    })

    this.el.addEventListener("drop", (e) => {
      e.preventDefault()
      this.el.classList.remove("dropzone-active")

      const files = e.dataTransfer.files
      if (files.length > 0) {
        // Trigger LiveView upload
        const input = this.el.querySelector('input[type="file"]')
        if (input) {
          input.files = files
          input.dispatchEvent(new Event('change', { bubbles: true }))
        }
      }
    })
  }
}

// Real-time status updates
Hooks.StatusUpdater = {
  mounted() {
    this.handleEvent("status_update", ({status, message}) => {
      this.el.dataset.status = status
      if (message) {
        const msgEl = this.el.querySelector('.status-message')
        if (msgEl) {
          msgEl.textContent = message
        }
      }
    })
  }
}

// LiveSocket setup
let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  uploaders: Uploaders,
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
