# frozen_string_literal: true

require 'test_helper'

class StatusControllerTest < ActionDispatch::IntegrationTest
  test 'ping returns pong' do
    get '/ping'

    assert_response :success
    assert_equal({ 'message' => 'pong' }, response.parsed_body)
  end

  test 'health returns ok' do
    get '/health'

    assert_response :success
    assert_equal({ 'status' => 'ok' }, response.parsed_body)
  end

  test 'root returns health' do
    get '/'

    assert_response :success
    assert_equal({ 'status' => 'ok' }, response.parsed_body)
  end
end
