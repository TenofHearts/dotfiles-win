<script lang="ts">
  import { providers } from '../providers.svelte';
  let wm = $derived(providers.glazewm);
  async function focus(name: string) {
    try { await wm?.runCommand(`focus --workspace ${JSON.stringify(name)}`); }
    catch (error) { console.error('Workspace focus failed:', error); }
  }
</script>
{#if wm}
  <div class="workspace-buttons">
    {#each wm.currentWorkspaces ?? [] as workspace (workspace.id)}
      <div class="workspace-chip" class:displayed={workspace.isDisplayed} class:focused={workspace.isDisplayed && wm.currentMonitor?.hasFocus}>
        <button onclick={() => focus(workspace.name)} aria-label={`Workspace ${workspace.name}`}>{workspace.name}</button>
      </div>
    {/each}
  </div>
{:else}<span class="muted">GlazeWM offline</span>{/if}
