import { resolveDataMode, type DataMode } from "./dataMode";

export const appMode = {
  get dataMode(): DataMode {
    return resolveDataMode();
  },
  frontendOnly: false,
  paymentsEnabled: false,
  uploadsEnabled: false,
  authEnabled: true,
  showPlaceholderLabels: false,
} as const;

export type AppMode = typeof appMode;

