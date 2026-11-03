import { useEffect, useState } from "react";

const SLOW_LOAD_DELAY_MS = 8000;
const SKELETON_DELAY_MS = 300;

export function LoadingState() {
  const [slow, setSlow] = useState(false);
  const [showSkeleton, setShowSkeleton] = useState(false);
  useEffect(() => {
    const skeletonTimer = setTimeout(() => setShowSkeleton(true), SKELETON_DELAY_MS);
    const timer = setTimeout(() => setSlow(true), SLOW_LOAD_DELAY_MS);
    return () => { clearTimeout(timer); clearTimeout(skeletonTimer); };
  }, []);
  return <div className="panel state" role="status">
    {showSkeleton && <div className="loading-skeleton" aria-hidden="true"><span /><span /><span /></div>}
    <span>{slow ? "Still loading. The server may be waking up; this can take a little longer." : "Loading…"}</span>
  </div>;
}
export function EmptyState({ title="Nothing here yet", description, actions }) {
  return <div className="state"><strong>{title}</strong>{description && <p>{description}</p>}{actions && <div className="actions">{actions}</div>}</div>;
}
export function ErrorState({ error, onRetry }) {
  return <div className="panel state error" role="alert">
    <strong>We couldn’t load this section</strong>
    <p>Please try again. No changes were submitted by this request.</p>
    {Number.isInteger(error?.status) && <small>Error code {error.status}</small>}
    {onRetry && <button type="button" onClick={onRetry}>Try again</button>}
  </div>;
}
