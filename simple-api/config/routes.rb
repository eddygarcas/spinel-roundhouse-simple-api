Rails.application.routes.draw do
  root to: 'status#health'
  get '/ping', to: 'status#ping'
  get '/health', to: 'status#health'
end
