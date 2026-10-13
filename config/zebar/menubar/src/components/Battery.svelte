<script lang="ts">
  import { providers } from '../providers.svelte';
  import Battery from '@lucide/svelte/icons/battery';
  import BatteryCharging from '@lucide/svelte/icons/battery-charging';
  import BatteryFull from '@lucide/svelte/icons/battery-full';
  import BatteryLow from '@lucide/svelte/icons/battery-low';
  import BatteryMedium from '@lucide/svelte/icons/battery-medium';
  import BatteryWarning from '@lucide/svelte/icons/battery-warning';
  let battery = $derived(providers.battery);
</script>
{#if battery?.state}
  <span class="battery-icon">
    {#if battery.state === 'charging'}<BatteryCharging />
    {:else if battery.chargePercent < 20}<BatteryWarning />
    {:else if battery.chargePercent < 50}<BatteryLow />
    {:else if battery.chargePercent < 80}<BatteryMedium />
    {:else if battery.chargePercent <= 100}<BatteryFull />
    {:else}<Battery />{/if}
  </span>
  <span class="tabular">{Math.round(battery.chargePercent)}%</span>
{/if}
