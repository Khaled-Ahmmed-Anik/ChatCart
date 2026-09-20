import { useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/useAuth";

export function LoginPage() {
  const { auth, login } = useAuth(); const navigate=useNavigate();
  const [level,setLevel]=useState("business"); const [error,setError]=useState(""); const [pending,setPending]=useState(false);
  if(auth) return <Navigate to={auth.actorType === "platform_administrator" ? "/admin/businesses" : "/app"} replace />;
  async function submit(event){event.preventDefault();setError("");setPending(true);const data=new FormData(event.currentTarget);try{const result=await login({level,email:data.get("email"),password:data.get("password")});navigate(result.actorType === "platform_administrator" ? "/admin/businesses" : "/app",{replace:true});}catch(reason){setError(reason.message);}finally{setPending(false);}}
  return <main className="login-page"><section className="login-story"><div className="brand large"><span>CC</span><div>ChatCart<small>Conversational commerce</small></div></div><div><p className="eyebrow">Sell through conversation</p><h1>Turn customer messages into confirmed orders.</h1><p>Manage products, conversations, orders, delivery and sales performance from one focused workspace.</p></div></section><section className="login-card"><p className="eyebrow">Secure access</p><h2>Sign in to ChatCart</h2><p className="muted">Choose the workspace that matches your account.</p><div className="segmented"><button type="button" className={level==="business"?"active":""} onClick={()=>setLevel("business")}>Business</button><button type="button" className={level==="admin"?"active":""} onClick={()=>setLevel("admin")}>Platform admin</button></div><form onSubmit={submit}><label>Email<input name="email" type="email" autoComplete="username" required /></label><label>Password<input name="password" type="password" autoComplete="current-password" required /></label>{error&&<p className="form-error" role="alert">{error}</p>}<button disabled={pending}>{pending?"Signing in…":"Sign in"}</button></form></section></main>;
}
