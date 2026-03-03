import { Controller } from "@hotwired/stimulus"

// Web Share API with copy-link fallback
export default class extends Controller {
  static values = { title: String, text: String, url: String }
  static targets = ["button"]

  async share() {
    const shareData = {
      title: this.titleValue,
      text: this.textValue,
      url: this.urlValue || window.location.href
    }

    if (navigator.share) {
      try {
        await navigator.share(shareData)
      } catch (e) {
        // User cancelled — no action needed
      }
    } else {
      // Fallback: copy URL to clipboard
      await navigator.clipboard.writeText(shareData.url)
      const original = this.buttonTarget.textContent
      this.buttonTarget.textContent = "Link Copied!"
      setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
    }
  }
}
