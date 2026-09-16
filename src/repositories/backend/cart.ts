import type { Cart, CartLine } from "@/domain/commerce";
import type { CartRepository } from "../contracts";
import { supabase } from "@/lib/supabase";
import { readJSON, writeJSON } from "@/lib/storage";

const GUEST_CART_KEY = "ogura.guest_cart";
const GUEST_SESSION_KEY = "ogura.guest_session_id";

function getOrCreateGuestSessionId(): string {
  if (typeof window === "undefined") return "guest-default";
  let sessionId = window.localStorage.getItem(GUEST_SESSION_KEY);
  if (!sessionId) {
    sessionId = `guest_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    window.localStorage.setItem(GUEST_SESSION_KEY, sessionId);
  }
  return sessionId;
}

function mapBackendCart(data: any): Cart {
  if (!data || !Array.isArray(data.lines)) {
    return { lines: [] };
  }
  const lines: CartLine[] = data.lines.map((l: any) => ({
    id: l.line_id || l.id,
    productId: l.product_id,
    variantId: l.variant_id,
    quantity: Math.max(1, Math.min(10, l.quantity || 1)),
    addedAt: Date.now(),
  }));
  return { lines };
}

export const backendCartRepository: CartRepository & {
  mergeGuestCart: () => Promise<boolean>;
  getGuestSessionId: () => string;
} = {
  getGuestSessionId(): string {
    return getOrCreateGuestSessionId();
  },

  async getCart(): Promise<Cart> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      return readJSON<Cart>(GUEST_CART_KEY, { lines: [] });
    }

    try {
      const res = await supabase.rpc<any>("get_customer_cart");
      if (res.error || !res.data) {
        return readJSON<Cart>(GUEST_CART_KEY, { lines: [] });
      }
      return mapBackendCart(res.data);
    } catch {
      return readJSON<Cart>(GUEST_CART_KEY, { lines: [] });
    }
  },

  async addVariant(productId: string, variantId: string, quantity = 1): Promise<Cart> {
    const safeQty = Math.max(1, Math.min(10, Math.floor(quantity) || 1));
    const { data: authData } = await supabase.auth.getUser();

    if (!authData.user || !supabase.isConfigured()) {
      // Guest cart handling in local storage
      const current = readJSON<Cart>(GUEST_CART_KEY, { lines: [] });
      const existing = current.lines.find((l) => l.variantId === variantId);
      let lines: CartLine[];
      if (existing) {
        lines = current.lines.map((l) =>
          l.variantId === variantId ? { ...l, quantity: Math.min(10, l.quantity + safeQty) } : l,
        );
      } else {
        lines = [
          ...current.lines,
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
      writeJSON(GUEST_CART_KEY, cart);
      return cart;
    }

    try {
      const res = await supabase.rpc("add_to_customer_cart", {
        p_variant_id: variantId,
        p_quantity: safeQty,
      });
      if (res.error) {
        throw new Error(res.error.message || "Failed to add variant to cart");
      }
      return this.getCart();
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error("Failed to add variant to cart");
    }
  },

  async updateQuantity(lineId: string, quantity: number): Promise<Cart> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      const current = readJSON<Cart>(GUEST_CART_KEY, { lines: [] });
      const lines = current.lines
        .map((l) => (l.id === lineId ? { ...l, quantity: Math.max(0, Math.min(10, quantity)) } : l))
        .filter((l) => l.quantity > 0);
      const cart = { lines };
      writeJSON(GUEST_CART_KEY, cart);
      return cart;
    }

    try {
      const res = await supabase.rpc("update_cart_line_quantity", {
        p_line_id: lineId,
        p_quantity: Math.max(0, Math.min(10, quantity)),
      });
      if (res.error) {
        throw new Error(res.error.message || "Failed to update cart line quantity");
      }
      return this.getCart();
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error("Failed to update cart line quantity");
    }
  },

  async removeLine(lineId: string): Promise<Cart> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      const current = readJSON<Cart>(GUEST_CART_KEY, { lines: [] });
      const lines = current.lines.filter((l) => l.id !== lineId);
      const cart = { lines };
      writeJSON(GUEST_CART_KEY, cart);
      return cart;
    }

    try {
      const res = await supabase.rpc("remove_cart_line", { p_line_id: lineId });
      if (res.error) {
        throw new Error(res.error.message || "Failed to remove cart line");
      }
      return this.getCart();
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error("Failed to remove cart line");
    }
  },

  async clearCart(): Promise<Cart> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      const cart = { lines: [] };
      writeJSON(GUEST_CART_KEY, cart);
      return cart;
    }

    try {
      await supabase.rpc("clear_customer_cart");
      return { lines: [] };
    } catch {
      return { lines: [] };
    }
  },

  async mergeGuestCart(): Promise<boolean> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) return false;

    const guestCart = readJSON<Cart>(GUEST_CART_KEY, { lines: [] });
    if (guestCart.lines.length === 0) return true;

    try {
      // Add each guest line into the customer's authenticated cart
      for (const line of guestCart.lines) {
        await supabase.rpc("add_to_customer_cart", {
          p_variant_id: line.variantId,
          p_quantity: line.quantity,
        });
      }
      // Clear the local guest cart once successfully merged
      writeJSON(GUEST_CART_KEY, { lines: [] });
      return true;
    } catch {
      return false;
    }
  },
};
