// Only dropdown height changes require native resizing. Serialize requests so
// closing a dropdown during an in-flight resize always wins. Retry failed sizes.
export function createResizeQueue(apply, report = console.error) {
  let requested = null;
  let applied = null;
  let running = false;
  let disposed = false;
  async function drain() {
    if (running || disposed) return;
    running = true;
    try {
      while (!disposed && requested !== applied) {
        const next = requested;
        try { await apply(next); applied = next; }
        catch (error) { report(error); if (requested === next) break; }
      }
    } finally { running = false; }
  }
  return {
    request(height) { requested = height; return drain(); },
    dispose() { disposed = true; }
  };
}
