/**
 * @param {{ title?: import("react").ReactNode, actions?: import("react").ReactNode,
 * children: import("react").ReactNode, className?: string }} props
 */
export function Panel({ title, actions, children, className="" }) {
  return <section className={`panel ${className}`}>
    {(title || actions) && <div className="panel-header">{title && <h2>{title}</h2>}{actions && <div className="actions">{actions}</div>}</div>}
    {children}
  </section>;
}
