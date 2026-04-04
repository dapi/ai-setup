Sidekiq.configure_server do |config|
  config.on(:startup) do
    Rails.application.reload_routes!
  end
end
