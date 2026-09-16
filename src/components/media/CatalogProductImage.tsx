// TEMPORARY_DRIVE_MEDIA — migrate approved originals to owned storage before production.
import { useEffect, useState } from "react";
import { ProductImagePlaceholder } from "@/components/media/slots";
import { getPrimaryImage, markImageFailed, renderableUrl } from "@/repositories/mock/productMediaRepository";
import { cn } from "@/lib/utils";

export interface CatalogProductImageProps {
  src: string;
  alt: string;
  aspectRatio?: string;
  loading?: "lazy" | "eager";
  priority?: boolean;
  fallbackSlotId: string;
  fallbackLabel?: string;
  imageRole?: string;
  className?: string;
  showMeta?: boolean;
  onLoad?: () => void;
  onError?: () => void;
}

export function CatalogProductImage({
  src,
  alt,
  aspectRatio = "3 / 4",
  loading,
  priority = false,
  fallbackSlotId,
  fallbackLabel,
  imageRole,
  className,
  showMeta = false,
  onLoad,
  onError,
}: CatalogProductImageProps) {
  const [loaded, setLoaded] = useState(false);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setLoaded(false);
    setFailed(false);
  }, [src]);

  if (failed || !src) {
    return (
      <ProductImagePlaceholder
        slotId={fallbackSlotId}
        alt={alt}
        label={fallbackLabel ?? imageRole ?? "IMAGE"}
        showMeta={showMeta}
        {...(className ? { className } : {})}
      />
    );
  }

  return (
    <div
      className={cn("relative w-full overflow-hidden border border-border bg-surface", className)}
      style={{ aspectRatio }}
    >
      {!loaded ? <span aria-hidden className="absolute inset-0 animate-pulse bg-surface" /> : null}
      <img
        ref={(node) => {
          if (!node) return;
          if (node.complete && node.naturalWidth > 0) setLoaded(true);
          else if (node.complete) setFailed(true);
        }}
        src={src}
        alt={alt}
        decoding="async"
        loading={loading ?? (priority ? "eager" : "lazy")}
        {...(priority ? { fetchPriority: "high" as const } : {})}
        referrerPolicy="no-referrer"
        className={cn(
          "size-full object-cover transition-opacity duration-300",
          loaded ? "opacity-100" : "opacity-0",
        )}
        style={{ objectPosition: "center top" }}
        onLoad={() => {
          setLoaded(true);
          onLoad?.();
        }}
        onError={() => {
          setFailed(true);
          onError?.();
        }}
      />
    </div>
  );
}

/** Small square-ish catalog thumbnail used in cart surfaces. */
export function CatalogProductThumb({ productId, title }: { productId: string; title: string }) {
  // TEMPORARY_DRIVE_MEDIA — migrate approved originals to owned storage before production.
  const image = getPrimaryImage(productId);
  if (!image) {
    return <ProductImagePlaceholder slotId={`product.${productId}.front`} alt={title} label={productId} showMeta={false} />;
  }
  return (
    <CatalogProductImage
      src={renderableUrl(image)}
      alt={`${title} — ${image.imageRole.toLowerCase()} image`}
      imageRole={image.imageRole}
      fallbackSlotId={`product.${productId}.front`}
      fallbackLabel={productId}
      onError={() => markImageFailed(image)}
    />
  );
}
