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
  const group = createProviderGroup(config);
  group.onOutput(output => Object.assign(providers, output));
  group.onError(errors => {
    Object.assign(providers, group.outputMap);
    console.error('Zebar provider:', errors);
  });
  return () => { void group.stopAll().catch(console.error); };
}
