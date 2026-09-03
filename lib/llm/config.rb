require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-5-mini'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      initialize!
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.openai_api_base = api_base
      end

      yield context
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        if openai_endpoint.present?
          endpoint = openai_endpoint.chomp('/')
          endpoint = "#{endpoint}/v1" unless endpoint.end_with?('/v1')
          config.openai_api_base = endpoint
        end
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger
      end
    end

    def system_api_key
      ENV['CAPTAIN_OPEN_AI_API_KEY'].presence || ENV['OPENAI_API_KEY'].presence || InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def openai_endpoint
      ENV['CAPTAIN_OPEN_AI_ENDPOINT'].presence || InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    end
  end
end
