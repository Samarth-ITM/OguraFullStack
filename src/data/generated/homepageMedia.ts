import heroDesktop from "@/assets/home/hero-desktop.jpg";
import heroMobile from "@/assets/home/hero-mobile.jpg";
import tileMadeToOrder from "@/assets/home/tile-made-to-order.jpg";
import tilePinterestFinds from "@/assets/home/tile-pinterest-finds.jpg";
import tileCelebrityFashion from "@/assets/home/tile-celebrity-fashion.jpg";
import tileFestiveEdit from "@/assets/home/tile-festive-edit.jpg";
import tileDesignerCurations from "@/assets/home/tile-designer-curations.jpg";
import tileInstagramBoutiques from "@/assets/home/tile-instagram-boutiques.jpg";
import campaignFestive from "@/assets/home/campaign-festive.jpg";
import editorialLook from "@/assets/home/editorial-look.jpg";

/** Editorial imagery bundled with the app, keyed by media slot id. */
export const HOMEPAGE_MEDIA: Record<string, string> = {
  "home.hero": heroDesktop,
  "home.hero.mobile": heroMobile,
  "home.explore.made-to-order": tileMadeToOrder,
  "home.explore.pinterest-finds": tilePinterestFinds,
  "home.explore.celebrity-fashion": tileCelebrityFashion,
  "home.explore.festive-edit": tileFestiveEdit,
  "home.explore.designer-curations": tileDesignerCurations,
  "home.explore.instagram-boutiques": tileInstagramBoutiques,
  "home.campaign.festive": campaignFestive,
  "home.editorial.look": editorialLook,
};

export function getSlotImage(slotId: string): string | undefined {
  return HOMEPAGE_MEDIA[slotId];
}
