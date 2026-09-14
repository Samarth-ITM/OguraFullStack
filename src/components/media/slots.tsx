import { Placeholder } from "./Placeholder";
import { RATIOS, type RatioKey } from "@/data/mediaSlots";

interface SlotProps {
  slotId: string;
  alt: string;
  label?: string;
  className?: string;
  entityId?: string;
  tone?: "wine" | "charcoal" | "deep";
  showMeta?: boolean;
}

function make(role: string, ratioKey: RatioKey) {
  return function SlotComponent(props: SlotProps) {
    const r = RATIOS[ratioKey];
    return (
      <Placeholder
        {...props}
        role={role}
        ratio={r.ratio}
        desktop={r.desktop}
        mobile={r.mobile}
      />
    );
  };
}

export const HeroMediaPlaceholder = make("hero", "hero");
export const HeroMobileMediaPlaceholder = make("hero", "heroMobile");
export const EditorialBannerPlaceholder = make("banner", "banner");
export const ShallowBannerPlaceholder = make("banner", "bannerShallow");
export const CampaignMediaPlaceholder = make("campaign", "editorial");
export const ProductImagePlaceholder = make("product", "product");
export const BrandLogoPlaceholder = make("brand", "review");
export const DesignerPortraitPlaceholder = make("designer", "portrait");
export const ReviewMediaPlaceholder = make("review", "review");
export const VideoPosterPlaceholder = make("video", "hero");
export const CategoryTilePlaceholder = make("editorial", "tile");
