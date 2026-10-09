/** n8n can take a few seconds to serve after its pod is ready, so a check retries before it fails. */
export async function retry<T>(fn: () => Promise<T>, { attempts = 10, delayMs = 2000 } = {}): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await fn();
    } catch (e) {
      if (attempt >= attempts) throw e;
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}
