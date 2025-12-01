import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item", "toggle"];
  static values = { limit: { type: Number, default: 2 } };

  connect() {
    this.expanded = false;

    if (this.hasToggleTarget) {
      this.toggleTemplate = this.toggleTarget.textContent.trim();
    }

    this.update();
  }

  itemTargetConnected() {
    this.update();
  }

  itemTargetDisconnected() {
    this.update();
  }

  update() {
    const items = this.itemTargets;
    const limit = this.limitValue;
    const hasMore = items.length > limit;

    items.forEach((item, index) => {
      item.hidden = !this.expanded && hasMore && index >= limit;
    });

    if (this.hasToggleTarget && this.toggleTemplate) {
      this.toggleTarget.hidden = this.expanded || !hasMore;
      const count = items.length - limit;
      this.toggleTarget.textContent = this.toggleTemplate.replace(
        "{count}",
        count
      );
    }
  }

  toggle() {
    this.expanded = true;
    this.update();
  }
}
