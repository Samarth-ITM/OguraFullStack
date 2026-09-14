export const appMode = {
  dataMode: "mock" as const,
  frontendOnly: true,
  paymentsEnabled: false,
  uploadsEnabled: false,
  authEnabled: false,
  showPlaceholderLabels: true,
} as const;

export type AppMode = typeof appMode;
