/* global axios */
import ApiClient from './ApiClient';

class VoipAPI extends ApiClient {
  constructor() {
    super('voip', { accountScoped: true });
  }

  getConfig() {
    return axios.get(`${this.url}/config`);
  }

  updateConfig(voip) {
    return axios.post(`${this.url}/config`, { voip });
  }

  getAgents() {
    return axios.get(`${this.url}/agents`);
  }

  updateAgent({ userId, extension, password }) {
    return axios.post(`${this.url}/agents`, {
      user_id: userId,
      extension,
      password,
    });
  }

  updateCallStatus({ event, phoneNumber }) {
    return axios.post(`${this.url}/call_status`, {
      event,
      phone_number: phoneNumber,
    });
  }

  callContact({ contactId, conversationId }) {
    return axios.post(`${this.url}/call_contact`, {
      contact_id: contactId,
      conversation_id: conversationId,
    });
  }

  logCall({
    conversationId,
    phoneNumber,
    durationSeconds,
    status,
    callId,
    disposition,
    updateConversationTipificacion,
  }) {
    return axios.post(`${this.url}/log_call`, {
      conversation_id: conversationId,
      phone_number: phoneNumber,
      duration_seconds: durationSeconds,
      status,
      call_id: callId,
      disposition,
      update_conversation_tipificacion: updateConversationTipificacion,
    });
  }

  getClickToCallReports(params = {}) {
    return axios.get(`${this.url}/click_to_call_reports`, { params });
  }

  getDatabaseReports(params = {}) {
    return axios.get(`${this.url}/database_reports`, { params });
  }
}

export default new VoipAPI();
