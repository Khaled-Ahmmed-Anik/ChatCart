export function Brand({ subtitle = "Commerce workspace", className = "" }) {
  return <div className={`brand-lockup ${className}`}>
    <img src="/brand/chatcart-mark.svg" width="42" height="42" alt="" />
    <div><strong>Chat<span>Cart</span></strong><small>{subtitle}</small></div>
  </div>;
}
