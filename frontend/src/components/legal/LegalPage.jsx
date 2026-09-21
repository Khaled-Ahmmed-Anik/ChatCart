import { Link } from "react-router-dom";

export function LegalPage({ eyebrow, title, updatedAt, children }) {
  return (
    <main className="legal-page">
      <article className="legal-document">
        <header className="legal-header">
          <Link className="legal-brand" to="/login">ChatCart</Link>
          <p className="legal-eyebrow">{eyebrow}</p>
          <h1>{title}</h1>
          <p className="legal-updated">Last updated: {updatedAt}</p>
        </header>
        <div className="legal-content">{children}</div>
        <footer className="legal-footer">
          <Link to="/privacy">Privacy Policy</Link>
          <Link to="/data-deletion">Data Deletion</Link>
          <Link to="/login">Business sign in</Link>
        </footer>
      </article>
    </main>
  );
}
