class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_params)
    @canned_response.user = target_user
    @canned_response.save!
    render json: @canned_response
  end

  def update
    if Current.account_user&.administrator? && params.dig(:canned_response, :user_id).present?
      @canned_response.user = Current.account.users.find(params[:canned_response][:user_id])
    end
    @canned_response.update!(canned_response_params)
    render json: @canned_response
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
    return if Current.account_user&.administrator?
    return if @canned_response.user_id == Current.user&.id

    render_unauthorized('You are not authorized to access this canned response')
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content)
  end

  def target_user
    if Current.account_user&.administrator? && params.dig(:canned_response, :user_id).present?
      Current.account.users.find(params[:canned_response][:user_id])
    else
      Current.user
    end
  end

  def canned_responses
    scope = base_canned_responses_scope
    return scope unless params[:search]

    search = params[:search].delete("\0")
    scope.where('short_code ILIKE :search OR content ILIKE :search', search: "%#{search}%")
         .order_by_search(search)
  end

  def base_canned_responses_scope
    return admin_scoped_canned_responses if Current.account_user&.administrator?
    return Current.account.canned_responses.where(user_id: Current.user.id) if Current.user.present?

    Current.account.canned_responses
  end

  def admin_scoped_canned_responses
    return Current.account.canned_responses.where(user_id: params[:user_id]) if params[:user_id].present?

    Current.account.canned_responses
  end
end
