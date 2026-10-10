// Small, checked adaptations of Neosoft's existing widgets. Upstream stays local.
import fs from 'node:fs';
import path from 'node:path';
const root = process.argv[2];
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const write = (file, value) => fs.writeFileSync(path.join(root, file), value);
const between = (text, start, end) => {
  const a = text.indexOf(start), b = text.indexOf(end, a + start.length);
  if (a < 0 || b < 0) throw new Error(`Upstream changed: ${start}`);
  return text.slice(a, b);
};
const ws = read('src/components/Workspaces.svelte');
const buttons = between(ws, '      {#each glazewm.currentWorkspaces', '    </SmoothDiv>');
write('src/components/Workspaces.svelte', between(ws, '<script', '</script>') + '</script>\n{#if glazewm}<div class="workspace-buttons">' + buttons.replace(/class="mr-2"/, 'class="workspace-chip" class:displayed={workspace.isDisplayed} class:focused={workspace.isDisplayed && glazewm.currentMonitor.hasFocus}') + '</div>{:else}<span class="muted">GlazeWM offline</span>{/if}\n');
const left = read('src/components/LeftGroup.svelte');
const battery = between(left, '  {#if config.showBatterySection', '  {#if config.showNetworkSection').replace(/<Meter[\s\S]*?>/, '<span class="battery-icon">').replace('</Meter>', '</span>');
write('src/components/Battery.svelte', between(left, '<script', '</script>').replace(/  let (memory|cpu) = .*\n/g, '') + '</script>\n' + battery + '\n{#if battery?.state}<span class="tabular">{Math.round(battery.chargePercent)}%</span>{/if}');
const volume = read('src/components/VolumeControl/VolumeControl.svelte');
const icons = between(volume, '          {#if device}', '\n        </button>');
write('src/components/VolumeControl/VolumeControl.svelte', `<script lang="ts">
import { providers } from '$lib/providers.svelte';
import Volume from '@lucide/svelte/icons/volume';
import Volume1 from '@lucide/svelte/icons/volume-1';
import Volume2 from '@lucide/svelte/icons/volume-2';
import VolumeOff from '@lucide/svelte/icons/volume-off';
import VolumeX from '@lucide/svelte/icons/volume-x';
let { onclick = () => {} }: { onclick?: () => void } = $props();
let audio = $derived(providers.audio);
let device = $derived(audio?.defaultPlaybackDevice);
let volume = $derived(device?.volume ?? 0);
let muted = $derived(device?.isMuted ?? false);
const visible = true;
const toggleModes = { clickThrough: false };
</script>
<button class="info-button volume" aria-label="Audio information" {onclick}>${icons}<span class="tabular">{device ? (muted ? 'Muted' : Math.round(volume) + '%') : '—'}</span></button>`);
// Keep upstream provider wiring, but avoid unnecessary CPU/weather/media polling.
let providers = read('src/lib/providers.svelte.ts');
providers = providers.replace('createProviderGroup(providerConfig)', 'createProviderGroup({battery:providerConfig.battery,date:providerConfig.date,glazewm:providerConfig.glazewm,audio:providerConfig.audio})');
write('src/lib/providers.svelte.ts', providers);
write('src/components/NowPlaying.svelte', read('src/components/NowPlaying.svelte').replace('let mediaTimeout: number | null', 'let mediaTimeout: ReturnType<typeof setTimeout> | null'));
const pkg = JSON.parse(read('package.json'));
delete pkg.devDependencies['svelte-range-slider-pips'];
write('package.json', JSON.stringify(pkg, null, 2));
write('src/app.css', read('src/app.css').replace('@import "https://www.nerdfonts.com/assets/css/webfont.css";', ''));
const config = JSON.parse(read('static/config.json'));
Object.assign(config, {enableAutoTiling:false,backgroundEffect:'inherit',direction:'floating',gradient:'disabled',attachSides:false,showShutdownButton:false,showHeartButton:false,showCpuSection:false,showMemorySection:false,showWeatherSection:false,showFullDateByDefault:false,use24hClock:true,showSeconds:false,useThinnerWorkspaceButtons:true});
write('static/config.json', JSON.stringify(config, null, 2));
