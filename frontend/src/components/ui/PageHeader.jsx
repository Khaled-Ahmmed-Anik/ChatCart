export function PageHeader({ eyebrow="AI-assisted commerce", title, description, actions }) {
  return <header className="page-header"><div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1>{description && <p className="muted">{description}</p>}</div>{actions && <div className="actions">{actions}</div>}</header>;
}
