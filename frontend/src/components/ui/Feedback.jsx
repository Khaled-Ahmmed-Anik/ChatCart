import { useEffect, useState } from "react";

const SLOW_LOAD_DELAY_MS = 8000;

export function LoadingState() {
  const [slow, setSlow] = useState(false);
  useEffect(() => {
    const timer = setTimeout(() => setSlow(true), SLOW_LOAD_DELAY_MS);
    return () => clearTimeout(timer);
  }, []);
  return <div className="panel state" role="status">{slow ? "Still loading. The server may be waking up; this can take a little longer." : "Loading…"}</div>;
}
export function EmptyState({ title="Nothing here yet", description }) { return <div className="state"><strong>{title}</strong>{description && <p>{description}</p>}</div>; }
export function ErrorState({ error }) { return <div className="panel state error" role="alert">{error?.message || "Something went wrong."}</div>; }
