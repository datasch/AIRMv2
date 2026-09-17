require 'rails_helper'

RSpec.describe 'Canned Responses API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before do
    create(:canned_response, account: account, user: agent, content: 'Hey {{ contact.name }}, Thanks for reaching out', short_code: 'name-short-code')
  end

  describe 'GET /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      it 'returns only the agent own canned responses and not other agents responses' do
        other_response = create(:canned_response, account: account, user: other_agent, content: 'Other response', short_code: 'other-code')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_ids = response.parsed_body.pluck('id')
        expect(response_ids).to include(account.canned_responses.first.id)
        expect(response_ids).not_to include(other_response.id)
      end

      it 'returns all the canned responses the user searched for within their own scope' do
        cr1 = account.canned_responses.first
        create(:canned_response, account: account, user: agent, content: 'Great! Looking forward', short_code: 'short-code')
        cr2 = create(:canned_response, account: account, user: agent, content: 'Thanks for reaching out', short_code: 'content-with-thanks')
        cr3 = create(:canned_response, account: account, user: agent, content: 'Thanks for reaching out', short_code: 'Thanks')
        create(:canned_response, account: account, user: other_agent, content: 'Thanks for reaching out', short_code: 'other-thanks')

        params = { search: 'thanks' }

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(
          [cr3, cr2, cr1].as_json
        )
      end

      it 'ignores null bytes in the search string' do
        matching_response = create(:canned_response, account: account, user: agent, content: 'Unique response', short_code: 'unique')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { search: "uni\0que" },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq([matching_response].as_json)
      end
    end

    context 'when it is an authenticated administrator' do
      it 'returns all canned responses in the account across all users' do
        cr_other = create(:canned_response, account: account, user: other_agent, content: 'Other response', short_code: 'other-code')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_ids = response.parsed_body.pluck('id')
        expect(response_ids).to contain_exactly(account.canned_responses.first.id, cr_other.id)
      end

      it 'allows filtering by user_id' do
        cr_other = create(:canned_response, account: account, user: other_agent, content: 'Other response', short_code: 'other-code')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { user_id: other_agent.id },
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_ids = response.parsed_body.pluck('id')
        expect(response_ids).to eq([cr_other.id])
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'creates a new canned response assigned to the current user' do
        params = { short_code: 'short', content: 'content' }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        created_response = CannedResponse.find(response.parsed_body['id'])
        expect(created_response.user_id).to eq(agent.id)
        expect(account.canned_responses.count).to eq(2)
      end

      it 'allows two different users to use the same short_code' do
        create(:canned_response, account: account, user: agent, short_code: 'saludo', content: 'Hola de agente 1')

        params = { short_code: 'saludo', content: 'Hola de agente 2' }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: other_agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        created_response = CannedResponse.find(response.parsed_body['id'])
        expect(created_response.user_id).to eq(other_agent.id)
        expect(created_response.short_code).to eq('saludo')
      end
    end

    context 'when administrator creates a response for another user' do
      it 'assigns the response to the specified user' do
        params = { short_code: 'assigned-code', content: 'Assigned content', user_id: other_agent.id }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        created_response = CannedResponse.find(response.parsed_body['id'])
        expect(created_response.user_id).to eq(other_agent.id)
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'updates an existing canned response owned by the user' do
        params = { short_code: 'B' }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.short_code).to eq('B')
      end

      it 'forbids an agent from updating another users canned response' do
        other_response = create(:canned_response, account: account, user: other_agent, short_code: 'other', content: 'content')

        put "/api/v1/accounts/#{account.id}/canned_responses/#{other_response.id}",
            params: { short_code: 'hacked' },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(other_response.reload.short_code).to eq('other')
      end

      it 'allows an administrator to update any users canned response' do
        other_response = create(:canned_response, account: account, user: other_agent, short_code: 'other', content: 'content')

        put "/api/v1/accounts/#{account.id}/canned_responses/#{other_response.id}",
            params: { short_code: 'admin-updated' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(other_response.reload.short_code).to eq('admin-updated')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'destroys the canned response owned by the user' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(CannedResponse.count).to eq(0)
      end

      it 'forbids an agent from deleting another users canned response' do
        other_response = create(:canned_response, account: account, user: other_agent, short_code: 'other', content: 'content')

        delete "/api/v1/accounts/#{account.id}/canned_responses/#{other_response.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(CannedResponse.exists?(other_response.id)).to be(true)
      end

      it 'allows an administrator to delete any users canned response' do
        other_response = create(:canned_response, account: account, user: other_agent, short_code: 'other', content: 'content')

        delete "/api/v1/accounts/#{account.id}/canned_responses/#{other_response.id}",
               headers: admin.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(CannedResponse.exists?(other_response.id)).to be(false)
      end
    end
  end
end
