// TEMPORARY_DRIVE_MEDIA — migrate approved originals to owned storage before production.
import raw from "./productMedia.json";

export type ImageRole = "PRIMARY" | "SECONDARY" | "BACK" | "DETAIL" | "UNKNOWN";

export interface ProductImageRecord {
  sourceProductId: string;
  productId: string;
  productSlug: string;
  imageId: string;
  imageRole: ImageRole;
  imageOrder: number;
  isPrimary: boolean;
  sourceFilename: string;
  /** TEMPORARY_DRIVE_MEDIA — migrate approved originals to owned storage before production. */
  url: string;
  qualityGate: string;
}

export interface ProductMediaRecord {
  sourceProductId: string;
  productId: string;
  productSlug: string;
  images: ProductImageRecord[];
}

export interface ProductMediaManifest {
  generatedFrom: string;
  totalProducts: number;
  totalImages: number;
  records: Record<string, ProductMediaRecord>;
}

export const productMediaManifest = raw as unknown as ProductMediaManifest;
