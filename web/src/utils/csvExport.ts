/**
 * Shared CSV export helpers used by the Admin and Provider "Reports" tabs.
 *
 * Centralizing this logic fixes a few correctness issues that existed when each
 * export button built its own CSV string by hand:
 *  - Every field is now escaped consistently (embedded quotes, commas, newlines),
 *    instead of only ever escaping one "free text" column per export.
 *  - A UTF-8 BOM is prepended so Excel (the default CSV viewer on Windows, which
 *    this platform's admins/providers use) renders names with special characters
 *    (e.g. "ñ", "é") correctly instead of showing mojibake.
 *  - Fields that start with `=`, `+`, `-`, `@`, or a tab are prefixed with a `'`
 *    to neutralize spreadsheet formula injection — several exported columns
 *    (report reasons, entity/reporter names) come from user-submitted text.
 *  - Downloads go through a Blob + object URL instead of a `data:` URI, which
 *    avoids the URL-length ceilings some browsers impose on data URIs as the
 *    exported dataset grows.
 */

const UTF8_BOM = '﻿';

/** Escapes a single CSV field: stringifies, doubles embedded quotes, wraps in quotes. */
export function escapeCsvField(value: unknown): string {
  const str = value === null || value === undefined ? '' : String(value);
  let escaped = str.replace(/"/g, '""');
  // Guard against CSV/formula injection when the file is opened in Excel/Sheets.
  if (/^[=+\-@\t]/.test(escaped)) {
    escaped = `'${escaped}`;
  }
  return `"${escaped}"`;
}

/** Builds a complete CSV document (with BOM) from headers + rows. */
export function buildCsv(headers: string[], rows: Array<Array<string | number | null | undefined>>): string {
  const lines = [
    headers.map(escapeCsvField).join(','),
    ...rows.map(row => row.map(escapeCsvField).join(',')),
  ];
  return UTF8_BOM + lines.join('\r\n');
}

/** Builds a CSV document and triggers a browser download for it. */
export function downloadCsv(
  filename: string,
  headers: string[],
  rows: Array<Array<string | number | null | undefined>>
): void {
  const csvContent = buildCsv(headers, rows);
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('href', url);
  link.setAttribute('download', filename);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/** Appends today's date (YYYY-MM-DD) to a filename base, e.g. "Report" -> "Report_2026-08-29.csv". */
export function dateStampedFilename(base: string): string {
  return `${base}_${new Date().toISOString().split('T')[0]}.csv`;
}
