import type { WishlistRepository } from "../contracts";
import { supabase } from "@/lib/supabase";
import { readJSON, writeJSON } from "@/lib/storage";

const GUEST_WISHLIST_KEY = "ogura.guest_wishlist";

export const backendWishlistRepository: WishlistRepository = {
  async list(): Promise<string[]> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      return readJSON<string[]>(GUEST_WISHLIST_KEY, []);
    }

    try {
      const res = await supabase.rpc<any>("get_customer_wishlist");
      if (res.error || !res.data) {
        return readJSON<string[]>(GUEST_WISHLIST_KEY, []);
      }
      const items = Array.isArray(res.data.items) ? res.data.items : [];
      return items.map((i: any) => i.product_id || i.id);
    } catch {
      return readJSON<string[]>(GUEST_WISHLIST_KEY, []);
    }
  },

  async toggle(productId: string): Promise<string[]> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      const current = readJSON<string[]>(GUEST_WISHLIST_KEY, []);
      const updated = current.includes(productId)
        ? current.filter((id) => id !== productId)
        : [productId, ...current];
      writeJSON(GUEST_WISHLIST_KEY, updated);
      return updated;
    }

    try {
      await supabase.rpc("toggle_wishlist_item", {
        p_product_id: productId,
      });
      return this.list();
    } catch {
      return this.list();
    }
  },
};
