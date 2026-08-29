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

  logCall({ conversationId, phoneNumber, durationSeconds, status }) {
    return axios.post(`${this.url}/log_call`, {
      conversation_id: conversationId,
      phone_number: phoneNumber,
      duration_seconds: durationSeconds,
      status,
    });
  }
}

export default new VoipAPI();
