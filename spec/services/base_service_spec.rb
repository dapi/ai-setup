require "rails_helper"

RSpec.describe BaseService do
  describe ".call" do
    it "returns a successful result from the service instance" do
      service_class = Class.new(described_class) do
        option :value

        def call
          success(result: value)
        end
      end

      result = service_class.call(value: "ready")

      expect(result).to be_success
      expect(result.result).to eq("ready")
      expect(result.error_code).to be_nil
      expect(result.messages).to eq([])
    end

    it "returns a failure result from the service instance" do
      service_class = Class.new(described_class) do
        def call
          failure(error_code: :invalid, messages: ["Not valid"])
        end
      end

      result = service_class.call

      expect(result).to be_failure
      expect(result.result).to be_nil
      expect(result.error_code).to eq(:invalid)
      expect(result.messages).to eq(["Not valid"])
    end
  end
end
