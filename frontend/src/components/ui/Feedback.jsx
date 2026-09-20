export function LoadingState() { return <div className="panel state">Loading…</div>; }
export function EmptyState({ title="Nothing here yet", description }) { return <div className="state"><strong>{title}</strong>{description && <p>{description}</p>}</div>; }
export function ErrorState({ error }) { return <div className="panel state error" role="alert">{error?.message || "Something went wrong."}</div>; }
