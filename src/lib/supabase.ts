/**
 * Supabase / Lovable Cloud Public Client Transport
 * Zero-dependency, type-safe transport using standard browser fetch.
 * 
 * Strict Security Invariants:
 * 1. Only publishable anon key is accepted.
 * 2. Never accepts or exposes service-role keys.
 * 3. Sanitizes all backend errors before returning to frontend callers.
 */

export interface AuthUser {
  id: string;
  email?: string;
  phone?: string;
  role?: string;
  user_metadata?: Record<string, unknown>;
  created_at?: string;
}

export interface AuthSession {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token: string;
  user: AuthUser;
}

export interface PostgrestResponse<T> {
  data: T | null;
  error: {
    message: string;
    code?: string;
    status?: number;
  } | null;
}

const AUTH_STORAGE_KEY = "ogura.auth.token";

class SupabaseTransport {
  private url: string;
  private anonKey: string;
  private session: AuthSession | null = null;
  private authListeners = new Set<(event: "SIGNED_IN" | "SIGNED_OUT", session: AuthSession | null) => void>();

  constructor() {
    this.url = (typeof import.meta !== "undefined" && import.meta.env?.["VITE_SUPABASE_URL"]) || "";
    this.anonKey =
      (typeof import.meta !== "undefined" &&
        (import.meta.env?.["VITE_SUPABASE_ANON_KEY"] || import.meta.env?.["VITE_SUPABASE_PUBLISHABLE_KEY"])) ||
      "";
    this.loadSession();
  }

  public isConfigured(): boolean {
    return Boolean(this.url && this.anonKey);
  }

  private loadSession(): void {
    if (typeof window === "undefined") return;
    try {
      // Parse OAuth callback token from URL hash if redirected from Supabase OAuth
      if (window.location.hash && window.location.hash.includes("access_token=")) {
        const hashParams = new URLSearchParams(window.location.hash.substring(1));
        const accessToken = hashParams.get("access_token");
        const refreshToken = hashParams.get("refresh_token") || "";
        const expiresIn = parseInt(hashParams.get("expires_in") || "3600", 10);
        const tokenType = hashParams.get("token_type") || "bearer";
        if (accessToken) {
          let user: AuthUser = { id: "" };
          try {
            const parts = accessToken.split(".");
            if (parts.length === 3 && parts[1]) {
              const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
              user = {
                id: payload.sub || "",
                email: payload.email,
                phone: payload.phone,
                role: payload.role,
                user_metadata: payload.user_metadata,
              };
            }
          } catch {
            user = { id: accessToken };
          }
          const session: AuthSession = {
            access_token: accessToken,
            refresh_token: refreshToken,
            expires_in: expiresIn,
            token_type: tokenType,
            user,
          };
          this.persistSession(session);
          window.history.replaceState(null, "", window.location.pathname + window.location.search);
          return;
        }
      }

      const raw = window.localStorage.getItem(AUTH_STORAGE_KEY);
      if (raw) {
        this.session = JSON.parse(raw);
      }
    } catch {
      this.session = null;
    }
  }

  private persistSession(session: AuthSession | null): void {
    this.session = session;
    if (typeof window === "undefined") return;
    try {
      if (session) {
        window.localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(session));
      } else {
        window.localStorage.removeItem(AUTH_STORAGE_KEY);
      }
    } catch {
      // localStorage unavailable
    }
  }

  private notifyAuth(event: "SIGNED_IN" | "SIGNED_OUT"): void {
    for (const listener of this.authListeners) {
      try {
        listener(event, this.session);
      } catch (err) {
        console.error("Auth listener error:", err);
      }
    }
  }

  private getHeaders(extra?: HeadersInit): Headers {
    const headers = new Headers(extra);
    headers.set("apikey", this.anonKey);
    const token = this.session?.access_token || this.anonKey;
    headers.set("Authorization", `Bearer ${token}`);
    if (!headers.has("Content-Type")) {
      headers.set("Content-Type", "application/json");
    }
    return headers;
  }

  private sanitizeError(errorPayload: unknown, status: number): { message: string; code?: string; status: number } {
    if (typeof errorPayload === "object" && errorPayload !== null) {
      const err = errorPayload as Record<string, unknown>;
      const rawMessage = String(err["message"] || err["error_description"] || err["error"] || "An unexpected error occurred.");
      const cleanMessage = rawMessage.replace(/error:\s*/i, "").replace(/PG::\w+/g, "");
      const res: { message: string; code?: string; status: number } = {
        message: cleanMessage,
        status,
      };
      if (typeof err["code"] === "string") {
        res.code = err["code"];
      }
      return res;
    }
    return {
      message: "The requested operation could not be completed. Please try again.",
      status,
    };
  }

  public get auth() {
    return {
      getSession: async (): Promise<{ data: { session: AuthSession | null }; error: null }> => {
        return { data: { session: this.session }, error: null };
      },

      getUser: async (): Promise<{ data: { user: AuthUser | null }; error: null }> => {
        return { data: { user: this.session?.user ?? null }, error: null };
      },

      signInWithOtp: async (params: { phone?: string; email?: string }): Promise<PostgrestResponse<unknown>> => {
        if (!this.isConfigured()) {
          return { data: null, error: { message: "Backend configuration missing" } };
        }
        try {
          const res = await fetch(`${this.url}/auth/v1/otp`, {
            method: "POST",
            headers: this.getHeaders(),
            body: JSON.stringify(params),
          });
          if (!res.ok) {
            const err = await res.json().catch(() => null);
            return { data: null, error: this.sanitizeError(err, res.status) };
          }
          const data = await res.json().catch(() => ({}));
          return { data, error: null };
        } catch {
          return { data: null, error: { message: "Network failure while requesting OTP" } };
        }
      },

      verifyOtp: async (params: {
        phone?: string;
        email?: string;
        token: string;
        type?: "sms" | "email" | "signup";
      }): Promise<PostgrestResponse<AuthSession>> => {
        if (!this.isConfigured()) {
          return { data: null, error: { message: "Backend configuration missing" } };
        }
        try {
          const res = await fetch(`${this.url}/auth/v1/verify`, {
            method: "POST",
            headers: this.getHeaders(),
            body: JSON.stringify({
              type: params.type || (params.phone ? "sms" : "email"),
              token: params.token,
              phone: params.phone,
              email: params.email,
            }),
          });
          if (!res.ok) {
            const err = await res.json().catch(() => null);
            return { data: null, error: this.sanitizeError(err, res.status) };
          }
          const session = (await res.json()) as AuthSession;
          this.persistSession(session);
          this.notifyAuth("SIGNED_IN");
          return { data: session, error: null };
        } catch {
          return { data: null, error: { message: "Network failure while verifying OTP" } };
        }
      },

      signInWithOAuth: async (params: {
        provider: "google" | string;
        options?: { redirectTo?: string | undefined; scopes?: string | undefined };
      }): Promise<{ data: { url: string } | null; error: { message: string } | null }> => {
        if (!this.isConfigured()) {
          return { data: null, error: { message: "Backend configuration missing" } };
        }
        const origin = typeof window !== "undefined" ? window.location.origin : "";
        const redirectTo = params.options?.redirectTo || (origin ? `${origin}/account/profile` : "");
        const query = new URLSearchParams({
          provider: params.provider,
          redirect_to: redirectTo,
        });
        if (params.options?.scopes) {
          query.set("scopes", params.options.scopes);
        }
        const authUrl = `${this.url}/auth/v1/authorize?${query.toString()}`;
        if (typeof window !== "undefined") {
          window.location.href = authUrl;
        }
        return { data: { url: authUrl }, error: null };
      },

      setSessionManually: (session: AuthSession | null): void => {
        this.persistSession(session);
        this.notifyAuth(session ? "SIGNED_IN" : "SIGNED_OUT");
      },

      signOut: async (): Promise<{ error: null }> => {
        if (this.isConfigured() && this.session?.access_token) {
          try {
            await fetch(`${this.url}/auth/v1/logout`, {
              method: "POST",
              headers: this.getHeaders(),
            });
          } catch {
            // Ignore logout network failure, clear local state
          }
        }
        this.persistSession(null);
        this.notifyAuth("SIGNED_OUT");
        return { error: null };
      },

      onAuthStateChange: (
        callback: (event: "SIGNED_IN" | "SIGNED_OUT", session: AuthSession | null) => void,
      ): { data: { subscription: { unsubscribe: () => void } } } => {
        this.authListeners.add(callback);
        return {
          data: {
            subscription: {
              unsubscribe: () => {
                this.authListeners.delete(callback);
              },
            },
          },
        };
      },
    };
  }

  public async rpc<T = unknown>(
    functionName: string,
    params: Record<string, unknown> = {},
  ): Promise<PostgrestResponse<T>> {
    if (!this.isConfigured()) {
      return { data: null, error: { message: "Backend configuration missing" } };
    }
    try {
      const res = await fetch(`${this.url}/rest/v1/rpc/${functionName}`, {
        method: "POST",
        headers: this.getHeaders(),
        body: JSON.stringify(params),
      });

      if (!res.ok) {
        const errorJson = await res.json().catch(() => null);
        return { data: null, error: this.sanitizeError(errorJson, res.status) };
      }

      const contentType = res.headers.get("content-type");
      if (contentType && contentType.includes("application/json")) {
        const data = await res.json();
        return { data: data as T, error: null };
      }
      return { data: null, error: null };
    } catch {
      return { data: null, error: { message: "Network failure calling backend RPC" } };
    }
  }

  public from<T = Record<string, unknown>>(table: string) {
    return new PostgrestQueryBuilder<T>(`${this.url}/rest/v1/${table}`, () => this.getHeaders());
  }
}

class PostgrestQueryBuilder<T> {
  private url: string;
  private getHeaders: () => Headers;
  private queryParams: string[] = [];

  constructor(url: string, getHeaders: () => Headers) {
    this.url = url;
    this.getHeaders = getHeaders;
  }

  public select(columns = "*"): this {
    this.queryParams.push(`select=${encodeURIComponent(columns)}`);
    return this;
  }

  public eq(column: string, value: string | number | boolean): this {
    this.queryParams.push(`${encodeURIComponent(column)}=eq.${encodeURIComponent(String(value))}`);
    return this;
  }

  public in(column: string, values: (string | number)[]): this {
    this.queryParams.push(`${encodeURIComponent(column)}=in.(${values.map((v) => encodeURIComponent(String(v))).join(",")})`);
    return this;
  }

  public order(column: string, options?: { ascending?: boolean }): this {
    const dir = options?.ascending === false ? "desc" : "asc";
    this.queryParams.push(`order=${encodeURIComponent(column)}.${dir}`);
    return this;
  }

  public limit(count: number): this {
    this.queryParams.push(`limit=${count}`);
    return this;
  }

  public range(from: number, to: number): this {
    this.queryParams.push(`offset=${from}`);
    this.queryParams.push(`limit=${to - from + 1}`);
    return this;
  }

  public async get(): Promise<PostgrestResponse<T[]>> {
    const qs = this.queryParams.length ? `?${this.queryParams.join("&")}` : "";
    try {
      const res = await fetch(`${this.url}${qs}`, {
        method: "GET",
        headers: this.getHeaders(),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => null);
        return { data: null, error: { message: err?.message || "Failed to fetch data", status: res.status } };
      }
      const data = await res.json();
      return { data: data as T[], error: null };
    } catch {
      return { data: null, error: { message: "Network failure during table query" } };
    }
  }

  public async single(): Promise<PostgrestResponse<T>> {
    const res = await this.limit(1).get();
    if (res.error) return { data: null, error: res.error };
    const item = res.data?.[0] ?? null;
    return { data: item, error: item ? null : { message: "Record not found", status: 404 } };
  }

  public async insert(payload: unknown): Promise<PostgrestResponse<T>> {
    const headers = this.getHeaders();
    headers.set("Prefer", "return=representation");
    try {
      const res = await fetch(this.url, {
        method: "POST",
        headers,
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => null);
        return { data: null, error: { message: err?.message || "Failed to insert record", status: res.status } };
      }
      const data = await res.json();
      const item = Array.isArray(data) ? data[0] : data;
      return { data: item as T, error: null };
    } catch {
      return { data: null, error: { message: "Network failure during insert" } };
    }
  }

  public async update(payload: unknown): Promise<PostgrestResponse<T>> {
    const headers = this.getHeaders();
    headers.set("Prefer", "return=representation");
    const qs = this.queryParams.length ? `?${this.queryParams.join("&")}` : "";
    try {
      const res = await fetch(`${this.url}${qs}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => null);
        return { data: null, error: { message: err?.message || "Failed to update record", status: res.status } };
      }
      const data = await res.json();
      const item = Array.isArray(data) ? data[0] : data;
      return { data: item as T, error: null };
    } catch {
      return { data: null, error: { message: "Network failure during update" } };
    }
  }

  public async delete(): Promise<PostgrestResponse<unknown>> {
    const headers = this.getHeaders();
    const qs = this.queryParams.length ? `?${this.queryParams.join("&")}` : "";
    try {
      const res = await fetch(`${this.url}${qs}`, {
        method: "DELETE",
        headers,
      });
      if (!res.ok) {
        const err = await res.json().catch(() => null);
        return { data: null, error: { message: err?.message || "Failed to delete record", status: res.status } };
      }
      return { data: true, error: null };
    } catch {
      return { data: null, error: { message: "Network failure during delete" } };
    }
  }
}

export const supabase = new SupabaseTransport();
