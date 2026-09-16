import type {
  AccountRepository,
  CartRepository,
  CheckoutRepository,
  WishlistRepository,
} from "../contracts";
import { mockCatalogRepository, productById, variantsByProduct } from "./catalog";
export { mockCatalogRepository };
import { simulate } from "./latency";
import {
  addToCart,
  clearCart,
  getState,
  removeCartLine,
  saveOrder,
  signIn,
  toggleWishlist,
  updateCartQuantity,
} from "@/state/store";
import type { Address, CheckoutDraft, Order, Profile } from "@/domain/commerce";

export const mockCartRepository: CartRepository = {
  async getCart() {
    return getState().cart;
  },
  async addVariant(productId, variantId, quantity = 1) {
    return addToCart(productId, variantId, quantity);
  },
  async updateQuantity(lineId, quantity) {
    return updateCartQuantity(lineId, quantity);
  },
  async removeLine(lineId) {
    return removeCartLine(lineId);
  },
  async clearCart() {
    return clearCart();
  },
};

export const mockWishlistRepository: WishlistRepository = {
  async list() {
    return getState().wishlist;
  },
  async toggle(productId) {
    return toggleWishlist(productId);
  },
};

export const mockAccountRepository: AccountRepository = {
  async getProfile() {
    return getState().profile;
  },
  async updateProfile(patch: Partial<Profile>) {
    const next = { ...getState().profile, ...patch };
    signIn(next);
    return next;
  },
  listOrders() {
    return simulate("orders", () => getState().orders);
  },
  getOrder(orderNumber) {
    return simulate(`order:${orderNumber}`, () =>
      getState().orders.find((o) => o.orderNumber === orderNumber) ?? null,
    );
  },
};

const PIN = /^\d{6}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE = /^\d{10}$/;

export const mockCheckoutRepository: CheckoutRepository = {
  async validateDraft(draft: CheckoutDraft) {
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
  async createMockOrder(draft: CheckoutDraft, address: Address) {
    const state = getState();
    const source = state.buyNow ? [state.buyNow] : state.cart.lines;
    const items = source.flatMap((line) => {
      const product = productById.get(line.productId);
      const variant = (variantsByProduct.get(line.productId) ?? []).find((v) => v.id === line.variantId);
      if (!product || !variant) return [];
      return [
        {
          productId: product.id,
          variantId: variant.id,
          title: product.title,
          brandName: product.brandName,
          size: variant.size,
          color: variant.color,
          quantity: line.quantity,
          price: variant.price,
        },
      ];
    });
    const subtotal = items.reduce((sum, i) => sum + i.price * i.quantity, 0);
    const shipping = subtotal >= 2999 ? 0 : 99;
    const order: Order = {
      orderNumber: `DEMO-OG-${String(Math.floor(1000 + Math.random() * 9000))}`,
      createdAt: Date.now(),
      status: "placed",
      items,
      subtotal,
      shipping,
      total: subtotal + shipping,
      address,
      paymentMethod: draft.paymentMethod,
      prototype: true,
    };
    saveOrder(order);
    return order;
  },
};

export const mockSellerRepository = {
  async getProfile() {
    return {
      id: "seller-mock-id",
      userId: "user-mock-id",
      businessName: "Mock Designer Studio",
      brandSlug: "mock-brand",
      status: "active",
      commissionRateBps: 1500,
    };
  },
  async listProducts() {
    return [];
  },
  async listSubOrders() {
    return [];
  },
  async listPayouts() {
    return [];
  },
  async shipSubOrder(_subOrderId: string, _awb: string, _courier: string) {
    return true;
  },
  async isEligibleForPayout() {
    return true;
  },
};

export const mockReturnsRepository = {
  async checkEligibility(_subOrderId: string, _orderItemId: string) {
    return { eligible: true, reason: "within_return_window" };
  },
  async createReturnRequest(subOrderId: string, orderItemId: string, reason: string, customerNotes?: string) {
    return {
      id: `ret_${Date.now()}`,
      subOrderId,
      orderItemId,
      reason,
      status: "requested",
      requestedAt: new Date().toISOString(),
      customerNotes,
    };
  },
  async listCustomerReturns() {
    return [];
  },
};

export const mockAdminRepository = {
  async hasRole(_role: string) {
    return true;
  },
  async approveSeller(_sellerId: string) {
    return true;
  },
  async suspendSeller(_sellerId: string) {
    return true;
  },
  async approveProduct(_productId: string) {
    return true;
  },
  async rejectProduct(_productId: string) {
    return true;
  },
  async listModerationQueue() {
    return [];
  },
};

export const repositories = {
  catalog: mockCatalogRepository,
  cart: mockCartRepository,
  wishlist: mockWishlistRepository,
  account: mockAccountRepository,
  checkout: mockCheckoutRepository,
  seller: mockSellerRepository,
  returns: mockReturnsRepository,
  admin: mockAdminRepository,
};
