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
}

export interface WishlistRepository {
  list(): Promise<string[]>;
  toggle(productId: string): Promise<string[]>;
}

export interface AccountRepository {
  getProfile(): Promise<Profile>;
  updateProfile(profile: Partial<Profile>): Promise<Profile>;
  listOrders(): Promise<Order[]>;
  getOrder(orderNumber: string): Promise<Order | null>;
}

export interface CheckoutRepository {
  validateDraft(draft: CheckoutDraft): Promise<Record<string, string>>;
  createMockOrder(draft: CheckoutDraft, address: Address): Promise<Order>;
}
