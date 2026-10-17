import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/useAuth";
import { Brand } from "../components/ui/Brand";

export function LoginPage() {
  const { auth, login } = useAuth();
  const navigate = useNavigate();
  const [level, setLevel] = useState("business");
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  if (auth) return <Navigate to={auth.actorType === "platform_administrator" ? "/admin/businesses" : "/app"} replace />;

  async function submit(event) {
    event.preventDefault();
    setError("");
    setPending(true);
    const data = new FormData(event.currentTarget);
    try {
      const result = await login({ level, email: data.get("email"), password: data.get("password") });
      navigate(result.actorType === "platform_administrator" ? "/admin/businesses" : "/app", { replace: true });
    } catch (reason) {
      setError(reason.message);
    } finally {
      setPending(false);
    }
  }

  return <main className="login-page">
    <section className="login-story">
      <Brand subtitle="Conversations into commerce" />
      <div className="login-introduction">
        <p className="eyebrow">Your shop. One workspace.</p>
        <h1>Good conversations.<br />More possibilities.</h1>
        <p>Help buyers discover your products, turn conversations into orders, and step in when a personal reply matters.</p>
        <div className="login-capabilities"><span>Bangla</span><span>Banglish</span><span>English</span></div>
      </div>
      <p className="login-story-footer">Built for the people behind small businesses.</p>
    </section>
    <section className="login-card" aria-labelledby="login-heading">
      <Brand className="login-mobile-brand" />
      <p className="eyebrow">Welcome back</p>
      <h2 id="login-heading">Sign in to your {level === "admin" ? "platform" : "shop"}</h2>
      <p className="muted">Your conversations, products, and orders in one place.</p>
      <fieldset className="workspace-choice" disabled={pending}>
        <legend>Workspace</legend>
        <div className="segmented">{[["business", "Business"], ["admin", "Platform admin"]].map(([value, label]) =>
          <button key={value} type="button" aria-pressed={level === value} className={level === value ? "active" : ""} onClick={() => { setLevel(value); setError(""); }}>{label}</button>
        )}</div>
      </fieldset>
      <form onSubmit={submit} aria-busy={pending}>
        <label>Email<input name="email" type="email" autoComplete="username" placeholder="you@example.com" required disabled={pending} /></label>
        <label htmlFor="login-password">Password</label>
        <div className="password-field">
          <input id="login-password" name="password" type={showPassword ? "text" : "password"} autoComplete="current-password" required disabled={pending} />
          <button type="button" aria-controls="login-password" aria-pressed={showPassword} onClick={() => setShowPassword(!showPassword)}>{showPassword ? "Hide" : "Show"}</button>
        </div>
        {error && <p className="form-error" role="alert">{error}</p>}
        <button className="login-submit" disabled={pending}>{pending ? "Signing in…" : "Sign in"}</button>
      </form>
      <footer className="login-links"><Link to="/privacy">Privacy policy</Link><Link to="/data-deletion">Data deletion</Link></footer>
    </section>
  </main>;
}
