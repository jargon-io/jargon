# frozen_string_literal: true

class WelcomeController < ApplicationController
  def index
    @items = HomeFeedQuery.new(limit: 25).call
  end
end
