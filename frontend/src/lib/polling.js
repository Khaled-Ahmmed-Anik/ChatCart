export const ACTIVE_POLL_INTERVAL_MS = 15_000;
export const FAILED_POLL_INTERVAL_MS = 60_000;

export function pollInterval(query) {
  return query.state.status === "error" ? FAILED_POLL_INTERVAL_MS : ACTIVE_POLL_INTERVAL_MS;
}
