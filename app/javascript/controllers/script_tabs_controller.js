import { Controller } from "@hotwired/stimulus"

// Switches between call/text/email script panels
export default class extends Controller {
  static targets = ["tab", "panel"]

  switch(event) {
    const index = event.currentTarget.dataset.index

    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle("bg-white", i.toString() === index)
      tab.classList.toggle("text-utah-navy", i.toString() === index)
      tab.classList.toggle("font-bold", i.toString() === index)
      tab.classList.toggle("text-gray-400", i.toString() !== index)
    })

    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i.toString() !== index)
    })
  }
}
