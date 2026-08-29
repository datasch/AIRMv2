import { frontendURL } from '../../../../helper/URLHelper';
import VoipIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/voip'),
      name: 'voip_settings_index',
      roles: ['administrator'],
      component: VoipIndex,
    },
  ],
};
