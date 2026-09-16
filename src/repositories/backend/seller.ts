import { supabase } from "@/lib/supabase";

export interface SellerProfile {
  id: string;
  userId: string;
  businessName: string;
  brandSlug: string;
  status: string;
  commissionRateBps: number;
}

export interface SellerSubOrder {
  id: string;
  subOrderNumber: string;
  orderId: string;
  status: string;
  subtotal: number;
  netPayable: number;
  itemsCount: number;
  createdAt: string;
}

export interface SellerPayoutStatement {
  id: string;
  cycleStart: string;
  cycleEnd: string;
  totalPayable: number;
  status: string;
}

export const backendSellerRepository = {
  async getProfile(): Promise<SellerProfile | null> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) return null;

    try {
      const res = await supabase
        .from<any>("sellers")
        .select("*")
        .eq("user_id", authData.user.id)
        .single();

      if (res.error || !res.data) return null;
      return {
        id: res.data.id,
        userId: res.data.user_id,
        businessName: res.data.business_name,
        brandSlug: res.data.brand_slug,
        status: res.data.status,
        commissionRateBps: res.data.commission_rate_bps || 1500,
      };
    } catch {
      return null;
    }
  },

  async listProducts(): Promise<any[]> {
    const seller = await this.getProfile();
    if (!seller) return [];

    try {
      const res = await supabase
        .from<any>("products")
        .select("*")
        .eq("seller_id", seller.id)
        .order("created_at", { ascending: false })
        .get();

      return res.data || [];
    } catch {
      return [];
    }
  },

  async listSubOrders(): Promise<SellerSubOrder[]> {
    const seller = await this.getProfile();
    if (!seller) return [];

    try {
      const res = await supabase
        .from<any>("seller_sub_orders")
        .select("*")
        .eq("seller_id", seller.id)
        .order("created_at", { ascending: false })
        .get();

      if (res.error || !res.data) return [];
      return res.data.map((so: any) => ({
        id: so.id,
        subOrderNumber: so.sub_order_number,
        orderId: so.order_id,
        status: so.status,
        subtotal: Math.round((so.subtotal_paise || 0) / 100),
        netPayable: Math.round((so.net_seller_payable_paise || 0) / 100),
        itemsCount: 1,
        createdAt: so.created_at,
      }));
    } catch {
      return [];
    }
  },

  async shipSubOrder(subOrderId: string, awb: string, courier: string, pickupDate: string): Promise<boolean> {
    if (!supabase.isConfigured()) return false;

    try {
      const res = await supabase.rpc<boolean>("seller_ship_sub_order", {
        p_sub_order_id: subOrderId,
        p_awb: awb,
        p_courier: courier,
        p_pickup_date: pickupDate,
      });

      return !res.error;
    } catch {
      return false;
    }
  },

  async listPayoutStatements(): Promise<SellerPayoutStatement[]> {
    const seller = await this.getProfile();
    if (!seller) return [];

    try {
      const res = await supabase
        .from<any>("payout_statements")
        .select("*")
        .eq("seller_id", seller.id)
        .order("cycle_start", { ascending: false })
        .get();

      if (res.error || !res.data) return [];
      return res.data.map((ps: any) => ({
        id: ps.id,
        cycleStart: ps.cycle_start,
        cycleEnd: ps.cycle_end,
        totalPayable: Math.round((ps.net_payable_paise || 0) / 100),
        status: ps.status,
      }));
    } catch {
      return [];
    }
  },

  async isPayoutEligible(): Promise<boolean> {
    const seller = await this.getProfile();
    if (!seller) return false;

    try {
      const res = await supabase.rpc<boolean>("is_seller_payout_eligible", {
        p_seller_id: seller.id,
      });
      return Boolean(res.data);
    } catch {
      return false;
    }
  },
};
