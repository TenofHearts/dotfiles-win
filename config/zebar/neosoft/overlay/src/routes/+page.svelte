<script lang="ts">
  import { onMount } from 'svelte';
  import { LogicalSize, PhysicalPosition } from '@tauri-apps/api/window';
  import { invoke } from '@tauri-apps/api/core';
  import { currentWidget, shellExec } from 'zebar';
  import { initProviders, providers } from '$lib/providers.svelte';
  import Workspaces from '../components/Workspaces.svelte';
  import Battery from '../components/Battery.svelte';
  import VolumeControl from '../components/VolumeControl/VolumeControl.svelte';
  import Wifi from '@lucide/svelte/icons/wifi';
  import WifiOff from '@lucide/svelte/icons/wifi-off';
  import Bluetooth from '@lucide/svelte/icons/bluetooth';
  import BluetoothOff from '@lucide/svelte/icons/bluetooth-off';

  let section = $state('mode');
  let popup = $state('');
  let error = $state('');
  let connection = $state<{wifi: string[], bluetooth: string[], wifiError?: string, bluetoothError?: string} | null>(null);
  let pill: HTMLDivElement;
  let panel: HTMLDivElement;
  let preview = false;
  let resize = () => {};
  let wm = $derived(providers.glazewm);
  let mode = $derived(!wm ? 'GlazeWM offline' : wm.isPaused ? 'Paused' : wm.bindingModes.map(m => m.displayName ?? m.name).join(' · ') || 'Normal');
  let audio = $derived(providers.audio);
  let clock = $derived(providers.date?.new.toLocaleTimeString(undefined, {hour:'2-digit',minute:'2-digit',hour12:false}) ?? '—');

  async function toggle(name: string) {
    popup = popup === name ? '' : name;
    if (popup && !preview) await currentWidget().tauriWindow.setFocus();
  }
  async function refreshConnections() {
    try {
      const widget = currentWidget();
      const folder = widget.htmlPath.replace(/[\\/][^\\/]+$/, '');
      const result = await shellExec('powershell.exe', ['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File', folder + '/connection-info.ps1']);
      if (result.code !== 0) throw new Error(result.stderr || 'Connection query failed');
      connection = JSON.parse(result.stdout.replace(/^\uFEFF/, ''));
      error = '';
    } catch (e) { connection = null; error = String(e); }
  }
  onMount(() => {
    section = location.pathname.split('/').pop()?.replace('.html','') || 'mode';
    preview = new URLSearchParams(location.search).has('preview');
    if (preview) {
      section = new URLSearchParams(location.search).get('section') || section;
      Object.assign(providers, {glazewm: {isPaused:false,bindingModes:[{name:'move',displayName:'Move'}],currentMonitor:{hasFocus:true},currentWorkspaces:[{id:'1',name:'1',isDisplayed:false},{id:'2',name:'2',isDisplayed:true},{id:'3',name:'3',isDisplayed:false}],allWorkspaces:[{id:'1'},{id:'2'},{id:'3'}],runCommand:()=>{}},date:{new:new Date(2026,9,10,14,36)},battery:{state:'charging',chargePercent:82},audio:{defaultPlaybackDevice:{name:'Speakers',volume:40,isMuted:false},playbackDevices:[{name:'Speakers',volume:40,isMuted:false}]}});
      connection = {wifi:['Studio WiFi'],bluetooth:['Wireless headphones','Keyboard']};
      return;
    }
    section = currentWidget().name;
    initProviders();
    const win = currentWidget().tauriWindow;
    let disposed = false;
    let scheduled = false;
    let lastSize = '';
    const fit = async () => {
      scheduled = false;
      if (disposed || !pill) return;
      // Older Zebar builds omit workArea, which newer Tauri's monitor wrapper requires.
      const monitor = await invoke<{size:{width:number,height:number},position:{x:number,y:number},scaleFactor:number} | null>('plugin:window|current_monitor');
      if (!monitor || disposed) return;
      const scale = monitor.scaleFactor;
      const barWidth = Math.ceil(pill.getBoundingClientRect().width);
      const edgeInset = 4; // Plus 4px of internal shadow padding: visible edge is 8px in.
      const width = Math.min(monitor.size.width / scale - edgeInset*2, Math.max(barWidth, popup && panel ? Math.ceil(panel.getBoundingClientRect().width) : 0) + 8);
      const height = popup && panel ? Math.ceil(panel.getBoundingClientRect().bottom) + 4 : 44;
      const key = `${width},${height},${monitor.position.x},${monitor.position.y},${scale}`;
      if (key === lastSize) return;
      lastSize = key;
      await win.setSize(new LogicalSize(width,height));
      // Keep the screen-facing edge fixed, including when a dropdown widens the window.
      const x = section === 'mode' ? monitor.position.x + edgeInset*scale : section === 'workspaces' ? monitor.position.x + (monitor.size.width-width*scale)/2 : monitor.position.x + monitor.size.width - (width+edgeInset)*scale;
      // The transparent window has 4px internal padding; its visible pill starts at y+4px.
      await win.setPosition(new PhysicalPosition(Math.round(x), monitor.position.y));
    };
    resize = () => { if (!scheduled && !disposed) { scheduled = true; requestAnimationFrame(() => { void fit().catch(console.error); }); } };
    const observer = new ResizeObserver(resize);
    observer.observe(pill);
    if (panel) observer.observe(panel);
    const unlisten = win.onFocusChanged(({payload}) => { if (!payload) popup = ''; });
    const geometryTimer = setInterval(resize,2000);
    let connectionTimer: ReturnType<typeof setInterval> | undefined;
    if (section === 'status') { void refreshConnections(); connectionTimer = setInterval(refreshConnections,20000); }
    resize();
    return () => { disposed=true; observer.disconnect();clearInterval(geometryTimer);if(connectionTimer)clearInterval(connectionTimer);void unlisten.then(stop=>stop()); };
  });
  $effect(() => { popup; mode; clock; connection; resize(); });
</script>

<svelte:window onkeydown={(e) => {if(e.key==='Escape')popup='';}} onpointerdown={(e) => {if(popup && !(e.target as HTMLElement).closest('.info-button,.dropdown'))popup='';}} />
<div class="pill-wrap {section}">
  <div class="pill" bind:this={pill}>
    {#if section === 'mode'}
      <span class="mode-dot" class:active={mode !== 'Normal'}></span><span class="mode-label">{mode}</span>
    {:else if section === 'workspaces'}
      <Workspaces />
    {:else}
      <VolumeControl onclick={() => toggle('audio')} />
      <button class="info-button" class:connected={!!connection?.wifi.length} aria-label="Wi-Fi information" aria-expanded={popup==='wifi'} onclick={() => toggle('wifi')}>{#if connection?.wifi.length}<Wifi />{:else}<WifiOff />{/if}</button>
      <button class="info-button" class:connected={!!connection?.bluetooth.length} aria-label="Bluetooth information" aria-expanded={popup==='bluetooth'} onclick={() => toggle('bluetooth')}>{#if connection?.bluetooth.length}<Bluetooth />{:else}<BluetoothOff />{/if}</button>
      <span class="separator"></span><span class="battery"><Battery /></span><span class="separator"></span><span class="tabular clock">{clock}</span>
    {/if}
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
