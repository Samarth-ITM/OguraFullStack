import { supabase } from "@/lib/supabase";

export const backendAdminRepository = {
  async hasRole(role: string): Promise<boolean> {
    if (!supabase.isConfigured()) return false;
    try {
      const res = await supabase.rpc<boolean>("has_role", {
        required_role: role,
      });
      return Boolean(res.data);
    } catch {
      return false;
    }
  },

  async listSellers(): Promise<any[]> {
    if (!supabase.isConfigured()) return [];
    try {
      const res = await supabase.from<any>("sellers").select("*").order("created_at", { ascending: false }).get();
      return res.data || [];
    } catch {
      return [];
    }
  },

  async approveSeller(sellerId: string): Promise<boolean> {
    if (!supabase.isConfigured()) return false;
    try {
      const res = await supabase.rpc<boolean>("approve_seller", {
        p_seller_id: sellerId,
      });
      return !res.error;
    } catch {
      return false;
    }
  },

  async suspendSeller(sellerId: string, reason: string): Promise<boolean> {
    if (!supabase.isConfigured()) return false;
    try {
      const res = await supabase.rpc<boolean>("suspend_seller", {
        p_seller_id: sellerId,
        p_reason: reason,
      });
      return !res.error;
    } catch {
      return false;
    }
  },

  async approveProduct(productId: string): Promise<boolean> {
    if (!supabase.isConfigured()) return false;
    try {
      const res = await supabase.rpc<boolean>("approve_product", {
        p_product_id: productId,
      });
      return !res.error;
    } catch {
      return false;
    }
  },

  async rejectProduct(productId: string, reason: string): Promise<boolean> {
    if (!supabase.isConfigured()) return false;
    try {
      const res = await supabase.rpc<boolean>("reject_product", {
        p_product_id: productId,
        p_reason: reason,
      });
      return !res.error;
    } catch {
      return false;
    }
  },

  async listAllOrders(): Promise<any[]> {
    if (!supabase.isConfigured()) return [];
    try {
      const res = await supabase.from<any>("orders").select("*").order("created_at", { ascending: false }).get();
      return res.data || [];
    } catch {
      return [];
    }
  },
};
