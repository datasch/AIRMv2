/* global axios */
import ApiClient from './ApiClient';

class CoverageAPI extends ApiClient {
  constructor() {
    super('coverage', { accountScoped: true });
  }

  getReports(params = {}) {
    return axios.get(`${this.url}/reports`, { params });
  }

  triggerSync(data = {}) {
    return axios.post(`${this.url}/sync`, data);
  }

  getSyncStatus() {
    return axios.get(`${this.url}/sync_status`);
  }
}

export default new CoverageAPI();
