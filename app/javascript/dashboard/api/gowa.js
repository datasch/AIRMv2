/* global axios */
import ApiClient from './ApiClient';

class GowaAPI extends ApiClient {
  constructor() {
    super('gowa', { accountScoped: true });
  }

  getStatus(deviceId) {
    const params = deviceId ? { device_id: deviceId } : {};
    return axios.get(`${this.url}/status`, { params });
  }

  getPairingQR(deviceId) {
    return axios.post(`${this.url}/pair`, { device_id: deviceId });
  }

  createInbox({ name, deviceId }) {
    return axios.post(`${this.url}/create_inbox`, {
      name,
      device_id: deviceId,
    });
  }

  disconnect(deviceId) {
    return axios.post(`${this.url}/disconnect`, { device_id: deviceId });
  }
}

export default new GowaAPI();
