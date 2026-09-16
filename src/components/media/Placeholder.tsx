import { appMode } from "@/config/appMode";
import { cn } from "@/lib/utils";
import { getSlotImage } from "@/data/generated/homepageMedia";

export interface PlaceholderProps {
  slotId: string;
  role: string;
  ratio: string;
  desktop: string;
  mobile: string;
  alt: string;
  label?: string;
  entityId?: string;
  className?: string;
  tone?: "wine" | "charcoal" | "deep";
  showMeta?: boolean;
}

const TONES: Record<string, string> = {
  wine: "linear-gradient(146deg, #6D102F 0%, #33121F 44%, #141416 100%)",
  charcoal: "linear-gradient(146deg, #26232A 0%, #16151A 50%, #0C0C0E 100%)",
  deep: "linear-gradient(146deg, #3A1024 0%, #1A1319 55%, #0A0A0C 100%)",
};

const TONE_KEYS = ["wine", "charcoal", "deep"] as const;

function toneFor(slotId: string, tone?: PlaceholderProps["tone"]) {
  const fallback = TONES["wine"] as string;
  if (tone) return TONES[tone] ?? fallback;
  let n = 0;
  for (let i = 0; i < slotId.length; i += 1) n = (n * 31 + slotId.charCodeAt(i)) % 997;
  const key = TONE_KEYS[n % 3] ?? "wine";
  return TONES[key] ?? fallback;
}

const NOISE =
  "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='3'/%3E%3C/filter%3E%3Crect width='120' height='120' filter='url(%23n)' opacity='0.32'/%3E%3C/svg%3E\")";

export function Placeholder({
  slotId,
  role,
  ratio,
  desktop,
  mobile,
  alt,
  label,
  className,
  tone,
  showMeta = true,
}: PlaceholderProps) {
  const image = getSlotImage(slotId);
  const meta = appMode.showPlaceholderLabels && showMeta && !image;
  return (
    <div
      role="img"
      aria-label={alt}
      data-slot-id={slotId}
      data-role={role}
      className={cn(
        "relative isolate w-full overflow-hidden border border-border bg-surface",
        className,
      )}
      style={{ aspectRatio: ratio, backgroundImage: toneFor(slotId, tone) }}
    >
      {image ? (
        <img
          src={image}
          alt=""
          aria-hidden
          loading="lazy"
          decoding="async"
          className="absolute inset-0 size-full object-cover"
          style={{ objectPosition: "center top" }}
        />
      ) : null}
      <span
        aria-hidden
        className={cn(
          "pointer-events-none absolute inset-0 mix-blend-soft-light opacity-40",
          image && "hidden",
        )}
        style={{ backgroundImage: NOISE }}
      />
      <span
        aria-hidden
        className={cn(
          "pointer-events-none absolute inset-0 flex items-center justify-center px-4 text-center",
          image && "hidden",
        )}
      >
        <span className="eyebrow max-w-full truncate !text-[10px] !text-[#E4D8DD]/70">
          {(label ?? `${role} · ${slotId}`).toUpperCase()}
        </span>
      </span>
      {meta ? (
        <span
          aria-hidden
          className="pointer-events-none absolute inset-x-0 bottom-0 flex items-center justify-between gap-2 bg-black/35 px-2 py-1 text-[9px] tracking-[0.14em] text-[#E4D8DD]/55 uppercase"
        >
          <span className="truncate">{ratio.replace(/\s/g, "")}</span>
          <span className="truncate">
            {desktop} / {mobile}
          </span>
        </span>
      ) : null}
    </div>
  );
}
