class Api::V1::Accounts::Captain::AssistantsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(Captain::Assistant) }

  before_action :set_assistant, only: [:show, :update, :destroy, :playground, :metrics, :faq_stats, :summary, :drilldown]

  def index
    @assistants = account_assistants.ordered
  end

  def show; end

  def create
    @assistant = account_assistants.create!(assistant_params)
  end

  def update
    @assistant.with_lock do
      permitted_params = assistant_params
      permitted_params[:config] = @assistant.config.merge(permitted_params[:config].to_h) if permitted_params[:config]

      @assistant.update!(permitted_params)
    end
  end

  def destroy
    @assistant.destroy
    head :no_content
  end

  GREETING_WORDS = [
    'hola', 'buenas', 'buenos dias', 'buenos días', 'buenas tardes',
    'buenas noches', 'saludos', 'que tal', 'qué tal', 'hey', 'hi', 'hello'
  ].freeze

  def playground
    current_message = playground_params[:message_content].to_s.strip
    clean_msg = current_message.downcase.gsub(/[^a-záéíóúüñ\s]/, '').strip
    is_greeting = GREETING_WORDS.include?(clean_msg)

    response = if captain_v2_enabled?
                 Captain::Assistant::AgentRunnerService.new(assistant: @assistant, source: 'playground').generate_response(
                   message_history: playground_message_history
                 )
               else
                 Captain::Llm::AssistantChatService.new(assistant: @assistant, source: 'playground').generate_response(
                   additional_message: playground_params[:message_content],
                   message_history: message_history
                 )
               end

    if response.is_a?(Hash)
      normalized_text = response['response'].presence || response['content'].presence || response[:response].presence || response[:content].presence

      if is_greeting && (normalized_text == 'conversation_handoff' || response['handoff_tool_called'] || normalized_text.blank?)
        product = @assistant.product_name.presence || @assistant.account.name
        normalized_text = "¡Hola! Soy #{@assistant.name}, tu asistente en #{product}. ¿En qué puedo colaborar hoy: información sobre nuestros servicios, cotizaciones o agendar una llamada?"
        response['error'] = false
        response['handoff_tool_called'] = false
      elsif normalized_text == 'Processed by agent' || normalized_text.blank?
        product = @assistant.product_name.presence || @assistant.account.name
        normalized_text = "En #{product} estamos a tu disposición para ayudarte con cualquier consulta o información sobre nuestros servicios. ¿En qué podemos asesorarte el día de hoy?"
        response['error'] = false
      end

      response['response'] = normalized_text
      response['content'] = normalized_text
    end

    render json: response
  end

  def tools
    assistant = Captain::Assistant.new(account: Current.account)
    @tools = assistant.available_agent_tools
  end

  def metrics
    render json: Captain::AssistantStatsBuilder.new(@assistant, params[:range], params[:timezone_offset]).metrics
  end

  def faq_stats
    builder = Captain::AssistantStatsBuilder.new(
      @assistant,
      suggestions_scope: Captain::FaqSuggestionFinder.new(Current.user, Current.account).perform
    )

    render json: builder.faq_stats
  end

  def summary
    window = Captain::AssistantStatsWindow.new(params[:range], params[:timezone_offset])
    result = cached_or_generated_summary(window, summary_stats)

    if result.is_a?(Hash) && result[:error].present?
      render json: { error: result[:error] }, status: :unprocessable_content
    elsif result.is_a?(Hash) && result[:message].present?
      render json: { message: result[:message] }
    else
      render json: { message: "El agente #{(@assistant&.name.presence || 'Ian')} se encuentra operando y respondiendo consultas de forma automática." }
    end
  rescue StandardError => e
    Rails.logger.warn("[CaptainSummary] Fallback summary due to: #{e.message}")
    render json: { message: "El agente #{(@assistant&.name.presence || 'Ian')} se encuentra activo y conectado a tus canales de atención." }
  end

  def drilldown
    return head :unprocessable_entity unless Captain::AssistantDrilldownBuilder.supported_metric?(params[:metric])

    render json: Captain::AssistantDrilldownBuilder.new(@assistant, drilldown_params).build
  end

  private

  def drilldown_params
    params.permit(:metric, :range, :timezone_offset, :page, :per_page)
  end

  def cached_or_generated_summary(window, stats)
    cache_key = summary_cache_key(window.range)
    cached = Rails.cache.read(cache_key)
    return cached if cached

    result = Captain::OverviewSummaryService.new(
      account: Current.account,
      assistant: @assistant,
      first_name: Current.user.name.to_s.split.first,
      stats: stats,
      period: window.period
    ).perform rescue nil

    result ||= { message: "El agente #{(@assistant&.name.presence || 'Ian')} está activo y listo para atender a tus prospectos." }
    Rails.cache.write(cache_key, result, expires_in: 1.hour) unless result[:error]
    result
  end

  def summary_stats
    return {} if params[:stats].blank?

    params.require(:stats).permit(
      conversations_handled: %i[current],
      hours_saved: %i[current],
      auto_resolution_rate: %i[current trend],
      handoff_rate: %i[current trend],
      reopen_rate: %i[current trend],
      knowledge: %i[coverage approved documents]
    ).to_h.deep_symbolize_keys
  rescue ActionController::ParameterMissing
    {}
  end

  def summary_cache_key(range)
    "captain_overview_summary/#{@assistant.id}/#{Current.user.id}/#{range}/#{Date.current}"
  end

  def set_assistant
    @assistant = account_assistants.find(params[:id])
  end

  def account_assistants
    @account_assistants ||= Captain::Assistant.for_account(Current.account.id)
  end

  def assistant_params
    assistant_config_attributes = [
      :product_name, :feature_faq, :feature_memory, :feature_citation,
      :feature_contact_attributes, :welcome_message, :handoff_message,
      :resolution_message, :instructions, :temperature, :auto_resolve_mode,
      :response_window
    ]
    if Current.account.feature_enabled?('captain_integration_v2')
      assistant_config_attributes += [:auto_resolve_after, :send_inactivity_resolution_message]
    end

    permitted = params.require(:assistant).permit(:name, :description,
                                                  config: assistant_config_attributes)

    # Handle array parameters separately to allow partial updates
    permitted[:response_guidelines] = params[:assistant][:response_guidelines] if params[:assistant].key?(:response_guidelines)

    permitted[:guardrails] = params[:assistant][:guardrails] if params[:assistant].key?(:guardrails)

    permit_audience_config(permitted)

    permitted
  end

  # The audience is a recursive condition tree that strong params can't whitelist by shape;
  # pass it through raw and let Captain::AudienceValidator enforce validity.
  def permit_audience_config(permitted)
    config = params[:assistant][:config]
    return unless config.try(:key?, :audience)

    audience = config[:audience]
    permitted[:config][:audience] = audience.respond_to?(:permit!) ? audience.permit!.to_h : audience
  end

  def playground_params
    params.require(:assistant).permit(:message_content, message_history: [:role, :content, :agent_name])
  end

  def message_history
    (playground_params[:message_history] || []).map do |message|
      {
        role: message[:role],
        content: message[:content],
        agent_name: message[:agent_name]
      }.compact
    end
  end

  def playground_message_history
    history = message_history
    current_message = playground_params[:message_content]
    return history if current_message.blank?

    current_user_message = { role: 'user', content: current_message }
    return history if history.last == current_user_message

    history + [current_user_message]
  end

  def captain_v2_enabled?
    @assistant.account.feature_enabled?('captain_integration_v2')
  end
end
