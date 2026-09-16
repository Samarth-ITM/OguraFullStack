import type { Address, CheckoutDraft, Order } from "@/domain/commerce";
import type { CheckoutRepository } from "../contracts";
import { supabase } from "@/lib/supabase";

export interface AuthoritativeQuoteResult {
  quoteId: string;
  subtotal: number; // in INR
  discount: number; // in INR
  shipping: number; // in INR
  tax: number;      // in INR
  total: number;    // in INR
  expiresAt: string;
  status: string;
  items: Array<{
    variantId: string;
    quantity: number;
    title: string;
    unitPrice: number;
    totalPrice: number;
  }>;
}

export interface AuthoritativeOrderResult {
  orderId: string;
  orderNumber: string;
  total: number;
  status: string;
  paymentId?: string;
  gatewayOrderId?: string;
}

const PIN = /^\d{6}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE = /^\d{10}$/;

export const backendCheckoutRepository: CheckoutRepository & {
  createAuthoritativeQuote: (addressId?: string, customAddress?: Record<string, unknown>) => Promise<AuthoritativeQuoteResult>;
  getAuthoritativeQuote: (quoteId: string) => Promise<AuthoritativeQuoteResult | null>;
  cancelAuthoritativeQuote: (quoteId: string) => Promise<boolean>;
  createOrderFromQuote: (quoteId: string) => Promise<AuthoritativeOrderResult>;
} = {
  async validateDraft(draft: CheckoutDraft): Promise<Record<string, string>> {
    const errors: Record<string, string> = {};
    if (!EMAIL.test(draft.email)) errors["email"] = "Enter a valid email address.";
    if (!PHONE.test(draft.phone.replace(/\D/g, ""))) errors["phone"] = "Enter a 10-digit mobile number.";
    if (!draft.address.fullName.trim()) errors["fullName"] = "Enter the recipient's full name.";
    if (!draft.address.line1.trim()) errors["line1"] = "Enter the street address.";
    if (!draft.address.city.trim()) errors["city"] = "Enter the city.";
    if (!draft.address.state.trim()) errors["state"] = "Enter the state.";
    if (!PIN.test(draft.address.pincode)) errors["pincode"] = "Enter a 6-digit pincode.";
    return errors;
  },

  async createMockOrder(_draft: CheckoutDraft, _address: Address): Promise<Order> {
    throw new Error(
      "[OGURA BACKEND INVARIANT] createMockOrder is not supported in backend mode. " +
      "Orders must be authoritatively created via createAuthoritativeQuote and createOrderFromQuote."
    );
  },

  async createAuthoritativeQuote(
    addressId?: string,
    customAddress?: Record<string, unknown>,
  ): Promise<AuthoritativeQuoteResult> {
    if (!supabase.isConfigured()) {
      throw new Error("Backend connection required for authoritative quote.");
    }

    const payload: Record<string, unknown> = {};
    if (addressId) payload["p_address_id"] = addressId;
    if (customAddress) payload["p_custom_address"] = customAddress;

    const res = await supabase.rpc<any>("create_checkout_quote", payload);

    if (res.error || !res.data) {
      throw new Error(res.error?.message || "Failed to create authoritative checkout quote.");
    }

    const q = res.data;
    const items = Array.isArray(q.items)
      ? q.items.map((i: any) => ({
          variantId: i.variant_id,
          quantity: i.quantity,
          title: i.title || "Design Piece",
          unitPrice: Math.round(i.price_paise / 100),
          totalPrice: Math.round((i.price_paise * i.quantity) / 100),
        }))
      : [];

    return {
      quoteId: q.quote_id,
      subtotal: Math.round(q.subtotal_paise / 100),
      discount: Math.round((q.discount_paise || 0) / 100),
      shipping: Math.round((q.shipping_fee_paise || 0) / 100),
      tax: Math.round((q.tax_paise || 0) / 100),
      total: Math.round(q.total_payable_paise / 100),
      expiresAt: q.expires_at,
      status: q.status,
      items,
    };
  },

  async getAuthoritativeQuote(quoteId: string): Promise<AuthoritativeQuoteResult | null> {
    if (!supabase.isConfigured()) return null;

    try {
      const res = await supabase.rpc<any>("get_checkout_quote", {
        p_quote_id: quoteId,
      });

      if (res.error || !res.data) return null;
      const q = res.data;
      const items = Array.isArray(q.items)
        ? q.items.map((i: any) => ({
            variantId: i.variant_id,
            quantity: i.quantity,
            title: i.title || "Design Piece",
            unitPrice: Math.round(i.price_paise / 100),
            totalPrice: Math.round((i.price_paise * i.quantity) / 100),
          }))
        : [];

      return {
        quoteId: q.quote_id,
        subtotal: Math.round(q.subtotal_paise / 100),
        discount: Math.round((q.discount_paise || 0) / 100),
        shipping: Math.round((q.shipping_fee_paise || 0) / 100),
        tax: Math.round((q.tax_paise || 0) / 100),
        total: Math.round(q.total_payable_paise / 100),
        expiresAt: q.expires_at,
        status: q.status,
        items,
      };
    } catch {
      return null;
    }
  },

  async cancelAuthoritativeQuote(quoteId: string): Promise<boolean> {
    if (!supabase.isConfigured()) return false;
    try {
      const res = await supabase.rpc<boolean>("cancel_checkout_quote", {
        p_quote_id: quoteId,
      });
      return !res.error;
    } catch {
      return false;
    }
  },

  async createOrderFromQuote(quoteId: string): Promise<AuthoritativeOrderResult> {
    if (!supabase.isConfigured()) {
      throw new Error("Backend connection required for authoritative order creation.");
    }

    const res = await supabase.rpc<any>("create_order_from_quote", {
      p_quote_id: quoteId,
    });

    if (res.error || !res.data) {
      throw new Error(res.error?.message || "Failed to create order from quote.");
    }

    const o = res.data;
    return {
      orderId: o.order_id,
      orderNumber: o.order_number,
      total: Math.round((o.total_amount_paise || 0) / 100),
      status: o.status,
      paymentId: o.payment_id,
      gatewayOrderId: o.gateway_order_id,
    };
  },
};
