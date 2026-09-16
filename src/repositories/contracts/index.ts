import type {
  Brand,
  Collection,
  Product,
  ProductListResult,
  ProductQuery,
  Variant,
} from "@/domain/catalog";
import type { Address, Cart, CheckoutDraft, Order, Profile } from "@/domain/commerce";

export interface CatalogRepository {
  listProducts(query: ProductQuery): Promise<ProductListResult>;
  getProduct(slug: string): Promise<{ product: Product; variants: Variant[] } | null>;
  searchProducts(q: string, limit?: number): Promise<Product[]>;
  listBrands(): Promise<Brand[]>;
  getBrand(slug: string): Promise<Brand | null>;
  listCollections(): Promise<Collection[]>;
  getCollection(slug: string): Promise<Collection | null>;
}

export interface CartRepository {
  getCart(): Promise<Cart>;
  addVariant(productId: string, variantId: string, quantity?: number): Promise<Cart>;
  updateQuantity(lineId: string, quantity: number): Promise<Cart>;
  removeLine(lineId: string): Promise<Cart>;
  clearCart(): Promise<Cart>;
  mergeGuestCart?(): Promise<boolean>;
}

export interface WishlistRepository {
  list(): Promise<string[]>;
  toggle(productId: string): Promise<string[]>;
}

export interface CustomerAddressItem extends Address {
  id?: string;
  isDefault?: boolean;
}

export interface AccountRepository {
  getProfile(): Promise<Profile>;
  updateProfile(profile: Partial<Profile>): Promise<Profile>;
  listOrders(): Promise<Order[]>;
  getOrder(orderNumber: string): Promise<Order | null>;
  listAddresses?(): Promise<CustomerAddressItem[]>;
  saveAddress?(addr: Address, isDefault?: boolean): Promise<CustomerAddressItem | null>;
  setDefaultAddress?(addressId: string): Promise<boolean>;
  deleteAddress?(addressId: string): Promise<boolean>;
}

export interface AuthoritativeQuote {
  quoteId: string;
  subtotal: number;
  discount: number;
  shipping: number;
  tax: number;
  total: number;
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

export interface AuthoritativeOrder {
  orderId: string;
  orderNumber: string;
  total: number;
  status: string;
  paymentId?: string;
  gatewayOrderId?: string;
}

export interface CheckoutRepository {
  validateDraft(draft: CheckoutDraft): Promise<Record<string, string>>;
  createMockOrder(draft: CheckoutDraft, address: Address): Promise<Order>;
  createAuthoritativeQuote?(addressId?: string, customAddress?: Record<string, unknown>): Promise<AuthoritativeQuote>;
  getAuthoritativeQuote?(quoteId: string): Promise<AuthoritativeQuote | null>;
  cancelAuthoritativeQuote?(quoteId: string): Promise<boolean>;
  createOrderFromQuote?(quoteId: string): Promise<AuthoritativeOrder>;
}
