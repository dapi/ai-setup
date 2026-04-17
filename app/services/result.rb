Result = Data.define(:success, :error_code, :messages, :result) do
  def success? = success
  def failure? = !success

  def self.new(success:, result: nil, error_code: nil, messages: [])
    self[success, error_code, messages, result]
  end
end
