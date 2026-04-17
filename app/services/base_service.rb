class BaseService
  extend Dry::Initializer

  class << self
    def call(**args)
      new(**args).call
    end
  end

  private

  def success(result: nil)
    Result.new(success: true, result: result)
  end

  def failure(error_code:, messages:, result: nil)
    Result.new(success: false, error_code: error_code, messages: messages, result: result)
  end
end
