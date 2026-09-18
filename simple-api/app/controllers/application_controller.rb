# Roundhouse's Spinel runtime currently implements request state on
# ActionController::Base. Actions stay JSON-only, so this remains an API.
class ApplicationController < ActionController::Base
end
