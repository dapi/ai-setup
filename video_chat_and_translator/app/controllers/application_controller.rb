# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :authenticate_user!

  inertia_share flash: -> { flash.to_hash }
  inertia_share current_user: -> { current_user&.as_json(only: [ :id, :email ]) }
end
