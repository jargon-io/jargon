import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]

  search() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value

    if (query.length < 3) {
      this.resultsTarget.innerHTML = ""
      return
    }

    this.timeout = setTimeout(() => {
      this.resultsTarget.src = `/autocomplete?q=${encodeURIComponent(query)}`
    }, 200)
  }

  navigate(event) {
    const items = this.resultsTarget.querySelectorAll("a")
    if (items.length === 0) return

    const current = this.resultsTarget.querySelector("a.bg-gray-100, a.dark\\:bg-gray-700")
    let index = Array.from(items).indexOf(current)

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        index = index < items.length - 1 ? index + 1 : 0
        this.highlight(items, index)
        break
      case "ArrowUp":
        event.preventDefault()
        index = index > 0 ? index - 1 : items.length - 1
        this.highlight(items, index)
        break
      case "Enter":
        if (current) {
          event.preventDefault()
          current.click()
        }
        break
      case "Escape":
        this.resultsTarget.innerHTML = ""
        this.inputTarget.blur()
        break
    }
  }

  highlight(items, index) {
    items.forEach((item, i) => {
      if (i === index) {
        item.classList.add("bg-gray-100", "dark:bg-gray-700")
      } else {
        item.classList.remove("bg-gray-100", "dark:bg-gray-700")
      }
    })
  }

  connect() {
    this.clickOutside = (e) => {
      if (!this.element.contains(e.target)) {
        this.resultsTarget.innerHTML = ""
      }
    }
    document.addEventListener("click", this.clickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutside)
  }
}
