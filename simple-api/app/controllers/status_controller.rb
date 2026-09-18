# frozen_string_literal: true

class StatusController < ApplicationController
  def ping
    render plain: '{"message":"pong"}', content_type: 'application/json'
  end

  def health
    render plain: '{"status":"ok"}', content_type: 'application/json'
  end
end
