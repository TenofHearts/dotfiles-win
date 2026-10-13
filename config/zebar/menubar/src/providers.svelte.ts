import { createProviderGroup, type ProviderGroup } from 'zebar';

const config = {
  glazewm: { type: 'glazewm' },
  battery: { type: 'battery', refreshInterval: 60000 },
  audio: { type: 'audio' },
  date: { type: 'date' }
} as const;

export const providers = $state<ProviderGroup<typeof config>['outputMap']>({
  glazewm: null, battery: null, audio: null, date: null
});

export function initProviders() {
  // Temporary RDP isolation test: Zebar 3.3.1's native audio callback reads
  // a potentially null default-device ID. Keep the UI shape, but do not
  // instantiate that provider until the connect/disconnect test is complete.
  const { audio: _audio, ...diagnosticConfig } = config;
  const group = createProviderGroup(diagnosticConfig);
  group.onOutput(output => Object.assign(providers, output));
  group.onError(errors => {
    Object.assign(providers, group.outputMap);
    console.error('Zebar provider:', errors);
  });
  return () => { void group.stopAll().catch(console.error); };
}
