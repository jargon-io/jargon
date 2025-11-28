# frozen_string_literal: true

class InsightsController < ApplicationController
  def show
    @insight = Insight.find_by!(nanoid: params[:id])
    @article = @insight.article
  end
end
