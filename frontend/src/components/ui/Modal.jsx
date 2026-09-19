import { useEffect, useRef } from "react";

export function Modal({ title, open, onClose, children }) {
  const ref = useRef(null);
  useEffect(() => { const dialog=ref.current; if(open && !dialog.open) dialog.showModal(); if(!open && dialog.open) dialog.close(); }, [open]);
  return <dialog ref={ref} onCancel={onClose} onClose={onClose}><div className="modal-header"><h2>{title}</h2><button className="icon-button" type="button" onClick={onClose} aria-label="Close">×</button></div><div className="modal-body">{children}</div></dialog>;
}
