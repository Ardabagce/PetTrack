import { create } from 'zustand';
import type { ParsedReport } from './parser';

/** Transient UI state shared across screens (not persisted). */
export const useUI = create<{ previewHtml: string | null; toast: string | null; scanDraft: { report: ParsedReport; image?: string } | null }>(() => ({ previewHtml: null, toast: null, scanDraft: null }));

export function showPreview(html: string) {
  useUI.setState({ previewHtml: html });
}

export function toast(message: string) {
  useUI.setState({ toast: message });
  setTimeout(() => useUI.setState((s) => (s.toast === message ? { toast: null } : s)), 2200);
}
