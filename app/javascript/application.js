// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Custom Turbo Stream action: redirect
Turbo.StreamActions.redirect = function () {
  const url = this.getAttribute("url");
  if (url) {
    Turbo.visit(url, { action: "replace" });
  }
};
