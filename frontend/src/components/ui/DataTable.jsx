import { EmptyState } from "./Feedback";

export function DataTable({ columns, rows, getRowKey=(row)=>row.id, emptyMessage }) {
  if (!rows.length) return <EmptyState description={emptyMessage} />;
  return <div className="table-wrap"><table><thead><tr>{columns.map(column=><th key={column.key}>{column.label}</th>)}</tr></thead><tbody>{rows.map(row=><tr key={getRowKey(row)}>{columns.map(column=><td key={column.key}>{column.render ? column.render(row) : row[column.key]}</td>)}</tr>)}</tbody></table></div>;
}
