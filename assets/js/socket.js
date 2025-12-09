// UserSocket client for real-time lesson updates
// This is used for WebSocket connections outside of LiveView (API/mobile clients)
import { Socket } from "phoenix"

let socket = null
let lessonChannels = {}

/**
 * Initialize the UserSocket connection with a JWT token
 * @param {string} token - JWT authentication token
 */
export function connectSocket(token) {
  if (socket && socket.isConnected()) {
    return socket
  }

  socket = new Socket("/socket", {
    params: { token: token }
  })

  socket.onError(() => console.error("[Socket] Connection error"))
  socket.onClose(() => console.log("[Socket] Connection closed"))

  socket.connect()
  console.log("[Socket] Connected")

  return socket
}

/**
 * Disconnect the socket
 */
export function disconnectSocket() {
  if (socket) {
    socket.disconnect()
    socket = null
    lessonChannels = {}
  }
}

/**
 * Join a lesson channel to receive real-time updates
 * @param {string} lessonId - The lesson UUID
 * @param {object} callbacks - Event callbacks
 * @param {function} callbacks.onTranscriptionComplete - Called when transcription finishes
 * @param {function} callbacks.onTranscriptionFailed - Called when transcription fails
 * @param {function} callbacks.onAnalysisComplete - Called when analysis finishes
 * @param {function} callbacks.onAnalysisFailed - Called when analysis fails
 * @param {function} callbacks.onStatusUpdate - Called on any status change
 */
export function joinLessonChannel(lessonId, callbacks = {}) {
  if (!socket) {
    console.error("[Socket] Not connected. Call connectSocket(token) first.")
    return null
  }

  // Reuse existing channel if already joined
  if (lessonChannels[lessonId]) {
    return lessonChannels[lessonId]
  }

  const channel = socket.channel(`lesson:${lessonId}`, {})

  // Set up event listeners
  channel.on("transcription_complete", payload => {
    console.log("[Lesson] Transcription complete", payload)
    callbacks.onTranscriptionComplete?.(payload)
  })

  channel.on("transcription_failed", payload => {
    console.error("[Lesson] Transcription failed", payload)
    callbacks.onTranscriptionFailed?.(payload)
  })

  channel.on("analysis_complete", payload => {
    console.log("[Lesson] Analysis complete", payload)
    callbacks.onAnalysisComplete?.(payload)
  })

  channel.on("analysis_failed", payload => {
    console.error("[Lesson] Analysis failed", payload)
    callbacks.onAnalysisFailed?.(payload)
  })

  channel.on("status_update", payload => {
    console.log("[Lesson] Status update", payload)
    callbacks.onStatusUpdate?.(payload)
  })

  // Join the channel
  channel.join()
    .receive("ok", () => {
      console.log(`[Lesson] Joined channel lesson:${lessonId}`)
    })
    .receive("error", resp => {
      console.error(`[Lesson] Unable to join channel lesson:${lessonId}`, resp)
    })

  lessonChannels[lessonId] = channel
  return channel
}

/**
 * Leave a lesson channel
 * @param {string} lessonId - The lesson UUID
 */
export function leaveLessonChannel(lessonId) {
  const channel = lessonChannels[lessonId]
  if (channel) {
    channel.leave()
    delete lessonChannels[lessonId]
    console.log(`[Lesson] Left channel lesson:${lessonId}`)
  }
}

/**
 * Get the current socket instance
 */
export function getSocket() {
  return socket
}

// Export for window access (useful for debugging)
if (typeof window !== "undefined") {
  window.HellenSocket = {
    connectSocket,
    disconnectSocket,
    joinLessonChannel,
    leaveLessonChannel,
    getSocket
  }
}
