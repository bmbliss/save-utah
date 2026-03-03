import { Controller } from "@hotwired/stimulus"

// Toggles the expandable phone numbers section on a blast rep card
export default class extends Controller {
  static targets = ["details"]

  toggle() {
    this.detailsTarget.classList.toggle("hidden")
  }
}
