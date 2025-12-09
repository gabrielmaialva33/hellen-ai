// LiveView Hook for Lesson Channel updates
// This hook connects to the lesson WebSocket channel for real-time updates
// Note: Currently the app uses PubSub directly in LiveView, so this is optional

export const LessonChannel = {
  mounted() {
    const lessonId = this.el.dataset.lessonId
    const token = this.el.dataset.token

    if (!lessonId) {
      console.warn("[LessonChannel] No lesson-id provided")
      return
    }

    // Only connect if we have a token (for non-LiveView pages)
    if (token) {
      this.connectToChannel(lessonId, token)
    }
  },

  destroyed() {
    if (this.channel) {
      this.channel.leave()
      console.log("[LessonChannel] Left channel")
    }
  },

  async connectToChannel(lessonId, token) {
    const { connectSocket, joinLessonChannel } = await import("../socket.js")

    connectSocket(token)

    this.channel = joinLessonChannel(lessonId, {
      onTranscriptionComplete: (payload) => {
        this.pushEvent("transcription_complete", payload)
      },
      onTranscriptionFailed: (payload) => {
        this.pushEvent("transcription_failed", payload)
      },
      onAnalysisComplete: (payload) => {
        this.pushEvent("analysis_complete", payload)
      },
      onAnalysisFailed: (payload) => {
        this.pushEvent("analysis_failed", payload)
      },
      onStatusUpdate: (payload) => {
        this.pushEvent("status_update", payload)
      }
    })
  }
}
