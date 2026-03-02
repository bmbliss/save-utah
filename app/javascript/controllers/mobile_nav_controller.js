import { Controller } from "@hotwired/stimulus"

// Toggles the mobile navigation menu open/closed
export default class extends Controller {
  toggle() {
    const menu = document.getElementById("mobile-menu")
    menu.classList.toggle("hidden")
  }
}
