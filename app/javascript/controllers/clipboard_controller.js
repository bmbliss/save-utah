import { Controller } from "@hotwired/stimulus"

// Copies text content to clipboard with visual feedback
export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    const text = this.sourceTarget.innerText
    navigator.clipboard.writeText(text).then(() => {
      const original = this.buttonTarget.textContent
      this.buttonTarget.textContent = "Copied!"
      setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
    })
  }
}
