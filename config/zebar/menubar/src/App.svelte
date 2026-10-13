<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { LogicalSize } from '@tauri-apps/api/window';
  import { currentWidget, shellExec } from 'zebar';
  import { initProviders, providers } from './providers.svelte';
  import { createResizeQueue } from './resize-queue.mjs';
  import Workspaces from './components/Workspaces.svelte';
  import Battery from './components/Battery.svelte';
  import VolumeControl from './components/VolumeControl.svelte';
  import Wifi from '@lucide/svelte/icons/wifi';
  import WifiOff from '@lucide/svelte/icons/wifi-off';
  import Bluetooth from '@lucide/svelte/icons/bluetooth';
  import BluetoothOff from '@lucide/svelte/icons/bluetooth-off';

  let popup = $state('');
  let error = $state('');
  let connection = $state<{wifi: string[], bluetooth: string[], wifiError?: string, bluetoothError?: string} | null>(null);
  let panel: HTMLDivElement;
  let preview = false;
  let resize = () => {};
  let connectionBusy = false;
  let disposed = false;
  let wm = $derived(providers.glazewm);
  let mode = $derived(!wm ? 'GlazeWM offline' : wm.isPaused ? 'Paused' : wm.bindingModes.map(m => m.displayName ?? m.name).join(' · ') || 'Normal');
  let focusedWindow = $derived(wm?.focusedContainer?.type === 'window' ? wm.focusedContainer : null);
  let fullWindowTitle = $derived(focusedWindow?.title.trim() || focusedWindow?.processName || '');
  let windowTitle = $derived.by(() => {
    if (!focusedWindow) return '';
    const title = fullWindowTitle;
    // VS Code includes the active file before its workspace and app name.
    if (/^code(?: - insiders)?$/i.test(focusedWindow.processName)) {
      const app = title.match(/Visual Studio Code(?: - Insiders)?$/)?.[0];
      if (app) {
        const context = title.slice(0, -app.length).replace(/ - $/, '').split(' - ').pop();
        return context ? context + ' - ' + app : app;
      }
    }
    return title;
  });
  let audio = $derived(providers.audio);
  let clock = $derived(providers.date?.new.toLocaleTimeString(undefined, {hour:'2-digit',minute:'2-digit',hour12:false}) ?? '—');

  async function toggle(name: string) {
    popup = popup === name ? '' : name;
    if (popup && !preview) {
      try { await currentWidget().tauriWindow.setFocus(); }
      catch (e) { console.error('Cannot focus dropdown:', e); }
    }
  }
  async function refreshConnections() {
    if (connectionBusy || disposed) return;
    connectionBusy = true;
    try {
      const widget = currentWidget();
      const folder = widget.htmlPath.replace(/[\\/][^\\/]+$/, '');
      const result = await shellExec('powershell.exe', ['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File', folder + '/connection-info.ps1']);
      if (result.code !== 0) throw new Error(result.stderr || 'Connection query failed');
      if (disposed) return;
      connection = JSON.parse(result.stdout.replace(/^\uFEFF/, ''));
      error = '';
    } catch (e) { if (!disposed) { connection = null; error = String(e); } }
    finally { connectionBusy = false; }
  }
  onMount(() => {
    preview = new URLSearchParams(location.search).has('preview');
    if (preview) {
      Object.assign(providers, {glazewm: {isPaused:false,bindingModes:[{name:'move',displayName:'Move'}],focusedContainer:{type:'window',title:'dotfiles — Visual Studio Code',processName:'Code'},currentMonitor:{hasFocus:true},currentWorkspaces:[{id:'1',name:'1',isDisplayed:false},{id:'2',name:'2',isDisplayed:true},{id:'3',name:'3',isDisplayed:false}],allWorkspaces:[{id:'1'},{id:'2'},{id:'3'}],runCommand:()=>{}},date:{new:new Date(2026,9,10,14,36)},battery:{state:'charging',chargePercent:82},audio:{defaultPlaybackDevice:{name:'Speakers',volume:40,isMuted:false},playbackDevices:[{name:'Speakers',volume:40,isMuted:false}]}});
      connection = {wifi:['Studio WiFi'],bluetooth:['Wireless headphones','Keyboard']};
      return;
    }
    const stopProviders = initProviders();
    const win = currentWidget().tauriWindow;
    let scheduled = false;
    const sizes = createResizeQueue(async (height: number) => {
      // Width and placement belong to Zebar's 100%-width monitor preset.
      // Read the current logical width only when a dropdown needs more height.
      await win.setSize(new LogicalSize(window.innerWidth, height));
    });
    const fit = async () => {
      await tick();
      scheduled = false;
      if (disposed) return;
      const height = popup && panel ? Math.ceil(panel.getBoundingClientRect().bottom) + 8 : 28;
      await sizes.request(height);
    };
    resize = () => { if (!scheduled && !disposed) { scheduled = true; requestAnimationFrame(() => { void fit().catch(console.error); }); } };
    const observer = new ResizeObserver(resize);
    if (panel) observer.observe(panel);
    const unlisten = win.onFocusChanged(({payload}) => { if (!payload) popup = ''; });
    void refreshConnections();
    const connectionTimer = setInterval(refreshConnections,20000);
    return () => {
      disposed=true; sizes.dispose(); observer.disconnect(); clearInterval(connectionTimer);
      stopProviders(); void unlisten.then(stop=>stop()).catch(console.error);
    };
  });
  $effect(() => { popup; resize(); });
</script>

<svelte:window onkeydown={(e) => {if(e.key==='Escape')popup='';}} onpointerdown={(e) => {if(popup && !(e.target as HTMLElement).closest('.info-button,.dropdown'))popup='';}} />
<div class="pill-wrap menubar">
  <div class="menu-row">
    <div class="pill mode" style:max-width="min(560px, 35vw)">
      <span class="mode-dot" class:active={mode !== 'Normal'}></span><span class="mode-label">{mode}</span>
      {#if windowTitle}<span class="separator"></span><span class="window-title" title={fullWindowTitle}>{windowTitle}</span>{/if}
    </div>
    <div class="pill workspaces">
      <Workspaces />
    </div>
    <div class="pill status">
      <VolumeControl onclick={() => toggle('audio')} expanded={popup === 'audio'} />
      <button class="info-button" class:connected={!!connection?.wifi.length} aria-label="Wi-Fi information" aria-expanded={popup==='wifi'} onclick={() => toggle('wifi')}>{#if connection?.wifi.length}<Wifi />{:else}<WifiOff />{/if}</button>
      <button class="info-button" class:connected={!!connection?.bluetooth.length} aria-label="Bluetooth information" aria-expanded={popup==='bluetooth'} onclick={() => toggle('bluetooth')}>{#if connection?.bluetooth.length}<Bluetooth />{:else}<BluetoothOff />{/if}</button>
      <span class="separator"></span><span class="battery"><Battery /></span><span class="separator"></span><span class="tabular clock">{clock}</span>
    </div>
  </div>
  <div bind:this={panel} class="dropdown" class:closed={!popup} role="region" aria-label={`${popup} information`}>
    {#if popup}
      <h2>{popup === 'audio' ? 'Volume' : popup === 'wifi' ? 'Wi-Fi' : 'Bluetooth'}</h2>
      {#if popup === 'audio'}
        {#each audio?.playbackDevices ?? [] as device}<div class="detail-row"><span>{device.name}</span><span class="muted">{device.isMuted ? 'Muted' : Math.round(device.volume) + '%'}</span></div>{:else}<p>No playback device available</p>{/each}
      {:else if error}<p class="muted">Connection information unavailable</p>
      {:else if !connection}<p class="muted">Checking connections…</p>
      {:else}
        {@const names = popup === 'wifi' ? connection.wifi : connection.bluetooth}
        {@const queryError = popup === 'wifi' ? connection.wifiError : connection.bluetoothError}
        {#if queryError}<p class="muted">Connection information unavailable</p>{:else}{#each names as name}<div class="detail-row"><span>{name}</span><span class="connected">Connected</span></div>{:else}<p class="muted">Nothing connected</p>{/each}{/if}
      {/if}
    {/if}
  </div>
</div>
