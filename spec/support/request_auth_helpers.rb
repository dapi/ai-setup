module RequestAuthHelpers
  def auth_header(staff_record)
    encoded = Base64.strict_encode64("#{staff_record.email}:password")
    { "Authorization" => "Basic #{encoded}" }
  end
end

RSpec.configure do |config|
  config.include RequestAuthHelpers, type: :request
end
