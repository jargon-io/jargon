import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item", "toggle"];
  static values = { limit: { type: Number, default: 2 } };

  connect() {
    this.update();
  }

  itemTargetConnected() {
    this.update();
  }

  update() {
    const items = this.itemTargets;
    const limit = this.limitValue;
    const hasMore = items.length > limit;

    items.forEach((item, index) => {
      item.hidden = hasMore && index >= limit;
    });

    if (this.hasToggleTarget) {
      this.toggleTarget.hidden = !hasMore;
      this.toggleTarget.textContent = `Show ${items.length - limit} more`;
    }
  }

  toggle() {
    this.itemTargets.forEach((item) => (item.hidden = false));
    if (this.hasToggleTarget) {
      this.toggleTarget.hidden = true;
    }
  }
}
