import type { Address, CheckoutDraft, Order, OrderItem, Profile } from "@/domain/commerce";
import type { AccountRepository } from "../contracts";
import { supabase } from "@/lib/supabase";

export interface CustomerAddressRecord extends Address {
  id?: string;
  isDefault?: boolean;
}

const GUEST_PROFILE: Profile = {
  name: "",
  email: "",
  phone: "",
  signedIn: false,
};

function mapBackendOrder(o: any): Order {
  const addr = o.shipping_address || {};
  const items: OrderItem[] = Array.isArray(o.items)
    ? o.items.map((i: any) => ({
        productId: i.product_id || "",
        variantId: i.variant_sku || i.sku || "",
        title: i.product_title || i.title || "Ogura Design",
        brandName: i.brand_name || "Designer",
        size: i.size || "Free",
        color: i.color || "Standard",
        quantity: i.quantity || 1,
        price: Math.round((i.unit_price_paise || i.price_paise || 0) / 100),
      }))
    : [];

  return {
    orderNumber: o.order_number || o.id,
    createdAt: o.created_at ? new Date(o.created_at).getTime() : Date.now(),
    status: o.status || "placed",
    items,
    subtotal: Math.round((o.subtotal_paise || 0) / 100),
    shipping: Math.round((o.shipping_fee_paise || 0) / 100),
    total: Math.round((o.total_payable_paise || 0) / 100),
    address: {
      fullName: addr.full_name || "",
      phone: addr.phone || "",
      line1: addr.line1 || "",
      line2: addr.line2 || "",
      city: addr.city || "",
      state: addr.state || "",
      pincode: addr.pincode || "",
    },
    paymentMethod: o.payment_method || "Online",
    prototype: true,
  };
}

export const backendAccountRepository: AccountRepository = {
  async getProfile(): Promise<Profile> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user) {
      return GUEST_PROFILE;
    }

    try {
      const res = await supabase
        .from<any>("profiles")
        .select("*")
        .eq("id", authData.user.id)
        .single();

      if (res.data) {
        return {
          name: res.data.name || authData.user.user_metadata?.["full_name"] || "Ogura Customer",
          email: res.data.email || authData.user.email || "",
          phone: res.data.phone || authData.user.phone || "",
          signedIn: true,
        };
      }

      return {
        name: (authData.user.user_metadata?.["full_name"] as string) || "Ogura Customer",
        email: authData.user.email || "",
        phone: authData.user.phone || "",
        signedIn: true,
      };
    } catch {
      return GUEST_PROFILE;
    }
  },

  async updateProfile(patch: Partial<Profile>): Promise<Profile> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      throw new Error("Authentication and backend configuration required to update profile");
    }

    try {
      const payload: Record<string, unknown> = {};
      if (patch.name !== undefined) payload["name"] = patch.name;
      if (patch.email !== undefined) payload["email"] = patch.email;
      if (patch.phone !== undefined) payload["phone"] = patch.phone;

      const res = await supabase
        .from("profiles")
        .eq("id", authData.user.id)
        .update(payload);

      if (res.error) {
        throw new Error(res.error.message || "Failed to update profile");
      }

      return this.getProfile();
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error("Failed to update profile");
    }
  },

  async listOrders(): Promise<Order[]> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      return [];
    }

    try {
      const res = await supabase
        .from<any>("orders")
        .select("*")
        .order("created_at", { ascending: false })
        .get();

      if (res.error) {
        throw new Error(res.error.message || "Failed to list orders");
      }

      if (!res.data) return [];

      // Map each order with its item snapshots
      const orders = await Promise.all(
        res.data.map(async (o: any) => {
          const detailRes = await supabase.rpc<any>("get_order_details", {
            p_order_id: o.id,
          });
          if (detailRes.data) {
            const allItems = (detailRes.data.sub_orders || []).flatMap((so: any) => so.items || []);
            return mapBackendOrder({ ...o, items: allItems });
          }
          return mapBackendOrder(o);
        }),
      );

      return orders;
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error("Failed to list orders");
    }
  },

  async getOrder(orderNumber: string): Promise<Order | null> {
    if (!supabase.isConfigured()) {
      throw new Error("Backend configuration missing. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.");
    }

    try {
      // Find order by order_number
      const res = await supabase
        .from<any>("orders")
        .select("*")
        .eq("order_number", orderNumber)
        .single();

      if (res.data) {
        const detailRes = await supabase.rpc<any>("get_order_details", {
          p_order_id: res.data.id,
        });
        if (detailRes.data) {
          const allItems = (detailRes.data.sub_orders || []).flatMap((so: any) => so.items || []);
          return mapBackendOrder({ ...res.data, items: allItems });
        }
        return mapBackendOrder(res.data);
      }
      return null;
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error(`Failed to fetch order ${orderNumber}`);
    }
  },

  async listAddresses(): Promise<CustomerAddressRecord[]> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      return [];
    }

    try {
      const res = await supabase
        .from<any>("customer_addresses")
        .select("*")
        .eq("is_active", true)
        .order("is_default", { ascending: false })
        .order("created_at", { ascending: false })
        .get();

      if (res.error || !res.data) return [];
      return res.data.map((a: any) => ({
        id: a.id,
        fullName: a.full_name,
        phone: a.phone,
        line1: a.line1,
        line2: a.line2 || "",
        city: a.city,
        state: a.state,
        pincode: a.pincode,
        isDefault: Boolean(a.is_default),
      }));
    } catch {
      return [];
    }
  },

  async saveAddress(addr: Address, isDefault = false): Promise<CustomerAddressRecord | null> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) {
      return null;
    }

    try {
      const res = await supabase.from<any>("customer_addresses").insert({
        user_id: authData.user.id,
        full_name: addr.fullName,
        phone: addr.phone,
        line1: addr.line1,
        line2: addr.line2 || null,
        city: addr.city,
        state: addr.state,
        pincode: addr.pincode,
        country: "India",
        is_default: isDefault,
        is_active: true,
      });

      if (res.error || !res.data) return null;
      return {
        id: res.data.id,
        fullName: res.data.full_name,
        phone: res.data.phone,
        line1: res.data.line1,
        line2: res.data.line2 || "",
        city: res.data.city,
        state: res.data.state,
        pincode: res.data.pincode,
        isDefault: Boolean(res.data.is_default),
      };
    } catch {
      return null;
    }
  },

  async setDefaultAddress(addressId: string): Promise<boolean> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) return false;

    try {
      const res = await supabase.rpc<boolean>("set_default_customer_address", {
        p_address_id: addressId,
      });
      return !res.error;
    } catch {
      return false;
    }
  },

  async deleteAddress(addressId: string): Promise<boolean> {
    const { data: authData } = await supabase.auth.getUser();
    if (!authData.user || !supabase.isConfigured()) return false;

    try {
      // Soft-delete: update is_active = false
      const res = await supabase
        .from("customer_addresses")
        .eq("id", addressId)
        .update({ is_active: false });
      return !res.error;
    } catch {
      return false;
    }
  },
};
