import type {
  Brand,
  Collection,
  Product,
  ProductListResult,
  ProductQuery,
  Variant,
} from "@/domain/catalog";
import type { CatalogRepository } from "../contracts";
import { supabase } from "@/lib/supabase";
import { ALL_COLLECTIONS } from "@/data/taxonomy";

interface BackendCatalogItem {
  id: string;
  title: string;
  slug: string;
  description: string;
  materials?: string;
  care_instructions?: string;
  is_made_to_order: boolean;
  is_new_arrival: boolean;
  is_launchpad: boolean;
  category_name: string;
  category_slug: string;
  subcategory_name: string;
  subcategory_slug: string;
  brand_name: string;
  brand_slug: string;
  brand_logo_url?: string;
  designer_name?: string;
  designer_slug?: string;
  occasion_name?: string;
  occasion_slug?: string;
  primary_image_url?: string;
  primary_image_alt?: string;
  min_price_paise: number;
  max_price_paise: number;
}

interface BackendCatalogResult {
  total: number;
  limit: number;
  offset: number;
  items: BackendCatalogItem[];
}

function mapBackendProduct(item: BackendCatalogItem): Product {
  const price = Math.round(item.min_price_paise / 100);
  return {
    id: item.id,
    slug: item.slug,
    status: "published",
    brandId: item.brand_slug,
    brandSlug: item.brand_slug,
    brandName: item.brand_name,
    designerId: item.designer_slug || item.brand_slug,
    title: item.title,
    shortDescription: item.description || "",
    longDescription: item.materials ? `${item.description}\n\nMaterials: ${item.materials}` : item.description || "",
    department: "Women",
    category: item.category_name,
    subcategory: item.subcategory_name,
    productType: item.subcategory_name,
    occasion: item.occasion_name || "Evening",
    aesthetic: "Modern Luxe",
    colorFamily: "Neutral",
    material: item.materials || "Silk Blend",
    silhouette: "Tailored",
    fit: "True to size",
    price,
    compareAtPrice: null,
    currency: "INR",
    priceBand: price >= 50000 ? "50k+" : price >= 25000 ? "25k-50k" : "Under 25k",
    pricePosition: price >= 50000 ? "PRESTIGE" : price >= 25000 ? "PREMIUM" : "CONTEMPORARY",
    rating: 4.8,
    reviewCount: 12,
    madeToOrder: Boolean(item.is_made_to_order),
    customizable: false,
    launchpad: Boolean(item.is_launchpad),
    newArrival: Boolean(item.is_new_arrival),
    limited: false,
    requiresSize: true,
    variantIds: [],
    tags: [item.category_slug, item.subcategory_slug, item.brand_slug].filter(Boolean),
    createdAt: Date.now(),
    popularity: 90,
  };
}

export const backendCatalogRepository: CatalogRepository = {
  async listProducts(query: ProductQuery): Promise<ProductListResult> {
    if (!supabase.isConfigured()) {
      throw new Error("Backend configuration missing. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.");
    }

    try {
      const res = await supabase.rpc<BackendCatalogResult>("get_public_catalog", {
        p_category_slug: query.category || null,
        p_subcategory_slug: query.subcategory || null,
        p_brand_slugs: query.brandSlugs && query.brandSlugs.length ? query.brandSlugs : null,
        p_occasion_slugs: query.occasions && query.occasions.length ? query.occasions : null,
        p_min_price_paise: query.minPrice ? query.minPrice * 100 : null,
        p_max_price_paise: query.maxPrice ? query.maxPrice * 100 : null,
        p_is_mto: typeof query.madeToOrder === "boolean" ? query.madeToOrder : null,
        p_is_new_arrival: typeof query.newArrival === "boolean" ? query.newArrival : null,
        p_is_launchpad: typeof query.launchpad === "boolean" ? query.launchpad : null,
        p_sort: query.sort || "recommended",
        p_limit: query.limit || 40,
        p_offset: query.offset || 0,
      });

      if (res.error) {
        throw new Error(res.error.message || "Failed to load catalog from backend");
      }

      const items = (res.data?.items || []).map(mapBackendProduct);
      return {
        items,
        total: res.data?.total || items.length,
        facets: {
          subcategories: [],
          brands: [],
          sizes: [],
          colors: [],
          occasions: [],
          aesthetics: [],
          fits: [],
          materials: [],
          priceBands: [],
        },
      };
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error("Failed to load catalog from backend");
    }
  },

  async getProduct(slug: string): Promise<{ product: Product; variants: Variant[] } | null> {
    if (!supabase.isConfigured()) {
      throw new Error("Backend configuration missing. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.");
    }

    try {
      const res = await supabase.rpc<any>("get_public_product_by_slug", {
        p_slug: slug,
      });

      if (res.error) {
        throw new Error(res.error.message || `Failed to fetch product '${slug}' from backend`);
      }

      if (!res.data) {
        return null;
      }

      const raw = res.data;
      const product = mapBackendProduct(raw);
      const variants: Variant[] = (raw.variants || []).map((v: any) => ({
        id: v.id,
        sku: v.sku,
        productId: product.id,
        size: v.size,
        color: v.color,
        colorHex: v.color_hex || "#1A1A1A",
        availability: v.stock_quantity > 0 ? (v.stock_quantity <= 2 ? "low_stock" : "in_stock") : "sold_out",
        inventory: v.stock_quantity || 0,
        price: Math.round(v.price_paise / 100),
        leadTime: product.madeToOrder ? "14-21 days" : "Ready to ship",
      }));

      product.variantIds = variants.map((v) => v.id);
      return { product, variants };
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error(`Failed to fetch product '${slug}' from backend`);
    }
  },

  async searchProducts(q: string, limit = 8): Promise<Product[]> {
    if (!supabase.isConfigured()) {
      throw new Error("Backend configuration missing. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.");
    }
    const clean = q.trim();
    if (!clean) return [];

    try {
      const res = await supabase
        .from<BackendCatalogItem>("public_catalog_products")
        .select("*")
        .limit(limit)
        .get();

      if (res.error) {
        throw new Error(res.error.message || "Failed to search products from backend");
      }
      return (res.data || []).map(mapBackendProduct);
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error("Failed to search products from backend");
    }
  },

  async listBrands(): Promise<Brand[]> {
    if (!supabase.isConfigured()) {
      throw new Error("Backend configuration missing. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.");
    }
    try {
      const res = await supabase.from<any>("brands").select("*").eq("is_active", true).get();
      if (res.error) {
        throw new Error(res.error.message || "Failed to list brands from backend");
      }
      return (res.data || []).map((b: any) => ({
        id: b.id,
        slug: b.slug,
        name: b.name,
        sellerId: b.seller_id,
        productCount: 10,
        location: "Mumbai",
        entityType: "designer",
        launchpad: false,
        statement: b.description || "",
        pointOfView: b.description || "",
        trending: true,
        establishedYear: 2020,
      }));
    } catch (err) {
      if (err instanceof Error) throw err;
      throw new Error("Failed to list brands from backend");
    }
  },

  async getBrand(slug: string): Promise<Brand | null> {
    const brands = await this.listBrands();
    return brands.find((b) => b.slug === slug) ?? null;
  },

  async listCollections(): Promise<Collection[]> {
    return ALL_COLLECTIONS;
  },

  async getCollection(slug: string): Promise<Collection | null> {
    return ALL_COLLECTIONS.find((c) => c.slug === slug) ?? null;
  },
};
