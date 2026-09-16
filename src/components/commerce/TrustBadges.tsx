import { RotateCcw, ShieldCheck, Truck } from "lucide-react";
import { cn } from "@/lib/utils";

/** Compact trust line used on product cards. */
export function TrustLine({ className }: { className?: string }) {
  return (
    <p className={cn("flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-secondary-text", className)}>
      <span className="inline-flex items-center gap-1">
        <Truck className="size-3.5 text-rose" aria-hidden /> Trusted delivery
      </span>
      <span className="inline-flex items-center gap-1">
        <RotateCcw className="size-3.5 text-rose" aria-hidden /> 7-day returns
      </span>
    </p>
  );
}

const ITEMS = [
  { icon: Truck, title: "Trusted delivery", body: "Tracked, insured dispatch across India." },
  { icon: RotateCcw, title: "7-day return policy", body: "Easy returns within 7 days of delivery." },
  { icon: ShieldCheck, title: "Secure checkout", body: "Verified designers and safe payments." },
] as const;

/** Full trust panel used on the product detail page. */
export function TrustPanel({ className }: { className?: string }) {
  return (
    <ul className={cn("grid gap-3 border border-border bg-surface p-4 sm:grid-cols-3", className)}>
      {ITEMS.map(({ icon: Icon, title, body }) => (
        <li key={title} className="flex items-start gap-2.5">
          <Icon className="mt-0.5 size-4 shrink-0 text-rose" aria-hidden />
          <div>
            <p className="text-[12px] font-medium text-foreground">{title}</p>
            <p className="text-[11px] leading-snug text-muted-text">{body}</p>
          </div>
        </li>
      ))}
    </ul>
  );
}
