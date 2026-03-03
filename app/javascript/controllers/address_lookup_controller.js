import { Controller } from "@hotwired/stimulus"

// Handles loading state for the address lookup form.
// Disables button + shows "Looking up..." while Turbo submits.
export default class extends Controller {
  static targets = ["button", "input"]

  connect() {
    this.element.addEventListener("turbo:submit-start", this.onSubmitStart)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.onSubmitStart)
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  onSubmitStart = () => {
    if (this.hasButtonTarget) {
      this.originalText = this.buttonTarget.textContent
      this.buttonTarget.textContent = "Looking up..."
      this.buttonTarget.disabled = true
      this.buttonTarget.classList.add("opacity-60", "cursor-wait")
    }
  }

  onSubmitEnd = () => {
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = this.originalText || "Find My Reps"
      this.buttonTarget.disabled = false
      this.buttonTarget.classList.remove("opacity-60", "cursor-wait")
    }
  }
}
