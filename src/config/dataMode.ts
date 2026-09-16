/**
 * OGURA DATA MODE & ENVIRONMENT CONFIGURATION GUARD
 *
 * Enforces explicit separation between Development and Production environments
 * and guarantees FAIL-CLOSED behavior in production.
 *
 * Core Invariants:
 * 1. DEVELOPMENT + EXPLICIT MOCK MODE:
 *    VITE_DATA_MODE="mock" allows mock repositories for offline local development.
 * 2. DEVELOPMENT + BACKEND MODE:
 *    VITE_DATA_MODE="backend" (or unconfigured default when backend is present)
 *    routes strictly to production backend repositories.
 * 3. PRODUCTION + BACKEND CONFIG MISSING:
 *    FAIL CLOSED. Mock repositories are strictly forbidden in production.
 *    Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY halts execution immediately.
 *    The application will NEVER silently produce a functioning mock commerce application.
 */

export type Environment = "development" | "production" | "test";
export type DataMode = "mock" | "backend";

export function getEnvironment(): Environment {
  if (typeof import.meta !== "undefined" && import.meta.env) {
    if (import.meta.env.PROD === true || import.meta.env.MODE === "production") {
      return "production";
    }
    if (import.meta.env.MODE === "test") {
      return "test";
    }
  }
  return "development";
}

export function isBackendConfigured(): boolean {
  if (typeof import.meta === "undefined" || !import.meta.env) return false;
  return Boolean(
    import.meta.env["VITE_SUPABASE_URL"] &&
    import.meta.env["VITE_SUPABASE_ANON_KEY"]
  );
}

export function resolveDataMode(): DataMode {
  const env = getEnvironment();
  const explicitMode = typeof import.meta !== "undefined" && import.meta.env
    ? import.meta.env["VITE_DATA_MODE"]
    : undefined;
  const configured = isBackendConfigured();

  // 1. PRODUCTION INVARIANTS (FAIL CLOSED)
  if (env === "production") {
    if (explicitMode === "mock") {
      throw new Error(
        "[OGURA FAIL-CLOSED] FATAL: VITE_DATA_MODE='mock' is strictly prohibited in production. " +
        "Mock commerce data cannot be used in production environments."
      );
    }
    if (!configured) {
      throw new Error(
        "[OGURA FAIL-CLOSED] FATAL: Production backend configuration missing. " +
        "Both VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be provided. " +
        "The application will NOT silently fall back to mock repositories in production."
      );
    }
    return "backend";
  }

  // 2. DEVELOPMENT INVARIANTS
  // Development + Explicit Mock Mode:
  if (explicitMode === "mock") {
    return "mock";
  }

  // Development + Backend Mode:
  if (explicitMode === "backend") {
    if (!configured) {
      throw new Error(
        "[OGURA DEV CONFIG ERROR] VITE_DATA_MODE is set to 'backend' but VITE_SUPABASE_URL or " +
        "VITE_SUPABASE_ANON_KEY is missing. Configure .env or explicitly set VITE_DATA_MODE=mock for local mock development."
      );
    }
    return "backend";
  }

  // Default in development when backend configuration is detected:
  if (configured) {
    return "backend";
  }

  // Development with no backend config and no explicit mock mode:
  // FAIL CLOSED: do not silently switch to mock mode.
  throw new Error(
    "[OGURA CONFIG GUARD] Backend configuration missing. To run against local mock data in development, " +
    "you must explicitly set VITE_DATA_MODE=mock in your .env or environment. " +
    "Silent fallback to mock commerce data is strictly prohibited."
  );
}
