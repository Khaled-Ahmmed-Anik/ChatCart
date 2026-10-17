const paths = {
  home: "m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z",
  inbox: "M4 4h16v16H4ZM4 14h5l2 3h2l2-3h5",
  orders: "M7 3h10v3h3v15H4V6h3Zm0 3h10M8 11h8M8 16h5",
  products: "m3 7 9-4 9 4-9 4Zm0 0v10l9 4 9-4V7M12 11v10",
  knowledge: "M12 5C8 2 4 3 2 4v16c3-2 7-2 10 0 3-2 7-2 10 0V4c-2-1-6-2-10 1Zm0 0v15",
  settings: "M4 7h16M4 17h16M8 4v6M16 14v6",
  shops: "M3 9h18l-2-6H5Zm1 0v12h16V9M9 21v-7h6v7",
  logout: "M9 4H4v16h5M9 12h12m-5-5 5 5-5 5",
  bell: "M5 17h14l-2-3V9a5 5 0 0 0-10 0v5Zm5 4h4"
};

export function Icon({ name, size = 20 }) {
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false"><path d={paths[name] || paths.inbox} /></svg>;
}
