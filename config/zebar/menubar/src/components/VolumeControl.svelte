<script lang="ts">
  import { providers } from '../providers.svelte';
  import Volume from '@lucide/svelte/icons/volume';
  import Volume1 from '@lucide/svelte/icons/volume-1';
  import Volume2 from '@lucide/svelte/icons/volume-2';
  import VolumeOff from '@lucide/svelte/icons/volume-off';
  import VolumeX from '@lucide/svelte/icons/volume-x';
  let { onclick, expanded = false }: { onclick: () => void; expanded?: boolean } = $props();
  let device = $derived(providers.audio?.defaultPlaybackDevice);
</script>
<button class="info-button volume" aria-label="Audio information" aria-expanded={expanded} {onclick}>
  {#if !device}<VolumeOff />
  {:else if device.isMuted || device.volume === 0}<VolumeX />
  {:else if device.volume <= 33}<Volume />
  {:else if device.volume <= 66}<Volume1 />
  {:else}<Volume2 />{/if}
  <span class="tabular">{device ? (device.isMuted ? 'Muted' : Math.round(device.volume) + '%') : '—'}</span>
</button>
