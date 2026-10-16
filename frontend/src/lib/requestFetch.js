const REQUEST_TIMEOUT_MS = 60000;

export async function requestFetch(input, options = {}) {
  try {
    return await fetch(input, { ...options, signal: options.signal || AbortSignal.timeout(REQUEST_TIMEOUT_MS) });
  } catch (error) {
    if (error?.name === "TimeoutError") {
      throw new Error("The server took too long to respond. Refresh to reconnect. If you were saving a change, check whether it was saved before submitting again.", { cause: error });
    }
    throw error;
  }
}
