import { useSyncExternalStore } from "react";
import { KEYS, readJSON, writeJSON } from "@/lib/storage";
import type { Cart, CartLine, CheckoutDraft, Order, Profile } from "@/domain/commerce";
import { supabase } from "@/lib/supabase";
import { accountRepository, cartRepository, wishlistRepository } from "@/repositories";

interface OguraState {
  cart: Cart;
  buyNow: CartLine | null;
  wishlist: string[];
  recentlyViewed: string[];
  searchHistory: string[];
  checkoutDraft: CheckoutDraft | null;
  profile: Profile;
  orders: Order[];
  hydrated: boolean;
}

export const EMPTY_DRAFT: CheckoutDraft = {
  email: "",
  phone: "",
  address: { fullName: "", phone: "", line1: "", line2: "", city: "", state: "", pincode: "" },
  deliveryMethod: "standard",
  coupon: "",
  paymentMethod: "upi",
};

const GUEST: Profile = { name: "", email: "", phone: "", signedIn: false };

let state: OguraState = {
  cart: { lines: [] },
  buyNow: null,
  wishlist: [],
  recentlyViewed: [],
  searchHistory: [],
  checkoutDraft: null,
  profile: GUEST,
  orders: [],
  hydrated: false,
};

const listeners = new Set<() => void>();

function emit() {
  listeners.forEach((l) => l());
}

function set(patch: Partial<OguraState>) {
  state = { ...state, ...patch };
  emit();
}

let authSubscribed = false;

async function syncWithBackend(): Promise<void> {
  const { data: authData } = await supabase.auth.getUser();
  if (authData.user && supabase.isConfigured()) {
    try {
      const [profile, , cart, wishlist, orders] = await Promise.all([
        accountRepository.getProfile(),
        cartRepository.mergeGuestCart?.() ?? Promise.resolve(false),
        cartRepository.getCart(),
        wishlistRepository.list(),
        accountRepository.listOrders(),
      ]);

      set({
        profile: { ...profile, signedIn: true },
        cart,
        wishlist,
        orders,
      });
    } catch {
      // Graceful fallback to current memory state
    }
  } else {
    // Unauthenticated guest
    try {
      const [cart, wishlist] = await Promise.all([
        cartRepository.getCart(),
        wishlistRepository.list(),
      ]);
      set({
        profile: GUEST,
        cart,
        wishlist,
        orders: [],
      });
    } catch {
      // Retain memory state
    }
  }
}

export function hydrate(): void {
  if (state.hydrated) return;

  state = {
    cart: readJSON<Cart>(KEYS.cart, { lines: [] }),
    buyNow: readJSON<CartLine | null>(KEYS.buyNow, null),
    wishlist: readJSON<string[]>(KEYS.wishlist, []),
    recentlyViewed: readJSON<string[]>(KEYS.recentlyViewed, []),
    searchHistory: readJSON<string[]>(KEYS.searchHistory, []),
    checkoutDraft: readJSON<CheckoutDraft | null>(KEYS.checkoutDraft, null),
    profile: GUEST,
    orders: [],
    hydrated: true,
  };
  emit();

  if (!authSubscribed) {
    authSubscribed = true;
    supabase.auth.onAuthStateChange(async (_event) => {
      await syncWithBackend();
    });
  }

  void syncWithBackend();
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function useOguraState<T>(selector: (s: OguraState) => T): T {
  return useSyncExternalStore(
    subscribe,
    () => selector(state),
    () => selector(state),
  );
}

export function getState(): OguraState {
  return state;
}

/* -------------------------------------------------- cart */

export function addToCart(productId: string, variantId: string, quantity = 1): Cart {
  const safeQty = Math.max(1, Math.min(10, Math.floor(quantity) || 1));
  const existing = state.cart.lines.find((l) => l.variantId === variantId);
  let lines: CartLine[];
  if (existing) {
    lines = state.cart.lines.map((l) =>
      l.variantId === variantId ? { ...l, quantity: Math.min(10, l.quantity + safeQty) } : l,
    );
  } else {
    lines = [
      ...state.cart.lines,
      {
        id: `${variantId}-${Date.now()}`,
        productId,
        variantId,
        quantity: safeQty,
        addedAt: Date.now(),
      },
    ];
  }
  const cart = { lines };
  set({ cart });

  // Async persist to certified repository
  void cartRepository.addVariant(productId, variantId, safeQty).then((updated) => {
    if (updated && updated.lines) {
      set({ cart: updated });
    }
  });

  return cart;
}

export function updateCartQuantity(lineId: string, quantity: number): Cart {
  const safeQty = Math.max(0, Math.min(10, quantity));
  const lines = state.cart.lines
    .map((l) => (l.id === lineId ? { ...l, quantity: safeQty } : l))
    .filter((l) => l.quantity > 0);
  const cart = { lines };
  set({ cart });

  void cartRepository.updateQuantity(lineId, safeQty).then((updated) => {
    if (updated && updated.lines) {
      set({ cart: updated });
    }
  });

  return cart;
}

export function removeCartLine(lineId: string): Cart {
  const cart = { lines: state.cart.lines.filter((l) => l.id !== lineId) };
  set({ cart });

  void cartRepository.removeLine(lineId).then((updated) => {
    if (updated && updated.lines) {
      set({ cart: updated });
    }
  });

  return cart;
}

export function clearCart(): Cart {
  const cart = { lines: [] };
  set({ cart });
  void cartRepository.clearCart();
  return cart;
}

export function setBuyNow(line: CartLine | null): void {
  set({ buyNow: line });
  writeJSON(KEYS.buyNow, line);
}

/* -------------------------------------------------- wishlist */

export function toggleWishlist(productId: string): string[] {
  const wishlist = state.wishlist.includes(productId)
    ? state.wishlist.filter((id) => id !== productId)
    : [productId, ...state.wishlist];
  set({ wishlist });

  void wishlistRepository.toggle(productId).then((updated) => {
    if (updated) {
      set({ wishlist: updated });
    }
  });

  return wishlist;
}

/* -------------------------------------------------- recently viewed */

export function pushRecentlyViewed(productId: string): void {
  const recentlyViewed = [productId, ...state.recentlyViewed.filter((id) => id !== productId)].slice(0, 12);
  set({ recentlyViewed });
  writeJSON(KEYS.recentlyViewed, recentlyViewed);
}

/* -------------------------------------------------- search */

export function pushSearchHistory(term: string): void {
  const clean = term.trim();
  if (!clean) return;
  const searchHistory = [clean, ...state.searchHistory.filter((t) => t !== clean)].slice(0, 8);
  set({ searchHistory });
  writeJSON(KEYS.searchHistory, searchHistory);
}

export function clearSearchHistory(): void {
  set({ searchHistory: [] });
  writeJSON(KEYS.searchHistory, []);
}

/* -------------------------------------------------- checkout / account */

export function saveCheckoutDraft(draft: CheckoutDraft): void {
  set({ checkoutDraft: draft });
  writeJSON(KEYS.checkoutDraft, draft);
}

export function saveOrder(order: Order): void {
  const orders = [order, ...state.orders.filter((o) => o.orderNumber !== order.orderNumber)];
  set({ orders });
}

export function signIn(profile: Profile): void {
  set({ profile: { ...profile, signedIn: true } });
  void syncWithBackend();
}

export function signOut(): void {
  set({ profile: GUEST, orders: [] });
  void supabase.auth.signOut().then(() => {
    void syncWithBackend();
  });
}
