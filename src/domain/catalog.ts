export type Availability = "in_stock" | "low_stock" | "sold_out" | "made_to_order";

export type PricePosition = "ACCESSIBLE" | "CONTEMPORARY" | "PREMIUM" | "PRESTIGE";

export interface Product {
  id: string;
  slug: string;
  status: string;
  brandId: string;
  brandSlug: string;
  brandName: string;
  designerId: string;
  title: string;
  shortDescription: string;
  longDescription: string;
  department: string;
  category: string;
  subcategory: string;
  productType: string;
  occasion: string;
  aesthetic: string;
  colorFamily: string;
  material: string;
  silhouette: string;
  fit: string;
  price: number;
  compareAtPrice: number | null;
  currency: "INR";
  priceBand: string;
  pricePosition: PricePosition;
  rating: number;
  reviewCount: number;
  madeToOrder: boolean;
  customizable: boolean;
  launchpad: boolean;
  newArrival: boolean;
  limited: boolean;
  requiresSize: boolean;
  variantIds: string[];
  tags: string[];
  createdAt: number;
  popularity: number;
}

export interface Variant {
  id: string;
  sku: string;
  productId: string;
  size: string;
  color: string;
  colorHex: string;
  availability: Availability;
  inventory: number;
  price: number;
  leadTime: string;
}

export interface Brand {
  id: string;
  slug: string;
  name: string;
  sellerId: string;
  productCount: number;
  location: string;
  entityType: "designer" | "instagram" | "boutique";
  launchpad: boolean;
  statement: string;
  pointOfView: string;
  trending: boolean;
  establishedYear: number;
}

export interface Category {
  slug: string;
  name: string;
  children: { slug: string; name: string }[];
}

export interface Collection {
  slug: string;
  title: string;
  description: string;
  kind: "price" | "style" | "editorial";
  minPrice?: number;
  maxPrice?: number;
  subcategories?: string[];
  productTypes?: string[];
}

export type MediaRole =
  | "hero"
  | "banner"
  | "editorial"
  | "campaign"
  | "product"
  | "brand"
  | "designer"
  | "review"
  | "video";

export interface MediaSlot {
  slotId: string;
  role: MediaRole;
  ratio: string;
  desktop: string;
  mobile: string;
  alt: string;
  entityId?: string;
}

export interface ProductQuery {
  category?: string;
  subcategory?: string;
  productTypes?: string[];
  brandSlugs?: string[];
  sizes?: string[];
  colors?: string[];
  occasions?: string[];
  aesthetics?: string[];
  fits?: string[];
  materials?: string[];
  priceBands?: string[];
  minPrice?: number;
  maxPrice?: number;
  minDiscount?: number;
  availability?: string[];
  madeToOrder?: boolean;
  launchpad?: boolean;
  newArrival?: boolean;
  collection?: string;
  q?: string;
  sort?: SortKey;
  offset?: number;
  limit?: number;
}

export type SortKey =
  | "recommended"
  | "newest"
  | "price-asc"
  | "price-desc"
  | "discount"
  | "rating"
  | "loved";

export interface ProductListResult {
  items: Product[];
  total: number;
  facets: Facets;
}

export interface Facets {
  subcategories: { value: string; count: number }[];
  brands: { value: string; label: string; count: number }[];
  sizes: { value: string; count: number }[];
  colors: { value: string; hex: string; count: number }[];
  occasions: { value: string; count: number }[];
  aesthetics: { value: string; count: number }[];
  fits: { value: string; count: number }[];
  materials: { value: string; count: number }[];
  priceBands: { value: string; count: number }[];
}
