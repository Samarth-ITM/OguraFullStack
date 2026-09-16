import { generatedBrands } from "./generated/brands";
import type { Brand } from "@/domain/catalog";

export interface Designer extends Brand {
  isNew: boolean;
}

export const mockDesigners: Designer[] = generatedBrands.map((b, i) => ({
  ...b,
  isNew: b.establishedYear >= 2022 || i % 6 === 0,
}));

export const mockDesignerBySlug = new Map(mockDesigners.map((d) => [d.slug, d]));
