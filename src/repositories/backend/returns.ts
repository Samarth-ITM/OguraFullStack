import { supabase } from "@/lib/supabase";

export interface ReturnEligibilityResult {
  eligible: boolean;
  reason?: string;
  maxRefund?: number;
  deliveredAt?: string;
}

export interface CustomerReturnRequest {
  id: string;
  orderNumber: string;
  itemTitle: string;
  status: string;
  refundAmount: number;
  requestedAt: string;
}

export const backendReturnsRepository = {
  async checkEligibility(subOrderId: string, itemId: string): Promise<ReturnEligibilityResult> {
    if (!supabase.isConfigured()) {
      return { eligible: false, reason: "Backend connection required." };
    }

    try {
      const res = await supabase.rpc<any>("check_return_eligibility", {
        p_sub_order_id: subOrderId,
        p_item_id: itemId,
      });

      if (res.error || !res.data) {
        return { eligible: false, reason: res.error?.message || "Ineligible for return." };
      }

      const result: ReturnEligibilityResult = {
        eligible: Boolean(res.data.eligible),
      };
      if (res.data.reason) result.reason = String(res.data.reason);
      if (res.data.max_refund_paise) result.maxRefund = Math.round(res.data.max_refund_paise / 100);
      if (res.data.delivered_at) result.deliveredAt = String(res.data.delivered_at);
      return result;
    } catch {
      return { eligible: false, reason: "Failed to evaluate return eligibility." };
    }
  },

  async createReturnRequest(
    subOrderId: string,
    itemId: string,
    reason: string,
    comments?: string,
  ): Promise<{ success: boolean; requestId?: string; error?: string }> {
    if (!supabase.isConfigured()) {
      return { success: false, error: "Backend connection required." };
    }

    try {
      const res = await supabase.rpc<string>("customer_create_return_request", {
        p_sub_order_id: subOrderId,
        p_item_id: itemId,
        p_return_reason: reason,
        p_comments: comments || null,
      });

      if (res.error || !res.data) {
        return { success: false, error: res.error?.message || "Failed to create return request." };
      }

      return { success: true, requestId: res.data };
    } catch {
      return { success: false, error: "Network failure while creating return request." };
    }
  },

  async listCustomerReturns(): Promise<CustomerReturnRequest[]> {
    if (!supabase.isConfigured()) return [];

    try {
      const res = await supabase.rpc<any>("get_customer_return_requests");
      if (res.error || !res.data) return [];

      const list = Array.isArray(res.data) ? res.data : [];
      return list.map((r: any) => ({
        id: r.id,
        orderNumber: r.order_number,
        itemTitle: r.product_title || "Design item",
        status: r.status,
        refundAmount: Math.round((r.refund_amount_paise || 0) / 100),
        requestedAt: r.created_at,
      }));
    } catch {
      return [];
    }
  },
};
