export function readJSON<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export function writeJSON(key: string, value: unknown): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* storage unavailable */
  }
}

export const KEYS = {
  cart: "ogura.cart",
  buyNow: "ogura.buyNow",
  wishlist: "ogura.wishlist",
  recentlyViewed: "ogura.recentlyViewed",
  searchHistory: "ogura.searchHistory",
  checkoutDraft: "ogura.checkoutDraft",
  session: "ogura.session",
  orders: "ogura.orders",
  addresses: "ogura.addresses",
  reviews: "ogura.reviews",
} as const;
